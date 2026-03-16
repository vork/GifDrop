import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_settings.dart';

void main() {
  group('ConversionSettings', () {
    test('default values', () {
      const s = ConversionSettings();
      expect(s.width, isNull);
      expect(s.fps, 15);
      expect(s.loopMode, LoopMode.loop);
      expect(s.useLocalColorTables, true);
      expect(s.ditherMode, 'bayer');
      expect(s.bayerScale, 3);
      expect(s.enableLossyCompression, false);
      expect(s.lossyLevel, 40);
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
          useLocalColorTables: false,
          ditherMode: 'none',
          bayerScale: 5,
          enableLossyCompression: true,
          lossyLevel: 100,
        );
        final copy = original.copyWith();
        expect(copy.width, 640);
        expect(copy.fps, 24);
        expect(copy.loopMode, LoopMode.boomerang);
        expect(copy.useLocalColorTables, false);
        expect(copy.ditherMode, 'none');
        expect(copy.bayerScale, 5);
        expect(copy.enableLossyCompression, true);
        expect(copy.lossyLevel, 100);
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

    test('ditherModeLabel returns correct labels', () {
      expect(ConversionSettings.ditherModeLabel('bayer'), 'Bayer (ordered)');
      expect(ConversionSettings.ditherModeLabel('none'), 'None');
      expect(ConversionSettings.ditherModeLabel('unknown'), 'unknown');
    });
  });
}
