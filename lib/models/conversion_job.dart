enum ConversionJobStatus {
  pending,
  converting,
  encoding,
  done,
  error,
}

enum TransparencyKeyMode {
  none,
  white,
  black,
}

class ConversionJob {
  final String inputPath;
  ConversionJobStatus status;
  double progress;
  String? outputPath;
  String? errorMessage;
  int? outputFileSize;
  String statusText;

  // Per-video trim (frame-based)
  int? trimStartFrame;
  int? trimEndFrame;

  // Source video fps (probed on add)
  double? sourceFps;

  // Per-video crop (pixel-based)
  int? cropX;
  int? cropY;
  int? cropWidth;
  int? cropHeight;

  // Per-video playback speed multiplier (1.0 = original speed)
  double playbackSpeed;

  // Per-video transparency keying mode.
  TransparencyKeyMode transparencyKeyMode;

  bool get hasTrim => trimStartFrame != null || trimEndFrame != null;
  bool get hasCrop =>
      cropX != null || cropY != null || cropWidth != null || cropHeight != null;

  /// Clamp trim values so they are valid for a video with [totalFrames].
  /// If trimEnd exceeds total frames, it is set to null (meaning end of video).
  /// If trimStart >= totalFrames, trim is cleared entirely.
  void clampTrim(int totalFrames) {
    if (trimStartFrame != null && trimStartFrame! >= totalFrames) {
      trimStartFrame = null;
      trimEndFrame = null;
      return;
    }
    if (trimEndFrame != null && trimEndFrame! >= totalFrames) {
      trimEndFrame = null;
    }
    if (trimStartFrame != null &&
        trimEndFrame != null &&
        trimStartFrame! >= trimEndFrame!) {
      trimStartFrame = null;
      trimEndFrame = null;
    }
  }

  ConversionJob({
    required this.inputPath,
    this.status = ConversionJobStatus.pending,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    this.outputFileSize,
    this.statusText = '',
    this.trimStartFrame,
    this.trimEndFrame,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.playbackSpeed = 1.0,
    this.transparencyKeyMode = TransparencyKeyMode.none,
  });
}
