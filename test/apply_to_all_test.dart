import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_job.dart';
import 'package:gif_converter/widgets/video_edit_dialog.dart';

/// Simulates the apply-to-all logic from converter_screen.dart.
void applyResult(VideoEditResult result, List<ConversionJob> jobs) {
  final targets = result.applyToAll ? jobs : [jobs.first];
  for (final target in targets) {
    target.trimStartFrame = result.trimStartFrame;
    target.trimEndFrame = result.trimEndFrame;
    target.cropX = result.cropX;
    target.cropY = result.cropY;
    target.cropWidth = result.cropWidth;
    target.cropHeight = result.cropHeight;
    target.playbackSpeed = result.playbackSpeed;
    if (target.status == ConversionJobStatus.done ||
        target.status == ConversionJobStatus.error) {
      target.status = ConversionJobStatus.pending;
      target.progress = 0;
      target.statusText = '';
      target.errorMessage = null;
    }
  }
}

void main() {
  group('Apply to all', () {
    test('applies trim and crop to all jobs', () {
      final jobs = [
        ConversionJob(inputPath: '/a.mp4'),
        ConversionJob(inputPath: '/b.mp4'),
        ConversionJob(inputPath: '/c.mp4'),
      ];

      const result = VideoEditResult(
        trimStartFrame: 10,
        trimEndFrame: 200,
        cropX: 50,
        cropY: 50,
        cropWidth: 640,
        cropHeight: 480,
        applyToAll: true,
      );

      applyResult(result, jobs);

      for (final job in jobs) {
        expect(job.trimStartFrame, 10);
        expect(job.trimEndFrame, 200);
        expect(job.cropX, 50);
        expect(job.cropY, 50);
        expect(job.cropWidth, 640);
        expect(job.cropHeight, 480);
        expect(job.playbackSpeed, 1.0);
      }
    });

    test('applyToAll=false only applies to first job', () {
      final jobs = [
        ConversionJob(inputPath: '/a.mp4'),
        ConversionJob(inputPath: '/b.mp4'),
      ];

      const result = VideoEditResult(
        trimStartFrame: 10,
        trimEndFrame: 200,
        applyToAll: false,
      );

      applyResult(result, jobs);

      expect(jobs[0].trimStartFrame, 10);
      expect(jobs[0].trimEndFrame, 200);
      expect(jobs[1].trimStartFrame, isNull);
      expect(jobs[1].trimEndFrame, isNull);
    });

    test('resets done jobs to pending when applying', () {
      final jobs = [
        ConversionJob(inputPath: '/a.mp4')
          ..status = ConversionJobStatus.done
          ..progress = 1.0
          ..outputPath = '/a.gif',
        ConversionJob(inputPath: '/b.mp4')
          ..status = ConversionJobStatus.done
          ..progress = 1.0
          ..outputPath = '/b.gif',
      ];

      const result = VideoEditResult(
        trimStartFrame: 5,
        applyToAll: true,
      );

      applyResult(result, jobs);

      for (final job in jobs) {
        expect(job.status, ConversionJobStatus.pending);
        expect(job.progress, 0);
      }
    });

    test('resets error jobs to pending when applying', () {
      final job = ConversionJob(inputPath: '/a.mp4')
        ..status = ConversionJobStatus.error
        ..errorMessage = 'something failed';

      const result = VideoEditResult(
        cropWidth: 100,
        cropHeight: 100,
        applyToAll: true,
      );

      applyResult(result, [job]);
      expect(job.status, ConversionJobStatus.pending);
      expect(job.errorMessage, isNull);
    });

    test('does not reset pending or converting jobs', () {
      final jobs = [
        ConversionJob(inputPath: '/a.mp4')
          ..status = ConversionJobStatus.pending,
        ConversionJob(inputPath: '/b.mp4')
          ..status = ConversionJobStatus.converting
          ..progress = 0.5,
      ];

      const result = VideoEditResult(
        trimStartFrame: 10,
        applyToAll: true,
      );

      applyResult(result, jobs);

      expect(jobs[0].status, ConversionJobStatus.pending);
      expect(jobs[1].status, ConversionJobStatus.converting);
      expect(jobs[1].progress, 0.5);
    });

    test('applies playback speed to all jobs', () {
      final jobs = [
        ConversionJob(inputPath: '/a.mp4'),
        ConversionJob(inputPath: '/b.mp4'),
      ];

      const result = VideoEditResult(
        playbackSpeed: 1.8,
        applyToAll: true,
      );

      applyResult(result, jobs);
      for (final job in jobs) {
        expect(job.playbackSpeed, 1.8);
      }
    });
  });

  group('Apply to all + clampTrim (different video lengths)', () {
    test('trim clamped per video when end exceeds total frames', () {
      final jobs = [
        ConversionJob(inputPath: '/short.mp4'), // 100 frames
        ConversionJob(inputPath: '/long.mp4'), // 500 frames
        ConversionJob(inputPath: '/tiny.mp4'), // 30 frames
      ];
      final totalFrames = [100, 500, 30];

      const result = VideoEditResult(
        trimStartFrame: 10,
        trimEndFrame: 300,
        applyToAll: true,
      );

      applyResult(result, jobs);

      // Simulate what convertToGif does: clamp per video
      for (int i = 0; i < jobs.length; i++) {
        jobs[i].clampTrim(totalFrames[i]);
      }

      // Short video (100 frames): start=10, end=null (300 > 100)
      expect(jobs[0].trimStartFrame, 10);
      expect(jobs[0].trimEndFrame, isNull);

      // Long video (500 frames): start=10, end=300 (within range)
      expect(jobs[1].trimStartFrame, 10);
      expect(jobs[1].trimEndFrame, 300);

      // Tiny video (30 frames): start=10, end=null (300 > 30)
      expect(jobs[2].trimStartFrame, 10);
      expect(jobs[2].trimEndFrame, isNull);
    });

    test('trim cleared entirely when start exceeds video length', () {
      final job = ConversionJob(inputPath: '/tiny.mp4');

      const result = VideoEditResult(
        trimStartFrame: 200,
        trimEndFrame: 300,
        applyToAll: true,
      );

      applyResult(result, [job]);
      job.clampTrim(50); // video is only 50 frames

      expect(job.trimStartFrame, isNull);
      expect(job.trimEndFrame, isNull);
      expect(job.hasTrim, false);
    });

    test('crop is not affected by different video lengths', () {
      final jobs = [
        ConversionJob(inputPath: '/a.mp4'),
        ConversionJob(inputPath: '/b.mp4'),
      ];

      const result = VideoEditResult(
        cropX: 10,
        cropY: 20,
        cropWidth: 640,
        cropHeight: 480,
        applyToAll: true,
      );

      applyResult(result, jobs);

      // Crop values are applied as-is (FFmpeg handles out-of-bounds)
      for (final job in jobs) {
        expect(job.cropX, 10);
        expect(job.cropY, 20);
        expect(job.cropWidth, 640);
        expect(job.cropHeight, 480);
      }
    });

    test('clearing trim via apply-to-all (null values)', () {
      final jobs = [
        ConversionJob(inputPath: '/a.mp4', trimStartFrame: 10, trimEndFrame: 50),
        ConversionJob(inputPath: '/b.mp4', trimStartFrame: 20, trimEndFrame: 100),
      ];

      const result = VideoEditResult(
        trimStartFrame: null,
        trimEndFrame: null,
        applyToAll: true,
      );

      applyResult(result, jobs);

      for (final job in jobs) {
        expect(job.trimStartFrame, isNull);
        expect(job.trimEndFrame, isNull);
        expect(job.hasTrim, false);
      }
    });
  });
}
