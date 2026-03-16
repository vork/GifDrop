import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'binary_resolver.dart';
import 'gifski_bindings.dart';
import 'gifski_library.dart';
import '../models/conversion_job.dart';
import '../models/conversion_settings.dart';

/// Thrown when conversion is stopped by user (Cancel).
class ConversionCancelledException implements Exception {
  @override
  String toString() => 'Conversion cancelled';
}

/// Basic video metadata extracted from FFmpeg probe.
class VideoInfo {
  final double duration;
  final int width;
  final int height;
  final double fps;
  final int totalFrames;

  const VideoInfo({
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    required this.totalFrames,
  });
}

class FfmpegService {
  String? _ffmpegPath;

  Future<String> get ffmpegPath async {
    _ffmpegPath ??= await BinaryResolver.resolve('ffmpeg');
    return _ffmpegPath!;
  }

  /// Run a process, drain stderr, and return (exitCode, stderrText).
  /// If [cancelSignal] completes first, kills the process and throws [ConversionCancelledException].
  Future<(int, String)> _runProcess(
    String executable,
    List<String> args, {
    void Function(String chunk)? onStderr,
    Future<void>? cancelSignal,
  }) async {
    final process = await Process.start(executable, args);

    process.stdout.drain<void>();

    final stderrBuf = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen((chunk) {
          stderrBuf.write(chunk);
          onStderr?.call(chunk);
        })
        .asFuture<void>();

    int? exitCode;
    if (cancelSignal != null) {
      try {
        await Future.any([
          (() async {
            await stderrDone;
            exitCode = await process.exitCode;
          })(),
          cancelSignal.then((_) async {
            process.kill(ProcessSignal.sigterm);
            await process.exitCode;
            throw ConversionCancelledException();
          }),
        ]);
      } on ConversionCancelledException {
        rethrow;
      }
    } else {
      await stderrDone;
      exitCode = await process.exitCode;
    }
    return (exitCode!, stderrBuf.toString());
  }

  /// Probe video for metadata: duration, resolution, fps, total frames.
  Future<VideoInfo> getVideoInfo(String inputPath) async {
    final ffmpeg = await ffmpegPath;
    final (_, stderr) = await _runProcess(ffmpeg, ['-i', inputPath]);

    // Duration
    double duration = 0;
    final durRegex = RegExp(r'Duration:\s+(\d+):(\d+):(\d+)\.(\d+)');
    final durMatch = durRegex.firstMatch(stderr);
    if (durMatch != null) {
      duration = int.parse(durMatch.group(1)!) * 3600.0 +
          int.parse(durMatch.group(2)!) * 60.0 +
          int.parse(durMatch.group(3)!) +
          int.parse(durMatch.group(4)!) / 100.0;
    }

    // Resolution and fps from video stream line
    int width = 0;
    int height = 0;
    double fps = 30;
    final streamRegex = RegExp(r'Stream.*Video:.*?(\d{2,5})x(\d{2,5})');
    final streamMatch = streamRegex.firstMatch(stderr);
    if (streamMatch != null) {
      width = int.parse(streamMatch.group(1)!);
      height = int.parse(streamMatch.group(2)!);
    }
    final fpsRegex = RegExp(r'(\d+(?:\.\d+)?)\s+fps');
    final fpsMatch = fpsRegex.firstMatch(stderr);
    if (fpsMatch != null) {
      fps = double.parse(fpsMatch.group(1)!);
    }

    final totalFrames = (duration * fps).round();

    return VideoInfo(
      duration: duration,
      width: width,
      height: height,
      fps: fps,
      totalFrames: totalFrames,
    );
  }

  /// Extract a single frame at a given time (seconds) and save as PNG.
  /// Returns the output file path.
  Future<String> extractFrame(String inputPath, double timeSeconds) async {
    final ffmpeg = await ffmpegPath;
    final outputPath = p.join(
      Directory.systemTemp.path,
      'gif_frame_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    final args = [
      '-ss', timeSeconds.toStringAsFixed(3),
      '-i', inputPath,
      '-vframes', '1',
      '-y', outputPath,
    ];

    final (exitCode, stderr) = await _runProcess(ffmpeg, args);
    if (exitCode != 0) {
      throw Exception('Frame extraction failed (exit $exitCode):\n$stderr');
    }
    return outputPath;
  }

  Future<double> getVideoDuration(String inputPath, {Future<void>? cancelSignal}) async {
    final ffmpeg = await ffmpegPath;
    final (_, stderr) = await _runProcess(ffmpeg, ['-i', inputPath], cancelSignal: cancelSignal);

    final regex = RegExp(r'Duration:\s+(\d+):(\d+):(\d+)\.(\d+)');
    final match = regex.firstMatch(stderr);
    if (match != null) {
      return int.parse(match.group(1)!) * 3600.0 +
          int.parse(match.group(2)!) * 60.0 +
          int.parse(match.group(3)!) +
          int.parse(match.group(4)!) / 100.0;
    }
    return 0;
  }

  /// Build the pre-processing filter chain (trim, fps, scale, crop).
  /// Per-video trim/crop comes from the [ConversionJob].
  /// [effectiveFps] overrides `settings.fps` — use to cap at source video fps.
  @visibleForTesting
  String buildPreFilters(ConversionSettings settings, ConversionJob job,
      {int? effectiveFps}) {
    final fps = effectiveFps ?? settings.fps;
    final parts = <String>[];

    // Trim must come first (before any resampling)
    if (job.hasTrim) {
      final trimParts = <String>[];
      if (job.trimStartFrame != null) {
        trimParts.add('start_frame=${job.trimStartFrame}');
      }
      if (job.trimEndFrame != null) {
        trimParts.add('end_frame=${job.trimEndFrame}');
      }
      parts.add('trim=${trimParts.join(':')}');
      parts.add('setpts=PTS-STARTPTS');
    }

    parts.add('fps=$fps');

    if (settings.width != null) {
      parts.add('scale=${settings.width}:-2:flags=lanczos');
    }

    // Crop after scale so coordinates are relative to output resolution
    if (job.hasCrop) {
      final w = job.cropWidth ?? 'iw';
      final h = job.cropHeight ?? 'ih';
      final x = job.cropX ?? 0;
      final y = job.cropY ?? 0;
      parts.add('crop=$w:$h:$x:$y');
    }

    return parts.join(',');
  }

  /// Build the boomerang portion of the filter graph.
  @visibleForTesting
  String buildBoomerangFilter(ConversionSettings settings) {
    if (!settings.isBoomerang) return '';

    if (settings.loopMode == LoopMode.boomerang) {
      return 'split[fwd][rev];[rev]reverse[rev2];[fwd][rev2]concat=n=2:v=1';
    } else {
      return 'split[fwd][rev];'
          '[rev]reverse,trim=start_frame=1,setpts=PTS-STARTPTS,'
          'reverse,trim=start_frame=1,setpts=PTS-STARTPTS,'
          'reverse,setpts=PTS-STARTPTS[rev2];'
          '[fwd][rev2]concat=n=2:v=1';
    }
  }

  /// Extract video frames as individual PNG files into a temp directory.
  Future<(String frameDir, int frameCount)> _extractFrames(
    String inputPath,
    ConversionSettings settings,
    ConversionJob job,
    double totalDuration,
    int effectiveFps,
    void Function(double progress, String status) onProgress, {
    Future<void>? cancelSignal,
  }) async {
    final ffmpeg = await ffmpegPath;
    final frameDir = Directory.systemTemp.createTempSync('gifdrop_frames_').path;

    final preFilters =
        buildPreFilters(settings, job, effectiveFps: effectiveFps);
    String vf;
    if (settings.isBoomerang) {
      final boomerang = buildBoomerangFilter(settings);
      vf = '$preFilters,$boomerang';
    } else {
      vf = preFilters;
    }

    final framePath = p.join(frameDir, 'frame_%06d.png');
    final args = [
      '-i', inputPath,
      '-vf', vf,
      '-vsync', 'vfr',
      '-y', framePath,
    ];

    final timeRegex = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)');
    final (exitCode, stderr) = await _runProcess(ffmpeg, args,
        onStderr: (chunk) {
      final match = timeRegex.firstMatch(chunk);
      if (match != null && totalDuration > 0) {
        final current = int.parse(match.group(1)!) * 3600.0 +
            int.parse(match.group(2)!) * 60.0 +
            int.parse(match.group(3)!) +
            int.parse(match.group(4)!) / 100.0;
        final effectiveDuration =
            settings.isBoomerang ? totalDuration * 2 : totalDuration;
        final progress = (current / effectiveDuration).clamp(0.0, 1.0);
        onProgress(progress, 'Extracting frames...');
      }
    }, cancelSignal: cancelSignal);

    if (exitCode != 0) {
      throw Exception('Frame extraction failed (exit $exitCode):\n$stderr');
    }

    final frames = Directory(frameDir)
        .listSync()
        .where((f) => f.path.endsWith('.png'))
        .length;

    if (frames == 0) {
      throw Exception('No frames extracted from video');
    }

    return (frameDir, frames);
  }

  /// Encode PNG frames into a GIF using gifski via FFI.
  Future<void> _encodeWithGifski(
    String frameDir,
    int frameCount,
    String outputPath,
    ConversionSettings settings,
    int effectiveFps,
    void Function(double progress, String status) onProgress, {
    Future<void>? cancelSignal,
  }) async {
    final bindings = GifskiLibrary.bindings;

    // Allocate and populate GifskiSettings
    final settingsPtr = calloc<GifskiSettings>();
    settingsPtr.ref.width = settings.width ?? 0;
    settingsPtr.ref.height = 0;
    settingsPtr.ref.quality = settings.quality;
    settingsPtr.ref.fast = settings.speedMode == SpeedMode.fast;
    settingsPtr.ref.repeat = settings.isLoop ? 0 : -1;

    final handle = bindings.gifskiNew(settingsPtr);
    calloc.free(settingsPtr);

    if (handle == nullptr) {
      throw Exception('gifski_new returned null — invalid settings');
    }

    var cancelled = false;
    cancelSignal?.then((_) => cancelled = true);

    var finishCalled = false;
    try {
      // Configure optional quality settings
      if (settings.motionQuality != null) {
        checkGifskiError(
          bindings.gifskiSetMotionQuality(handle, settings.motionQuality!),
          'gifski_set_motion_quality',
        );
      }
      if (settings.speedMode == SpeedMode.extra) {
        checkGifskiError(
          bindings.gifskiSetExtraEffort(handle, true),
          'gifski_set_extra_effort',
        );
      }

      // Set output file — this starts the encoder thread, must be before adding frames
      final outputPathNative = outputPath.toNativeUtf8();
      checkGifskiError(
        bindings.gifskiSetFileOutput(handle, outputPathNative),
        'gifski_set_file_output',
      );
      calloc.free(outputPathNative);

      // Collect and sort frame paths
      final framePaths = Directory(frameDir)
          .listSync()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.path)
          .toList()
        ..sort();

      // Add frames with presentation timestamps
      final frameDuration = 1.0 / effectiveFps;
      for (var i = 0; i < framePaths.length; i++) {
        if (cancelled) {
          throw ConversionCancelledException();
        }

        final pathNative = framePaths[i].toNativeUtf8();
        final result = bindings.gifskiAddFramePngFile(
          handle,
          i,
          pathNative,
          i * frameDuration,
        );
        calloc.free(pathNative);

        if (result == GifskiError.aborted) {
          throw ConversionCancelledException();
        }
        checkGifskiError(result, 'gifski_add_frame_png_file');

        // Report progress based on frames added
        onProgress(
          ((i + 1) / framePaths.length).clamp(0.0, 1.0),
          'Encoding GIF...',
        );

        // Yield to allow UI updates and cancel signal processing
        await Future<void>.delayed(Duration.zero);
      }

      // Finalize — does the actual encoding work and frees the handle
      finishCalled = true;
      final finishResult = bindings.gifskiFinish(handle);
      if (finishResult == GifskiError.aborted) {
        throw ConversionCancelledException();
      }
      checkGifskiError(finishResult, 'gifski_finish');
    } finally {
      if (!finishCalled) {
        bindings.gifskiFinish(handle); // free the handle, ignore result
      }
    }
  }

  Future<String> convertToGif({
    required ConversionJob job,
    required ConversionSettings settings,
    required void Function(double progress, String status) onProgress,
    Future<void>? cancelSignal,
  }) async {
    final inputPath = job.inputPath;
    final outputDir = p.dirname(inputPath);
    final baseName = p.basenameWithoutExtension(inputPath);
    final outputPath = p.join(outputDir, '$baseName.gif');

    String? frameDir;
    try {
      onProgress(0.0, 'Analyzing video...');
      final info = await getVideoInfo(inputPath);
      final duration = info.duration;

      // Clamp trim to actual video length
      if (job.hasTrim) {
        job.clampTrim(info.totalFrames);
      }

      // Cap output fps at source video fps to avoid duplicate frames
      final effectiveFps = settings.fps < info.fps.round()
          ? settings.fps
          : info.fps.round();

      onProgress(0.05, 'Extracting frames...');
      final (extractedDir, frameCount) = await _extractFrames(
        inputPath,
        settings,
        job,
        duration,
        effectiveFps,
        (p, s) => onProgress(0.05 + p * 0.45, s),
        cancelSignal: cancelSignal,
      );
      frameDir = extractedDir;

      onProgress(0.50, 'Encoding GIF...');
      await _encodeWithGifski(
        frameDir,
        frameCount,
        outputPath,
        settings,
        effectiveFps,
        (p, s) => onProgress(0.50 + p * 0.45, s),
        cancelSignal: cancelSignal,
      );

      onProgress(1.0, 'Done!');
      return outputPath;
    } finally {
      if (frameDir != null) {
        try {
          await Directory(frameDir).delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
