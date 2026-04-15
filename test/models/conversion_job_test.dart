import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_job.dart';

void main() {
  group('ConversionJob', () {
    test('default values', () {
      final job = ConversionJob(inputPath: '/test/video.mp4');
      expect(job.status, ConversionJobStatus.pending);
      expect(job.progress, 0.0);
      expect(job.hasTrim, false);
      expect(job.hasCrop, false);
      expect(job.trimStartFrame, isNull);
      expect(job.trimEndFrame, isNull);
      expect(job.cropX, isNull);
      expect(job.cropY, isNull);
      expect(job.cropWidth, isNull);
      expect(job.cropHeight, isNull);
      expect(job.playbackSpeed, 1.0);
    });

    test('hasTrim is true when trimStartFrame is set', () {
      final job = ConversionJob(inputPath: '/v.mp4', trimStartFrame: 10);
      expect(job.hasTrim, true);
    });

    test('hasTrim is true when trimEndFrame is set', () {
      final job = ConversionJob(inputPath: '/v.mp4', trimEndFrame: 100);
      expect(job.hasTrim, true);
    });

    test('hasTrim is true when both trim frames are set', () {
      final job = ConversionJob(
          inputPath: '/v.mp4', trimStartFrame: 10, trimEndFrame: 100);
      expect(job.hasTrim, true);
    });

    test('hasCrop is true when any crop field is set', () {
      expect(ConversionJob(inputPath: '/v.mp4', cropX: 0).hasCrop, true);
      expect(ConversionJob(inputPath: '/v.mp4', cropY: 0).hasCrop, true);
      expect(
          ConversionJob(inputPath: '/v.mp4', cropWidth: 100).hasCrop, true);
      expect(
          ConversionJob(inputPath: '/v.mp4', cropHeight: 100).hasCrop, true);
    });

    test('hasCrop is false when no crop fields are set', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      expect(job.hasCrop, false);
    });
  });

  group('ConversionJob.clampTrim', () {
    test('clears trim when start >= totalFrames', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 500,
        trimEndFrame: 600,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, isNull);
      expect(job.trimEndFrame, isNull);
      expect(job.hasTrim, false);
    });

    test('clears trimEnd when it exceeds totalFrames', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 10,
        trimEndFrame: 500,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, 10);
      expect(job.trimEndFrame, isNull);
    });

    test('keeps trim unchanged when within bounds', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 10,
        trimEndFrame: 100,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, 10);
      expect(job.trimEndFrame, 100);
    });

    test('clears both when start >= end after clamping', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 50,
        trimEndFrame: 50,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, isNull);
      expect(job.trimEndFrame, isNull);
    });

    test('handles null trimStartFrame with out-of-range trimEndFrame', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimEndFrame: 500,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, isNull);
      expect(job.trimEndFrame, isNull);
    });

    test('handles null trimEndFrame', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 10,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, 10);
      expect(job.trimEndFrame, isNull);
    });

    test('no-op when no trim set', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      job.clampTrim(200);
      expect(job.trimStartFrame, isNull);
      expect(job.trimEndFrame, isNull);
    });

    test('clears trim when start equals totalFrames exactly', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 200,
        trimEndFrame: 300,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, isNull);
      expect(job.trimEndFrame, isNull);
    });

    test('keeps trimEnd when it equals totalFrames - 1', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 10,
        trimEndFrame: 199,
      );
      job.clampTrim(200);
      expect(job.trimStartFrame, 10);
      expect(job.trimEndFrame, 199);
    });
  });
}
