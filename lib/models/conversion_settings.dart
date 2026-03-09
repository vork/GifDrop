enum LoopMode {
  none,
  loop,
  boomerang,
  boomerangSeamless,
}

class ConversionSettings {
  final int? width;
  final int fps;
  final LoopMode loopMode;
  final bool useLocalColorTables;
  final String ditherMode;
  final int bayerScale;
  final bool enableLossyCompression;
  final int lossyLevel;

  const ConversionSettings({
    this.width,
    this.fps = 15,
    this.loopMode = LoopMode.loop,
    this.useLocalColorTables = true,
    this.ditherMode = 'bayer',
    this.bayerScale = 3,
    this.enableLossyCompression = false,
    this.lossyLevel = 40,
  });

  bool get isLoop => loopMode != LoopMode.none;
  bool get isBoomerang =>
      loopMode == LoopMode.boomerang || loopMode == LoopMode.boomerangSeamless;

  ConversionSettings copyWith({
    int? Function()? width,
    int? fps,
    LoopMode? loopMode,
    bool? useLocalColorTables,
    String? ditherMode,
    int? bayerScale,
    bool? enableLossyCompression,
    int? lossyLevel,
  }) {
    return ConversionSettings(
      width: width != null ? width() : this.width,
      fps: fps ?? this.fps,
      loopMode: loopMode ?? this.loopMode,
      useLocalColorTables: useLocalColorTables ?? this.useLocalColorTables,
      ditherMode: ditherMode ?? this.ditherMode,
      bayerScale: bayerScale ?? this.bayerScale,
      enableLossyCompression:
          enableLossyCompression ?? this.enableLossyCompression,
      lossyLevel: lossyLevel ?? this.lossyLevel,
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

  static const List<int> fpsPresets = [10, 15, 20, 24, 30];

  static const List<String> ditherModes = [
    'bayer',
    'floyd_steinberg',
    'sierra2_4a',
    'none',
  ];

  static String ditherModeLabel(String mode) {
    switch (mode) {
      case 'bayer':
        return 'Bayer (ordered)';
      case 'floyd_steinberg':
        return 'Floyd-Steinberg';
      case 'sierra2_4a':
        return 'Sierra';
      case 'none':
        return 'None';
      default:
        return mode;
    }
  }
}
