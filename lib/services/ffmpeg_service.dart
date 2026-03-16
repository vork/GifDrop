import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'binary_resolver.dart';
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
  String? _gifsicklePath;

  Future<String> get ffmpegPath async {
    _ffmpegPath ??= await BinaryResolver.resolve('ffmpeg');
    return _ffmpegPath!;
  }

  Future<String> get gifsicklePath async {
    _gifsicklePath ??= await BinaryResolver.resolve('gifsicle');
    return _gifsicklePath!;
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
  /// Returns the chain as a string. For use in both palette and GIF passes.
  /// Per-video trim/crop comes from the [ConversionJob].
  @visibleForTesting
  String buildPreFilters(ConversionSettings settings, ConversionJob job) {
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

    parts.add('fps=${settings.fps}');

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
  /// [inputLabel] is the label of the stream to process (e.g. empty for -vf, or a named label).
  /// Returns (filterGraph, outputLabel) where outputLabel is the named stream to continue with.
  @visibleForTesting
  String buildBoomerangFilter(ConversionSettings settings) {
    if (!settings.isBoomerang) return '';

    if (settings.loopMode == LoopMode.boomerang) {
      // Forward + backward, with duplicate frames at junction
      // split → reverse → concat
      return 'split[fwd][rev];[rev]reverse[rev2];[fwd][rev2]concat=n=2:v=1';
    } else {
      // Seamless: trim first frame of reversed (duplicate of last forward frame)
      // and trim last frame of reversed (duplicate of first forward frame for loop point)
      // Triple-reverse trick to trim last frame without knowing count:
      //   reverse → trim start_frame=1 → reverse → trim start_frame=1 → reverse
      return 'split[fwd][rev];'
          '[rev]reverse,trim=start_frame=1,setpts=PTS-STARTPTS,'
          'reverse,trim=start_frame=1,setpts=PTS-STARTPTS,'
          'reverse,setpts=PTS-STARTPTS[rev2];'
          '[fwd][rev2]concat=n=2:v=1';
    }
  }

  Future<String> _generatePalette(
    String inputPath,
    ConversionSettings settings,
    ConversionJob job,
    String palettePath, {
    Future<void>? cancelSignal,
  }) async {
    final ffmpeg = await ffmpegPath;

    final statsMode = settings.useLocalColorTables ? 'diff' : 'full';
    final preFilters = buildPreFilters(settings, job);

    String vf;
    if (settings.isBoomerang) {
      final boomerang = buildBoomerangFilter(settings);
      vf = '$preFilters,$boomerang,palettegen=stats_mode=$statsMode';
    } else {
      vf = '$preFilters,palettegen=stats_mode=$statsMode';
    }

    final args = [
      '-i', inputPath,
      '-vf', vf,
      '-y', palettePath,
    ];

    final (exitCode, stderr) = await _runProcess(ffmpeg, args, cancelSignal: cancelSignal);
    if (exitCode != 0) {
      throw Exception('Palette generation failed (exit $exitCode):\n$stderr');
    }
    return palettePath;
  }

  Future<void> _createGif(
    String inputPath,
    String palettePath,
    String outputPath,
    ConversionSettings settings,
    ConversionJob job,
    double totalDuration,
    void Function(double progress, String status) onProgress, {
    Future<void>? cancelSignal,
  }) async {
    final ffmpeg = await ffmpegPath;

    final preFilters = buildPreFilters(settings, job);

    final paletteOpts = StringBuffer('paletteuse=dither=${settings.ditherMode}');
    if (settings.ditherMode == 'bayer') {
      paletteOpts.write(':bayer_scale=${settings.bayerScale}');
    }
    if (settings.useLocalColorTables) {
      paletteOpts.write(':diff_mode=rectangle:new=1');
    }

    String filterComplex;
    if (settings.isBoomerang) {
      final boomerang = buildBoomerangFilter(settings);
      filterComplex =
          '$preFilters,$boomerang [x]; [x][1:v] $paletteOpts';
    } else {
      filterComplex = '$preFilters [x]; [x][1:v] $paletteOpts';
    }

    final loopFlag = settings.isLoop ? '0' : '-1';

    final args = [
      '-i', inputPath,
      '-i', palettePath,
      '-lavfi', filterComplex,
      '-loop', loopFlag,
      '-y', outputPath,
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
        final progress = (current / totalDuration).clamp(0.0, 1.0);
        onProgress(progress, 'Creating GIF...');
      }
    },
        cancelSignal: cancelSignal);

    if (exitCode != 0) {
      throw Exception('GIF creation failed (exit $exitCode):\n$stderr');
    }
  }

  Future<void> _optimizeWithGifsicle(
    String gifPath,
    ConversionSettings settings,
    void Function(double progress, String status) onProgress, {
    Future<void>? cancelSignal,
  }) async {
    final gifsicle = await gifsicklePath;

    onProgress(0.0, 'Optimizing with lossy compression...');

    final args = [
      '--lossy=${settings.lossyLevel}',
      '-O3',
      '-b',
      gifPath,
    ];

    final (exitCode, stderr) = await _runProcess(gifsicle, args, cancelSignal: cancelSignal);
    if (exitCode != 0) {
      throw Exception('Gifsicle optimization failed (exit $exitCode):\n$stderr');
    }

    onProgress(1.0, 'Optimization complete');
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
    final palettePath = p.join(
      Directory.systemTemp.path,
      'gif_palette_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    try {
      onProgress(0.0, 'Analyzing video...');
      final info = await getVideoInfo(inputPath);
      final duration = info.duration;

      // Clamp trim to actual video length
      if (job.hasTrim) {
        job.clampTrim(info.totalFrames);
      }

      onProgress(0.05, 'Generating color palette...');
      await _generatePalette(inputPath, settings, job, palettePath, cancelSignal: cancelSignal);

      // Boomerang modes roughly double the effective duration for progress tracking
      final effectiveDuration = settings.isBoomerang ? duration * 2 : duration;

      onProgress(0.1, 'Creating GIF...');
      await _createGif(
        inputPath,
        palettePath,
        outputPath,
        settings,
        job,
        effectiveDuration,
        (p, s) => onProgress(0.1 + p * 0.8, s),
        cancelSignal: cancelSignal,
      );

      if (settings.enableLossyCompression) {
        onProgress(0.9, 'Applying lossy compression...');
        await _optimizeWithGifsicle(
          outputPath,
          settings,
          (p, s) => onProgress(0.9 + p * 0.1, s),
          cancelSignal: cancelSignal,
        );
      }

      onProgress(1.0, 'Done!');
      return outputPath;
    } finally {
      try {
        await File(palettePath).delete();
      } catch (_) {}
    }
  }
}
