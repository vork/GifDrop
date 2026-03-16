enum LoopMode {
  none,
  loop,
  boomerang,
  boomerangSeamless,
}

enum SpeedMode {
  fast,
  normal,
  extra,
}

enum QualityPreset {
  low,
  medium,
  high,
  lossless,
}

class ConversionSettings {
  final int? width;
  final int fps;
  final LoopMode loopMode;
  final int quality;
  final int? motionQuality;
  final SpeedMode speedMode;

  const ConversionSettings({
    this.width,
    this.fps = 30,
    this.loopMode = LoopMode.loop,
    this.quality = 80,
    this.motionQuality,
    this.speedMode = SpeedMode.normal,
  });

  bool get isLoop => loopMode != LoopMode.none;
  bool get isBoomerang =>
      loopMode == LoopMode.boomerang || loopMode == LoopMode.boomerangSeamless;

  ConversionSettings copyWith({
    int? Function()? width,
    int? fps,
    LoopMode? loopMode,
    int? quality,
    int? Function()? motionQuality,
    SpeedMode? speedMode,
  }) {
    return ConversionSettings(
      width: width != null ? width() : this.width,
      fps: fps ?? this.fps,
      loopMode: loopMode ?? this.loopMode,
      quality: quality ?? this.quality,
      motionQuality:
          motionQuality != null ? motionQuality() : this.motionQuality,
      speedMode: speedMode ?? this.speedMode,
    );
  }

  static String loopModeLabel(LoopMode mode) {
    switch (mode) {
      case LoopMode.none:
        return 'No loop (play once)';
      case LoopMode.loop:
        return 'Loop';
      case LoopMode.boomerang:
        return 'Boomerang';
      case LoopMode.boomerangSeamless:
        return 'Boomerang (seamless)';
    }
  }

  static String loopModeDescription(LoopMode mode) {
    switch (mode) {
      case LoopMode.none:
        return 'Play once and stop';
      case LoopMode.loop:
        return 'Repeat forward';
      case LoopMode.boomerang:
        return 'Forward then backward';
      case LoopMode.boomerangSeamless:
        return 'Forward then backward, no duplicate frames at edges';
    }
  }

  static String speedModeLabel(SpeedMode mode) {
    switch (mode) {
      case SpeedMode.fast:
        return 'Fast';
      case SpeedMode.normal:
        return 'Normal';
      case SpeedMode.extra:
        return 'Extra';
    }
  }

  static String speedModeDescription(SpeedMode mode) {
    switch (mode) {
      case SpeedMode.fast:
        return 'Faster encoding, slightly lower quality';
      case SpeedMode.normal:
        return 'Balanced speed and quality';
      case SpeedMode.extra:
        return 'Slower encoding for best quality';
    }
  }

  static const List<int?> widthPresets = [
    null,
    256,
    320,
    480,
    512,
    640,
    800,
    1024,
  ];

  static const List<int> fpsPresets = [10, 15, 20, 24, 30, 60];

  /// Returns the matching preset for the current quality settings, or null if custom.
  QualityPreset? get matchingPreset {
    for (final preset in QualityPreset.values) {
      final ref = fromPreset(preset);
      if (quality == ref.quality && motionQuality == ref.motionQuality) {
        return preset;
      }
    }
    return null;
  }

  /// Apply a preset, preserving width, fps, loopMode, and speedMode.
  ConversionSettings applyPreset(QualityPreset preset) {
    final ref = fromPreset(preset);
    return ConversionSettings(
      width: width,
      fps: fps,
      loopMode: loopMode,
      quality: ref.quality,
      motionQuality: ref.motionQuality,
      speedMode: speedMode,
    );
  }

  /// Reference settings for each preset.
  /// Presets control quality + motionQuality (the file-size knobs).
  /// Speed mode is independent (encoding time tradeoff).
  static ConversionSettings fromPreset(QualityPreset preset) {
    return switch (preset) {
      QualityPreset.low => const ConversionSettings(
          quality: 30,
        ),
      QualityPreset.medium => const ConversionSettings(
          quality: 60,
        ),
      QualityPreset.high => const ConversionSettings(
          quality: 80,
        ),
      QualityPreset.lossless => const ConversionSettings(
          quality: 100,
          motionQuality: 100,
        ),
    };
  }

  static String qualityPresetLabel(QualityPreset preset) {
    return switch (preset) {
      QualityPreset.low => 'Low',
      QualityPreset.medium => 'Medium',
      QualityPreset.high => 'High',
      QualityPreset.lossless => 'Lossless',
    };
  }

  static String qualityPresetDescription(QualityPreset preset) {
    return switch (preset) {
      QualityPreset.low => 'Smallest files — visible quality loss',
      QualityPreset.medium =>
        'Good quality with reasonable file size',
      QualityPreset.high => 'Great quality — recommended for most use cases',
      QualityPreset.lossless =>
        'Maximum quality — best colors, full motion detail',
    };
  }

  static String qualityLabel(int quality) {
    if (quality <= 50) return 'Small';
    if (quality <= 70) return 'Good';
    if (quality <= 80) return 'High';
    if (quality <= 90) return 'Best';
    return 'Maximum';
  }
}
