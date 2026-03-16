import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/widgets/crop_overlay.dart';

void main() {
  group('CropOverlay', () {
    testWidgets('renders without error', (tester) async {
      Rect? lastCrop;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CropOverlay(
              imageSize: const Size(1920, 1080),
              displaySize: const Size(960, 540),
              onCropChanged: (r) => lastCrop = r,
            ),
          ),
        ),
      );
      expect(find.byType(CropOverlay), findsOneWidget);
      // No interaction yet, so callback should not have fired
      expect(lastCrop, isNull);
    });

    testWidgets('initialCrop sets starting crop rect', (tester) async {
      Rect? lastCrop;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CropOverlay(
              imageSize: const Size(1920, 1080),
              displaySize: const Size(960, 540),
              initialCrop: const Rect.fromLTWH(100, 100, 800, 600),
              onCropChanged: (r) => lastCrop = r,
            ),
          ),
        ),
      );
      expect(find.byType(CropOverlay), findsOneWidget);
      // The overlay exists with the initial crop
      expect(lastCrop, isNull); // no interaction = no callback
    });

    testWidgets('drag inside the crop moves it and fires onCropChanged',
        (tester) async {
      Rect? lastCrop;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );

      // Drag from center of the overlay
      final center = tester.getCenter(find.byType(CropOverlay));
      await tester.dragFrom(center, const Offset(50, 30));
      await tester.pumpAndSettle();

      // When crop is full-frame and we drag, the crop rect shifts
      // The callback should have been called
      expect(lastCrop, isNotNull);
    });

    testWidgets('aspect ratio constraint adjusts crop on widget update',
        (tester) async {
      Rect? lastCrop;
      // Start with no aspect ratio
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  initialCrop: const Rect.fromLTWH(100, 100, 800, 600),
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );

      // Now update with 1:1 aspect ratio
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  initialCrop: const Rect.fromLTWH(100, 100, 800, 600),
                  aspectRatio: 1.0,
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The crop should have been adjusted to 1:1 ratio
      expect(lastCrop, isNotNull);
      // Width should equal height (in image pixels)
      expect(lastCrop!.width, closeTo(lastCrop!.height, 1.0));
    });

    testWidgets('16:9 aspect ratio produces correct proportions',
        (tester) async {
      Rect? lastCrop;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );

      // Update with 16:9 ratio
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  aspectRatio: 16 / 9,
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lastCrop, isNotNull);
      final ratio = lastCrop!.width / lastCrop!.height;
      expect(ratio, closeTo(16 / 9, 0.05));
    });

    testWidgets('9:16 portrait ratio constrains correctly', (tester) async {
      Rect? lastCrop;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );

      // Update with 9:16 ratio (portrait)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  aspectRatio: 9 / 16,
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lastCrop, isNotNull);
      final ratio = lastCrop!.width / lastCrop!.height;
      expect(ratio, closeTo(9 / 16, 0.05));
      // Width should be less than height for portrait
      expect(lastCrop!.width, lessThan(lastCrop!.height));
    });

    testWidgets('switching from ratio back to free does not fire callback',
        (tester) async {
      Rect? lastCrop;
      // Start with 1:1
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  aspectRatio: 1.0,
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );

      lastCrop = null;

      // Switch to free (null)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 540,
                child: CropOverlay(
                  imageSize: const Size(1920, 1080),
                  displaySize: const Size(960, 540),
                  onCropChanged: (r) => lastCrop = r,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switching to free (null) should not trigger callback
      expect(lastCrop, isNull);
    });
  });
}
