import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/models/conversion_job.dart';
import 'package:gif_converter/models/conversion_settings.dart';
import 'package:gif_converter/services/ffmpeg_service.dart';

void main() {
  late FfmpegService service;

  setUp(() {
    service = FfmpegService();
  });

  group('buildPreFilters', () {
    test('basic filter with default settings', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      expect(result, 'fps=20');
    });

    test('includes scale when width is set', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      const settings = ConversionSettings(width: 640);
      final result = service.buildPreFilters(settings, job);
      expect(result, 'fps=20,scale=640:-2:flags=lanczos');
    });

    test('includes trim when start frame is set', () {
      final job = ConversionJob(inputPath: '/v.mp4', trimStartFrame: 10);
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      expect(result, 'trim=start_frame=10,setpts=PTS-STARTPTS,fps=20');
    });

    test('includes trim when end frame is set', () {
      final job = ConversionJob(inputPath: '/v.mp4', trimEndFrame: 100);
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      expect(result, 'trim=end_frame=100,setpts=PTS-STARTPTS,fps=20');
    });

    test('includes trim with both start and end', () {
      final job = ConversionJob(
          inputPath: '/v.mp4', trimStartFrame: 10, trimEndFrame: 100);
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      expect(result,
          'trim=start_frame=10:end_frame=100,setpts=PTS-STARTPTS,fps=20');
    });

    test('includes crop when crop fields are set', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        cropX: 50,
        cropY: 100,
        cropWidth: 640,
        cropHeight: 480,
      );
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      expect(result, 'fps=20,crop=640:480:50:100');
    });

    test('crop uses iw/ih when width/height not set', () {
      final job = ConversionJob(inputPath: '/v.mp4', cropX: 10);
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      expect(result, 'fps=20,crop=iw:ih:10:0');
    });

    test('full pipeline: trim + fps + scale + crop', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 5,
        trimEndFrame: 50,
        cropX: 0,
        cropY: 0,
        cropWidth: 320,
        cropHeight: 240,
      );
      const settings = ConversionSettings(width: 640, fps: 24);
      final result = service.buildPreFilters(settings, job);
      expect(
        result,
        'trim=start_frame=5:end_frame=50,setpts=PTS-STARTPTS,'
        'fps=24,scale=640:-2:flags=lanczos,'
        'crop=320:240:0:0',
      );
    });

    test('effectiveFps overrides settings fps', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      const settings = ConversionSettings(fps: 30);
      final result =
          service.buildPreFilters(settings, job, effectiveFps: 24);
      expect(result, 'fps=24');
    });

    test('order is trim, fps, scale, crop', () {
      final job = ConversionJob(
        inputPath: '/v.mp4',
        trimStartFrame: 0,
        cropWidth: 100,
        cropHeight: 100,
      );
      const settings = ConversionSettings(width: 480, fps: 30);
      final result = service.buildPreFilters(settings, job);
      final parts = result.split(',');
      // trim comes first
      expect(parts[0], startsWith('trim='));
      // setpts follows trim
      expect(parts[1], 'setpts=PTS-STARTPTS');
      // then fps
      expect(parts[2], startsWith('fps='));
      // then scale
      expect(parts[3], startsWith('scale='));
      // then crop
      expect(parts[4], startsWith('crop='));
    });
  });

  group('buildPreFilters edge cases', () {
    test('no crop when no crop fields set', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      const settings = ConversionSettings(fps: 20);
      final result = service.buildPreFilters(settings, job);
      expect(result, 'fps=20');
      expect(result, isNot(contains('crop')));
    });

    test('crop defaults missing y to 0', () {
      final job = ConversionJob(inputPath: '/v.mp4', cropX: 10, cropY: null);
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      // cropX alone triggers hasCrop
      expect(result, contains('crop=iw:ih:10:0'));
    });

    test('effectiveFps of 50 is used', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      const settings = ConversionSettings(fps: 30);
      final result =
          service.buildPreFilters(settings, job, effectiveFps: 50);
      expect(result, 'fps=50');
    });

    test('scale not added when width is null', () {
      final job = ConversionJob(inputPath: '/v.mp4');
      const settings = ConversionSettings();
      final result = service.buildPreFilters(settings, job);
      expect(result, isNot(contains('scale')));
    });
  });

  group('buildBoomerangFilter', () {
    test('returns empty string for non-boomerang modes', () {
      const loop = ConversionSettings(loopMode: LoopMode.loop);
      expect(service.buildBoomerangFilter(loop), '');

      const none = ConversionSettings(loopMode: LoopMode.none);
      expect(service.buildBoomerangFilter(none), '');
    });

    test('returns forward+backward concat for boomerang', () {
      const settings = ConversionSettings(loopMode: LoopMode.boomerang);
      final result = service.buildBoomerangFilter(settings);
      expect(result, contains('split[fwd][rev]'));
      expect(result, contains('reverse'));
      expect(result, contains('concat=n=2:v=1'));
    });

    test('returns seamless filter for boomerangSeamless', () {
      const settings =
          ConversionSettings(loopMode: LoopMode.boomerangSeamless);
      final result = service.buildBoomerangFilter(settings);
      expect(result, contains('split[fwd][rev]'));
      expect(result, contains('trim=start_frame=1'));
      expect(result, contains('concat=n=2:v=1'));
    });
  });
}
