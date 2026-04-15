import 'dart:async';
import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/conversion_job.dart';
import '../services/ffmpeg_service.dart';
import 'crop_overlay.dart';

/// Result returned from the VideoEditDialog.
class VideoEditResult {
  final int? trimStartFrame;
  final int? trimEndFrame;
  final int? cropX;
  final int? cropY;
  final int? cropWidth;
  final int? cropHeight;
  final bool applyToAll;

  const VideoEditResult({
    this.trimStartFrame,
    this.trimEndFrame,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.applyToAll = false,
  });
}

/// Full-screen dialog for visually trimming and cropping a video.
class VideoEditDialog extends StatefulWidget {
  final String videoPath;
  final FfmpegService ffmpegService;
  final ConversionJob job;

  const VideoEditDialog({
    super.key,
    required this.videoPath,
    required this.ffmpegService,
    required this.job,
  });

  @override
  State<VideoEditDialog> createState() => _VideoEditDialogState();
}

class _VideoEditDialogState extends State<VideoEditDialog> {
  VideoInfo? _videoInfo;
  bool _loading = true;
  String? _error;

  // Current preview frame
  String? _framePath;
  bool _extractingFrame = false;
  Timer? _debounce;
  int _currentFrame = 0;

  // Trim range
  int _trimStart = 0;
  int _trimEnd = 0;
  bool _trimEnabled = false;

  // Crop
  Rect? _cropRect; // in image pixel coordinates
  bool _cropEnabled = false;
  double? _cropAspectRatio; // null = free

  // Preview playback
  bool _previewing = false;
  bool _preparingPreview = false;
  double _prepareProgress = 0;
  List<String> _previewFramePaths = [];
  int _previewFrameIndex = 0;
  Timer? _playbackTimer;

  // Track temp files for cleanup
  final List<String> _tempFiles = [];
  String? _frameError;

  final _cropXController = TextEditingController();
  final _cropYController = TextEditingController();
  final _cropWController = TextEditingController();
  final _cropHController = TextEditingController();

  double get _safeFps {
    final fps = _videoInfo?.fps ?? 0;
    if (!fps.isFinite || fps <= 0) return 1;
    return fps;
  }

  double get _safeAspectRatio {
    final info = _videoInfo;
    if (info == null || info.width <= 0 || info.height <= 0) {
      return 16 / 9;
    }
    return info.width / info.height;
  }

  @override
  void initState() {
    super.initState();
    _initFromJob();
    _loadVideoInfo();
  }

  void _initFromJob() {
    final job = widget.job;
    _trimEnabled = job.hasTrim;
    _cropEnabled = job.hasCrop;
    if (job.trimStartFrame != null) _trimStart = job.trimStartFrame!;
    if (job.hasCrop) {
      _cropRect = Rect.fromLTWH(
        (job.cropX ?? 0).toDouble(),
        (job.cropY ?? 0).toDouble(),
        (job.cropWidth ?? 0).toDouble(),
        (job.cropHeight ?? 0).toDouble(),
      );
      _syncCropInputsFromRect();
    }
  }

  void _syncCropInputsFromRect() {
    if (_cropRect == null) return;
    _cropXController.text = _cropRect!.left.round().toString();
    _cropYController.text = _cropRect!.top.round().toString();
    _cropWController.text = _cropRect!.width.round().toString();
    _cropHController.text = _cropRect!.height.round().toString();
  }

  Rect _clampCropRect(Rect rect, VideoInfo info) {
    final maxW = info.width.toDouble().clamp(1, double.infinity);
    final maxH = info.height.toDouble().clamp(1, double.infinity);
    final x = rect.left.clamp(0.0, maxW - 1).toDouble();
    final y = rect.top.clamp(0.0, maxH - 1).toDouble();
    final w = rect.width.clamp(1.0, maxW - x).toDouble();
    final h = rect.height.clamp(1.0, maxH - y).toDouble();
    return Rect.fromLTWH(x, y, w, h);
  }

  void _applyManualCropValues() {
    final info = _videoInfo;
    if (info == null) return;

    final x = int.tryParse(_cropXController.text.trim());
    final y = int.tryParse(_cropYController.text.trim());
    final w = int.tryParse(_cropWController.text.trim());
    final h = int.tryParse(_cropHController.text.trim());
    if (x == null || y == null || w == null || h == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crop values must be whole numbers')),
      );
      return;
    }
    if (x < 0 || y < 0 || w <= 0 || h <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use x/y >= 0 and w/h > 0')),
      );
      return;
    }

    setState(() {
      _cropAspectRatio = null;
      _cropRect = _clampCropRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
        info,
      );
      _syncCropInputsFromRect();
    });
  }

  Future<void> _loadVideoInfo() async {
    try {
      final info = await widget.ffmpegService.getVideoInfo(widget.videoPath);
      if (!mounted) return;
      setState(() {
        _videoInfo = info;
        _loading = false;
        final maxFrame = (info.totalFrames - 1).clamp(0, 1 << 30).toInt();
        if (_trimEnd == 0) _trimEnd = info.totalFrames;
        if (widget.job.trimEndFrame != null) {
          _trimEnd = widget.job.trimEndFrame!;
        }
        _trimStart = _trimStart.clamp(0, maxFrame).toInt();
        _trimEnd = _trimEnd.clamp(_trimStart, info.totalFrames).toInt();
        _currentFrame = _trimStart.clamp(0, maxFrame).toInt();
        if (_cropRect != null) {
          _cropRect = _clampCropRect(_cropRect!, info);
          _syncCropInputsFromRect();
        }
      });
      _extractCurrentFrame();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _extractCurrentFrame() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted || _videoInfo == null) return;
      setState(() {
        _extractingFrame = true;
        _frameError = null;
      });
      try {
        final timeSeconds = _currentFrame / _safeFps;
        final path = await widget.ffmpegService
            .extractFrame(widget.videoPath, timeSeconds);
        _tempFiles.add(path);
        if (!mounted) return;
        setState(() {
          _framePath = path;
          _extractingFrame = false;
          _frameError = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _extractingFrame = false;
          _frameError = e.toString();
        });
      }
    });
  }

  Future<void> _startPreview() async {
    if (_videoInfo == null) return;

    setState(() {
      _preparingPreview = true;
      _prepareProgress = 0;
    });

    final fps = _safeFps;
    final start = _trimEnabled ? _trimStart : 0;
    final end = _trimEnabled ? _trimEnd : _videoInfo!.totalFrames;
    final rangeFrames = (end - start).clamp(1, 1 << 30).toInt();

    // Extract ~20 frames, or fewer if the range is short
    final frameCount = rangeFrames.clamp(2, 24).toInt();
    final step = rangeFrames / frameCount;

    final paths = <String>[];
    for (int i = 0; i < frameCount; i++) {
      if (!mounted) return;
      final frame = start + (step * i).round();
      final timeSec = frame / fps;
      try {
        final path = await widget.ffmpegService
            .extractFrame(widget.videoPath, timeSec);
        _tempFiles.add(path);
        paths.add(path);
      } catch (_) {
        // Skip failed frames
      }
      if (mounted) {
        setState(() => _prepareProgress = (i + 1) / frameCount);
      }
    }

    if (!mounted || paths.isEmpty) return;

    // Calculate playback interval from the video duration of the range
    final rangeDuration = rangeFrames / fps;
    final intervalMs = (rangeDuration * 1000 / paths.length)
        .round()
        .clamp(33, 500); // 2-30fps playback

    setState(() {
      _previewFramePaths = paths;
      _previewFrameIndex = 0;
      _previewing = true;
      _preparingPreview = false;
    });

    _playbackTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) {
        if (!mounted) return;
        setState(() {
          _previewFrameIndex =
              (_previewFrameIndex + 1) % _previewFramePaths.length;
        });
      },
    );
  }

  void _stopPreview() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    setState(() {
      _previewing = false;
      _preparingPreview = false;
      _previewFramePaths = [];
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _playbackTimer?.cancel();
    // Clean up temp frames
    for (final path in _tempFiles) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _cropXController.dispose();
    _cropYController.dispose();
    _cropWController.dispose();
    _cropHController.dispose();
    super.dispose();
  }

  VideoEditResult _buildResult({bool applyToAll = false}) {
    return VideoEditResult(
      trimStartFrame: _trimEnabled ? _trimStart : null,
      trimEndFrame:
          _trimEnabled && _trimEnd < (_videoInfo?.totalFrames ?? 0)
              ? _trimEnd
              : null,
      cropX: _cropEnabled && _cropRect != null
          ? _cropRect!.left.round()
          : null,
      cropY: _cropEnabled && _cropRect != null
          ? _cropRect!.top.round()
          : null,
      cropWidth: _cropEnabled && _cropRect != null
          ? _cropRect!.width.round()
          : null,
      cropHeight: _cropEnabled && _cropRect != null
          ? _cropRect!.height.round()
          : null,
      applyToAll: applyToAll,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: EdgeInsets.only(left: Platform.isMacOS ? 60 : 0),
            child: Text(
              'Edit Video',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          centerTitle: false,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .pop(_buildResult(applyToAll: true)),
              child: const Text('Apply to All'),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_buildResult()),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text('Error: $_error',
                        style: TextStyle(color: theme.colorScheme.error)))
                : _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_previewing)
                    _buildPlaybackPreview(theme)
                  else
                    _buildPreviewArea(theme, constraints),
                  const SizedBox(height: 12),
                  _buildPreviewButton(theme),
                  if (!_previewing) ...[
                    const SizedBox(height: 16),
                    _buildScrubber(theme),
                    const SizedBox(height: 20),
                    _buildTrimControls(theme),
                    const SizedBox(height: 16),
                    _buildCropControls(theme),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewArea(ThemeData theme, BoxConstraints constraints) {
    if (_framePath == null) {
      return AspectRatio(
        aspectRatio: _safeAspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: _extractingFrame
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white70, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          _frameError ?? 'Could not load preview frame',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _extractCurrentFrame,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    final info = _videoInfo!;
    final aspectRatio = _safeAspectRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: LayoutBuilder(
              builder: (context, imageConstraints) {
                final displaySize = Size(
                  imageConstraints.maxWidth,
                  imageConstraints.maxHeight,
                );
                return Stack(
                  children: [
                    // Video frame
                    SizedBox(
                      width: displaySize.width,
                      height: displaySize.height,
                      child: Image.file(
                        File(_framePath!),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                    // Loading indicator
                    if (_extractingFrame)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Crop overlay
                    if (_cropEnabled)
                      CropOverlay(
                        imageSize:
                            Size(info.width.toDouble(), info.height.toDouble()),
                        displaySize: displaySize,
                        initialCrop: _cropRect,
                        aspectRatio: _cropAspectRatio,
                        onCropChanged: (rect) {
                          if (!mounted) return;
                          setState(() {
                            _cropRect = rect;
                            _syncCropInputsFromRect();
                          });
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackPreview(ThemeData theme) {
    if (_previewFramePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    final info = _videoInfo!;
    final cropRect = _cropEnabled && _cropRect != null
        ? _cropRect!
        : Rect.fromLTWH(
            0, 0, info.width.toDouble(), info.height.toDouble());
    final aspectRatio = cropRect.width / cropRect.height;

    // Scale factors from image pixels to display coordinates
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // We need to show only the cropped portion of the frame.
                // Scale the full image so that it fills the display, then
                // position it so the crop region is visible.
                final displayW = constraints.maxWidth;
                final displayH = constraints.maxHeight;

                // Scale factor: how much to scale image so crop fills display
                final scaleX = displayW / cropRect.width;
                final scaleY = displayH / cropRect.height;

                return ClipRect(
                  child: SizedBox(
                    width: displayW,
                    height: displayH,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: info.width * scaleX,
                      maxHeight: info.height * scaleY,
                      child: Transform.translate(
                        offset: Offset(
                          -cropRect.left * scaleX,
                          -cropRect.top * scaleY,
                        ),
                        child: Image.file(
                          File(_previewFramePaths[_previewFrameIndex]),
                          width: info.width * scaleX,
                          height: info.height * scaleY,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewButton(ThemeData theme) {
    if (_preparingPreview) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Preparing preview...',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _prepareProgress),
            ],
          ),
        ),
      );
    }

    return Center(
      child: _previewing
          ? FilledButton.icon(
              onPressed: _stopPreview,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Stop Preview'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
            )
          : OutlinedButton.icon(
              onPressed: _videoInfo != null ? _startPreview : null,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Preview with trim & crop'),
            ),
    );
  }

  Widget _buildScrubber(ThemeData theme) {
    final total = _videoInfo?.totalFrames ?? 1;
    final interactiveStyle = GoogleFonts.staatliches(
      fontSize: 13,
      color: theme.colorScheme.onSurface,
    );
    final subtitleStyle = GoogleFonts.dmSans(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Preview Frame', style: subtitleStyle),
                const Spacer(),
                Text(
                  'Frame $_currentFrame / $total',
                  style: interactiveStyle,
                ),
                if (_videoInfo != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(_currentFrame / _safeFps),
                    style: interactiveStyle,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _currentFrame.toDouble(),
                min: 0,
                max: total.toDouble().clamp(1, double.infinity),
                onChanged: (v) {
                  setState(() => _currentFrame = v.round());
                  _extractCurrentFrame();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimControls(ThemeData theme) {
    final total = _videoInfo?.totalFrames ?? 1;
    final boldLabel = GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: theme.colorScheme.onSurface,
    );
    final subtitleStyle = GoogleFonts.dmSans(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final interactiveStyle = GoogleFonts.staatliches(
      fontSize: 13,
      color: theme.colorScheme.onSurface,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.content_cut,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Trim', style: boldLabel),
                const Spacer(),
                Switch(
                  value: _trimEnabled,
                  onChanged: (v) => setState(() => _trimEnabled = v),
                ),
              ],
            ),
            if (_trimEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Drag the range to select which frames to keep.',
                style: subtitleStyle,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Start: $_trimStart', style: interactiveStyle),
                  const Spacer(),
                  Text('End: $_trimEnd', style: interactiveStyle),
                ],
              ),
              RangeSlider(
                values:
                    RangeValues(_trimStart.toDouble(), _trimEnd.toDouble()),
                min: 0,
                max: total.toDouble().clamp(1, double.infinity),
                divisions: total > 1 ? total : null,
                labels: RangeLabels('$_trimStart', '$_trimEnd'),
                onChanged: (values) {
                  setState(() {
                    _trimStart = values.start.round();
                    _trimEnd = values.end.round();
                  });
                },
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _trimStart = _currentFrame;
                      });
                    },
                    icon: const Icon(Icons.first_page, size: 16),
                    label: const Text('Set start to current'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _trimEnd = _currentFrame;
                      });
                    },
                    icon: const Icon(Icons.last_page, size: 16),
                    label: const Text('Set end to current'),
                  ),
                ],
              ),
              if (_videoInfo != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Duration: ${_formatTime((_trimEnd - _trimStart) / _safeFps)} '
                  '(${_trimEnd - _trimStart} frames)',
                  style: subtitleStyle,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualCropInputs(ThemeData theme) {
    InputDecoration inputDecoration(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );

    Widget sizedField(TextEditingController controller, String label) {
      return SizedBox(
        width: 88,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: inputDecoration(label),
          onSubmitted: (_) => _applyManualCropValues(),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        sizedField(_cropXController, 'X'),
        sizedField(_cropYController, 'Y'),
        sizedField(_cropWController, 'W'),
        sizedField(_cropHController, 'H'),
        FilledButton(
          onPressed: _applyManualCropValues,
          child: const Text('Apply Values'),
        ),
      ],
    );
  }

  Widget _buildCropControls(ThemeData theme) {
    final boldLabel = GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: theme.colorScheme.onSurface,
    );
    final subtitleStyle = GoogleFonts.dmSans(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final interactiveStyle = GoogleFonts.staatliches(
      fontSize: 13,
      color: theme.colorScheme.onSurface,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.crop, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Crop', style: boldLabel),
                const Spacer(),
                Switch(
                  value: _cropEnabled,
                  onChanged: (v) => setState(() {
                    _cropEnabled = v;
                    if (v && _cropRect == null && _videoInfo != null) {
                      _cropRect = Rect.fromLTWH(
                        0,
                        0,
                        _videoInfo!.width.toDouble(),
                        _videoInfo!.height.toDouble(),
                      );
                      _syncCropInputsFromRect();
                    }
                  }),
                ),
              ],
            ),
            if (_cropEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Drag the rectangle on the preview or enter X/Y/W/H manually.',
                style: subtitleStyle,
              ),
              const SizedBox(height: 10),
              Text('Aspect Ratio', style: boldLabel),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildRatioChip('Free', null),
                  _buildRatioChip('1:1', 1.0),
                  _buildRatioChip('4:3', 4 / 3),
                  _buildRatioChip('3:2', 3 / 2),
                  _buildRatioChip('16:9', 16 / 9),
                  _buildRatioChip('9:16', 9 / 16),
                  _buildRatioChip('3:4', 3 / 4),
                  _buildRatioChip('2:3', 2 / 3),
                  _buildRatioChip('21:9', 21 / 9),
                ],
              ),
              if (_cropRect != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      'X: ${_cropRect!.left.round()}  Y: ${_cropRect!.top.round()}',
                      style: interactiveStyle,
                    ),
                    Text(
                      'W: ${_cropRect!.width.round()}  H: ${_cropRect!.height.round()}',
                      style: interactiveStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildManualCropInputs(theme),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _videoInfo != null
                    ? () {
                        setState(() {
                          _cropAspectRatio = null;
                          _cropRect = Rect.fromLTWH(
                            0,
                            0,
                            _videoInfo!.width.toDouble(),
                            _videoInfo!.height.toDouble(),
                          );
                          _syncCropInputsFromRect();
                        });
                      }
                    : null,
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('Reset to full frame'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatioChip(String label, double? ratio) {
    final isSelected = _cropAspectRatio == ratio;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _cropAspectRatio = ratio);
      },
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatTime(double seconds) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60);
    return '${m.toString().padLeft(2, '0')}:${s.toStringAsFixed(2).padLeft(5, '0')}';
  }
}
