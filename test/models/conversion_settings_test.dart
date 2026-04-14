import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_settings.dart';

void main() {
  group('ConversionSettings', () {
    test('default values', () {
      const s = ConversionSettings();
      expect(s.width, isNull);
      expect(s.fps, 20);
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
          ConversionSettings.speedModeLabel(SpeedMode.extra), 'Extra');
    });

    test('loopModeDescription returns correct descriptions', () {
      expect(ConversionSettings.loopModeDescription(LoopMode.none),
          'Play once and stop');
      expect(ConversionSettings.loopModeDescription(LoopMode.loop),
          'Repeat forward');
      expect(ConversionSettings.loopModeDescription(LoopMode.boomerang),
          'Forward then backward');
      expect(
          ConversionSettings.loopModeDescription(LoopMode.boomerangSeamless),
          'Forward then backward, no duplicate frames at edges');
    });

    test('loopModeLabel covers all modes', () {
      expect(ConversionSettings.loopModeLabel(LoopMode.boomerangSeamless),
          'Boomerang (seamless)');
    });

    test('speedModeDescription returns correct descriptions', () {
      expect(ConversionSettings.speedModeDescription(SpeedMode.fast),
          'Faster encoding, slightly lower quality');
      expect(ConversionSettings.speedModeDescription(SpeedMode.normal),
          'Balanced speed and quality');
      expect(ConversionSettings.speedModeDescription(SpeedMode.extra),
          'Slower encoding for best quality');
    });

    test('qualityPresetLabel returns correct labels', () {
      expect(
          ConversionSettings.qualityPresetLabel(QualityPreset.low), 'Low');
      expect(ConversionSettings.qualityPresetLabel(QualityPreset.medium),
          'Medium');
      expect(
          ConversionSettings.qualityPresetLabel(QualityPreset.high), 'High');
      expect(ConversionSettings.qualityPresetLabel(QualityPreset.lossless),
          'Lossless');
    });

    test('qualityPresetDescription returns correct descriptions', () {
      expect(
          ConversionSettings.qualityPresetDescription(QualityPreset.low),
          'Smallest files — visible quality loss');
      expect(
          ConversionSettings.qualityPresetDescription(QualityPreset.medium),
          'Good quality with reasonable file size');
      expect(
          ConversionSettings.qualityPresetDescription(QualityPreset.high),
          'Great quality — recommended for most use cases');
      expect(
          ConversionSettings.qualityPresetDescription(QualityPreset.lossless),
          'Maximum quality — best colors, full motion detail');
    });

    test('qualityLabel boundary values', () {
      expect(ConversionSettings.qualityLabel(1), 'Small');
      expect(ConversionSettings.qualityLabel(51), 'Good');
      expect(ConversionSettings.qualityLabel(71), 'High');
      expect(ConversionSettings.qualityLabel(80), 'High');
      expect(ConversionSettings.qualityLabel(81), 'Best');
      expect(ConversionSettings.qualityLabel(91), 'Maximum');
    });

    test('fpsPresets contains 50 fps option (max for GIF)', () {
      expect(ConversionSettings.fpsPresets, contains(50));
      expect(ConversionSettings.fpsPresets, isNot(contains(60)));
    });

    test('widthPresets starts with null (original) and is sorted', () {
      expect(ConversionSettings.widthPresets.first, isNull);
      final nonNull = ConversionSettings.widthPresets
          .where((w) => w != null)
          .cast<int>()
          .toList();
      for (int i = 1; i < nonNull.length; i++) {
        expect(nonNull[i], greaterThan(nonNull[i - 1]));
      }
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

      test('high preset quality and motionQuality', () {
        final s = ConversionSettings.fromPreset(QualityPreset.high);
        expect(s.quality, 80);
        expect(s.motionQuality, isNull);
      });

      test('applyPreset lossless sets motionQuality', () {
        const s = ConversionSettings(quality: 50, width: 320);
        final applied = s.applyPreset(QualityPreset.lossless);
        expect(applied.quality, 100);
        expect(applied.motionQuality, 100);
        expect(applied.width, 320);
      });

      test('matchingPreset with motionQuality set returns null for non-lossless', () {
        const s = ConversionSettings(quality: 80, motionQuality: 50);
        expect(s.matchingPreset, isNull);
      });

      test('matchingPreset detects lossless with motionQuality', () {
        const s = ConversionSettings(quality: 100, motionQuality: 100);
        expect(s.matchingPreset, QualityPreset.lossless);
      });

      test('fromPreset values are consistent with matchingPreset', () {
        for (final preset in QualityPreset.values) {
          final settings = ConversionSettings.fromPreset(preset);
          final detected = settings.matchingPreset;
          expect(detected, preset,
              reason: '$preset round-trips through fromPreset/matchingPreset');
        }
      });
    });
  });
}
