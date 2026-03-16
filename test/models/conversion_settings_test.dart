import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_settings.dart';

void main() {
  group('ConversionSettings', () {
    test('default values', () {
      const s = ConversionSettings();
      expect(s.width, isNull);
      expect(s.fps, 30);
      expect(s.loopMode, LoopMode.loop);
      expect(s.quality, 80);
      expect(s.motionQuality, isNull);
      expect(s.speedMode, SpeedMode.normal);
    });

    test('isLoop is true for loop mode', () {
      const s = ConversionSettings(loopMode: LoopMode.loop);
      expect(s.isLoop, true);
    });

    test('isLoop is false for none mode', () {
      const s = ConversionSettings(loopMode: LoopMode.none);
      expect(s.isLoop, false);
    });

    test('isLoop is true for boomerang modes', () {
      expect(
          const ConversionSettings(loopMode: LoopMode.boomerang).isLoop, true);
      expect(
          const ConversionSettings(loopMode: LoopMode.boomerangSeamless).isLoop,
          true);
    });

    test('isBoomerang is true for boomerang modes', () {
      expect(const ConversionSettings(loopMode: LoopMode.boomerang).isBoomerang,
          true);
      expect(
          const ConversionSettings(loopMode: LoopMode.boomerangSeamless)
              .isBoomerang,
          true);
    });

    test('isBoomerang is false for non-boomerang modes', () {
      expect(
          const ConversionSettings(loopMode: LoopMode.loop).isBoomerang, false);
      expect(
          const ConversionSettings(loopMode: LoopMode.none).isBoomerang, false);
    });

    group('copyWith', () {
      test('copies all fields', () {
        const original = ConversionSettings(
          width: 640,
          fps: 24,
          loopMode: LoopMode.boomerang,
          quality: 75,
          speedMode: SpeedMode.fast,
        );
        final copy = original.copyWith();
        expect(copy.width, 640);
        expect(copy.fps, 24);
        expect(copy.loopMode, LoopMode.boomerang);
        expect(copy.quality, 75);
        expect(copy.speedMode, SpeedMode.fast);
      });

      test('can set width to null', () {
        const original = ConversionSettings(width: 640);
        final copy = original.copyWith(width: () => null);
        expect(copy.width, isNull);
      });

      test('can change width', () {
        const original = ConversionSettings(width: 640);
        final copy = original.copyWith(width: () => 320);
        expect(copy.width, 320);
      });

      test('can change fps', () {
        const original = ConversionSettings();
        final copy = original.copyWith(fps: 30);
        expect(copy.fps, 30);
      });

      test('can set and clear motionQuality', () {
        const original = ConversionSettings();
        final withMotion =
            original.copyWith(motionQuality: () => 80);
        expect(withMotion.motionQuality, 80);
        final cleared =
            withMotion.copyWith(motionQuality: () => null);
        expect(cleared.motionQuality, isNull);
      });
    });

    test('widthPresets contains expected values', () {
      expect(ConversionSettings.widthPresets, contains(null));
      expect(ConversionSettings.widthPresets, contains(640));
      expect(ConversionSettings.widthPresets, contains(320));
    });

    test('fpsPresets contains expected values', () {
      expect(ConversionSettings.fpsPresets, contains(15));
      expect(ConversionSettings.fpsPresets, contains(30));
    });

    test('loopModeLabel returns correct labels', () {
      expect(ConversionSettings.loopModeLabel(LoopMode.loop), 'Loop');
      expect(ConversionSettings.loopModeLabel(LoopMode.none),
          'No loop (play once)');
      expect(
          ConversionSettings.loopModeLabel(LoopMode.boomerang), 'Boomerang');
    });

    test('qualityLabel returns correct labels', () {
      expect(ConversionSettings.qualityLabel(50), 'Small');
      expect(ConversionSettings.qualityLabel(70), 'Good');
      expect(ConversionSettings.qualityLabel(90), 'Best');
      expect(ConversionSettings.qualityLabel(100), 'Maximum');
    });

    test('speedModeLabel returns correct labels', () {
      expect(ConversionSettings.speedModeLabel(SpeedMode.fast), 'Fast');
      expect(ConversionSettings.speedModeLabel(SpeedMode.normal), 'Normal');
      expect(
          ConversionSettings.speedModeLabel(SpeedMode.extra), 'Extra effort');
    });

    group('quality presets', () {
      test('matchingPreset detects high preset for defaults', () {
        const s = ConversionSettings();
        expect(s.matchingPreset, QualityPreset.high);
      });

      test('matchingPreset detects each preset', () {
        for (final preset in QualityPreset.values) {
          final s = ConversionSettings.fromPreset(preset);
          expect(s.matchingPreset, preset);
        }
      });

      test('matchingPreset returns null for custom settings', () {
        const s = ConversionSettings(quality: 73);
        expect(s.matchingPreset, isNull);
      });

      test('matchingPreset ignores speedMode', () {
        const s = ConversionSettings(quality: 80, speedMode: SpeedMode.fast);
        expect(s.matchingPreset, QualityPreset.high);
      });

      test('applyPreset preserves width, fps, loopMode, speedMode', () {
        const s = ConversionSettings(
          width: 640,
          fps: 24,
          loopMode: LoopMode.boomerang,
          speedMode: SpeedMode.extra,
        );
        final applied = s.applyPreset(QualityPreset.low);
        expect(applied.width, 640);
        expect(applied.fps, 24);
        expect(applied.loopMode, LoopMode.boomerang);
        expect(applied.speedMode, SpeedMode.extra);
        expect(applied.quality, 30);
        expect(applied.motionQuality, isNull);
      });

      test('lossless preset sets motionQuality to 100', () {
        final s = ConversionSettings.fromPreset(QualityPreset.lossless);
        expect(s.quality, 100);
        expect(s.motionQuality, 100);
      });

      test('low preset leaves motionQuality at default', () {
        final s = ConversionSettings.fromPreset(QualityPreset.low);
        expect(s.quality, 30);
        expect(s.motionQuality, isNull);
      });

      test('medium preset leaves motionQuality at default', () {
        final s = ConversionSettings.fromPreset(QualityPreset.medium);
        expect(s.quality, 60);
        expect(s.motionQuality, isNull);
      });
    });
  });
}
