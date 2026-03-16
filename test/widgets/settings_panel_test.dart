import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_settings.dart';
import 'package:gif_converter/widgets/settings_panel.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  group('SettingsPanel', () {
    late ConversionSettings settings;
    late ConversionSettings? lastChanged;

    setUp(() {
      settings = const ConversionSettings();
      lastChanged = null;
    });

    testWidgets('renders all section titles', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
      )));

      expect(find.text('Resolution (width)'), findsOneWidget);
      expect(find.text('Frame Rate (FPS)'), findsOneWidget);
      expect(find.text('Loop Mode'), findsOneWidget);
      expect(find.text('Quality Preset'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
    });

    testWidgets('renders all resolution presets as chips', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
      )));

      expect(find.text('Original'), findsOneWidget);
      for (final width in ConversionSettings.widthPresets) {
        if (width != null) {
          expect(find.text('$width'), findsOneWidget);
        }
      }
    });

    testWidgets('renders all fps presets including 60', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
      )));

      for (final fps in ConversionSettings.fpsPresets) {
        expect(find.text('$fps'), findsOneWidget);
      }
    });

    testWidgets('renders all loop mode options', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
      )));

      for (final mode in LoopMode.values) {
        expect(
          find.text(ConversionSettings.loopModeLabel(mode)),
          findsOneWidget,
        );
      }
    });

    testWidgets('renders all quality presets', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
      )));

      for (final preset in QualityPreset.values) {
        expect(
          find.text(ConversionSettings.qualityPresetLabel(preset)),
          findsOneWidget,
        );
      }
    });

    testWidgets('selecting a resolution fires callback with correct width',
        (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (s) => lastChanged = s,
      )));

      await tester.tap(find.text('640'));
      expect(lastChanged?.width, 640);
    });

    testWidgets('selecting Original sets width to null', (tester) async {
      settings = const ConversionSettings(width: 640);
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (s) => lastChanged = s,
      )));

      await tester.tap(find.text('Original'));
      expect(lastChanged?.width, isNull);
    });

    testWidgets('selecting fps fires callback', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (s) => lastChanged = s,
      )));

      await tester.tap(find.text('60'));
      expect(lastChanged?.fps, 60);
    });

    testWidgets('selecting loop mode fires callback', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (s) => lastChanged = s,
      )));

      await tester.tap(find.text('Boomerang'));
      expect(lastChanged?.loopMode, LoopMode.boomerang);
    });

    testWidgets('selecting quality preset applies preset values',
        (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (s) => lastChanged = s,
      )));

      await tester.tap(find.text('Low'));
      expect(lastChanged?.quality, 30);
      expect(lastChanged?.motionQuality, isNull);
    });

    testWidgets('shows custom chip when quality does not match any preset',
        (tester) async {
      settings = const ConversionSettings(quality: 73);
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
      )));

      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('does not show custom chip when preset matches',
        (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
      )));

      expect(find.text('Custom'), findsNothing);
    });

    testWidgets('shows fps capping warning when minSourceFps is lower',
        (tester) async {
      settings = const ConversionSettings(fps: 30);
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
        minSourceFps: 24,
      )));

      expect(find.textContaining('Will use 24 fps'), findsOneWidget);
    });

    testWidgets('does not show fps warning when source fps is sufficient',
        (tester) async {
      settings = const ConversionSettings(fps: 24);
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (_) {},
        minSourceFps: 30,
      )));

      expect(find.textContaining('Will use'), findsNothing);
    });

    testWidgets('all controls disabled when enabled=false', (tester) async {
      await tester.pumpWidget(_wrap(SettingsPanel(
        settings: settings,
        onSettingsChanged: (s) => lastChanged = s,
        enabled: false,
      )));

      // Tap a chip — callback should NOT fire
      await tester.tap(find.text('640'));
      expect(lastChanged, isNull);
    });

    group('advanced section', () {
      testWidgets('advanced section is collapsed by default', (tester) async {
        await tester.pumpWidget(_wrap(SettingsPanel(
          settings: settings,
          onSettingsChanged: (_) {},
        )));

        // Quality slider label should not be visible
        expect(find.text('Quality:'), findsNothing);
        expect(find.text('Speed:'), findsNothing);
      });

      testWidgets('expanding advanced shows quality and speed controls',
          (tester) async {
        await tester.pumpWidget(_wrap(SettingsPanel(
          settings: settings,
          onSettingsChanged: (_) {},
        )));

        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();

        expect(find.text('Quality:'), findsOneWidget);
        expect(find.text('Speed:'), findsOneWidget);
      });

      testWidgets('motion quality checkbox unchecked by default',
          (tester) async {
        await tester.pumpWidget(_wrap(SettingsPanel(
          settings: settings,
          onSettingsChanged: (_) {},
        )));

        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();

        expect(find.text('Uses quality value'), findsOneWidget);
      });

      testWidgets('checking motion quality checkbox sets motionQuality',
          (tester) async {
        await tester.pumpWidget(_wrap(SettingsPanel(
          settings: settings,
          onSettingsChanged: (s) => lastChanged = s,
        )));

        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();

        // Find and tap the checkbox
        final checkbox = find.byType(Checkbox);
        expect(checkbox, findsOneWidget);
        await tester.tap(checkbox);

        expect(lastChanged?.motionQuality, settings.quality);
      });

      testWidgets('unchecking motion quality clears motionQuality',
          (tester) async {
        settings = const ConversionSettings(quality: 80, motionQuality: 60);
        await tester.pumpWidget(_wrap(SettingsPanel(
          settings: settings,
          onSettingsChanged: (s) => lastChanged = s,
        )));

        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();

        final checkbox = find.byType(Checkbox);
        await tester.tap(checkbox);

        expect(lastChanged?.motionQuality, isNull);
      });
    });
  });
}
