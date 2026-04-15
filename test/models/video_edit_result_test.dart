import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_job.dart';
import 'package:gif_converter/widgets/video_edit_dialog.dart';

void main() {
  group('VideoEditResult', () {
    test('default values', () {
      const result = VideoEditResult();
      expect(result.trimStartFrame, isNull);
      expect(result.trimEndFrame, isNull);
      expect(result.cropX, isNull);
      expect(result.cropY, isNull);
      expect(result.cropWidth, isNull);
      expect(result.cropHeight, isNull);
      expect(result.playbackSpeed, 1.0);
      expect(result.transparencyKeyMode, TransparencyKeyMode.none);
      expect(result.applyToAll, false);
    });

    test('stores trim values', () {
      const result = VideoEditResult(
        trimStartFrame: 10,
        trimEndFrame: 200,
      );
      expect(result.trimStartFrame, 10);
      expect(result.trimEndFrame, 200);
    });

    test('stores crop values', () {
      const result = VideoEditResult(
        cropX: 50,
        cropY: 100,
        cropWidth: 640,
        cropHeight: 480,
      );
      expect(result.cropX, 50);
      expect(result.cropY, 100);
      expect(result.cropWidth, 640);
      expect(result.cropHeight, 480);
    });

    test('applyToAll flag', () {
      const result = VideoEditResult(applyToAll: true);
      expect(result.applyToAll, true);
    });

    test('stores playback speed', () {
      const result = VideoEditResult(playbackSpeed: 1.5);
      expect(result.playbackSpeed, 1.5);
    });

    test('stores transparency key mode', () {
      const result = VideoEditResult(
        transparencyKeyMode: TransparencyKeyMode.white,
      );
      expect(result.transparencyKeyMode, TransparencyKeyMode.white);
    });

    test('stores all values together', () {
      const result = VideoEditResult(
        trimStartFrame: 5,
        trimEndFrame: 150,
        cropX: 10,
        cropY: 20,
        cropWidth: 300,
        cropHeight: 200,
        playbackSpeed: 0.75,
        transparencyKeyMode: TransparencyKeyMode.black,
        applyToAll: true,
      );
      expect(result.trimStartFrame, 5);
      expect(result.trimEndFrame, 150);
      expect(result.cropX, 10);
      expect(result.cropY, 20);
      expect(result.cropWidth, 300);
      expect(result.cropHeight, 200);
      expect(result.playbackSpeed, 0.75);
      expect(result.transparencyKeyMode, TransparencyKeyMode.black);
      expect(result.applyToAll, true);
    });
  });
}
