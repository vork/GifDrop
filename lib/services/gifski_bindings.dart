import 'dart:ffi';
import 'package:ffi/ffi.dart';

// ── GifskiSettings struct ──────────────────────────────────────────
// Mirrors: typedef struct GifskiSettings { uint32_t width; uint32_t height;
//   uint8_t quality; bool fast; int16_t repeat; } GifskiSettings;
final class GifskiSettings extends Struct {
  @Uint32()
  external int width;

  @Uint32()
  external int height;

  @Uint8()
  external int quality;

  @Bool()
  external bool fast;

  @Int16()
  external int repeat;
}

// ── Opaque gifski handle ───────────────────────────────────────────
final class GifskiHandle extends Opaque {}

// ── GifskiError codes ──────────────────────────────────────────────
abstract final class GifskiError {
  static const ok = 0;
  static const nullArg = 1;
  static const invalidState = 2;
  static const quant = 3;
  static const gif = 4;
  static const threadLost = 5;
  static const notFound = 6;
  static const permissionDenied = 7;
  static const alreadyExists = 8;
  static const invalidInput = 9;
  static const timedOut = 10;
  static const writeZero = 11;
  static const interrupted = 12;
  static const unexpectedEof = 13;
  static const aborted = 14;
  static const other = 15;

  static String message(int code) {
    return switch (code) {
      ok => 'OK',
      nullArg => 'Null argument',
      invalidState => 'Invalid state',
      quant => 'Quantization error',
      gif => 'GIF encoding error',
      threadLost => 'Thread lost',
      notFound => 'Not found',
      permissionDenied => 'Permission denied',
      alreadyExists => 'Already exists',
      invalidInput => 'Invalid input',
      timedOut => 'Timed out',
      writeZero => 'Write zero',
      interrupted => 'Interrupted',
      unexpectedEof => 'Unexpected EOF',
      aborted => 'Aborted',
      _ => 'Unknown error ($code)',
    };
  }
}

class GifskiException implements Exception {
  final String context;
  final int code;
  GifskiException(this.context, this.code);

  @override
  String toString() => '$context: ${GifskiError.message(code)}';
}

void checkGifskiError(int code, String context) {
  if (code != GifskiError.ok) {
    throw GifskiException(context, code);
  }
}

// ── Native function typedefs ───────────────────────────────────────

// gifski *gifski_new(const GifskiSettings *settings)
typedef _GifskiNewNative = Pointer<GifskiHandle> Function(
    Pointer<GifskiSettings>);
typedef GifskiNewDart = Pointer<GifskiHandle> Function(
    Pointer<GifskiSettings>);

// GifskiError gifski_finish(gifski *g)
typedef _GifskiFinishNative = Int32 Function(Pointer<GifskiHandle>);
typedef GifskiFinishDart = int Function(Pointer<GifskiHandle>);

// GifskiError gifski_set_motion_quality(gifski *handle, uint8_t quality)
typedef _GifskiSetMotionQualityNative = Int32 Function(
    Pointer<GifskiHandle>, Uint8);
typedef GifskiSetMotionQualityDart = int Function(
    Pointer<GifskiHandle>, int);

// GifskiError gifski_set_extra_effort(gifski *handle, bool extra)
typedef _GifskiSetExtraEffortNative = Int32 Function(
    Pointer<GifskiHandle>, Bool);
typedef GifskiSetExtraEffortDart = int Function(
    Pointer<GifskiHandle>, bool);

// GifskiError gifski_set_file_output(gifski *handle, const char *path)
typedef _GifskiSetFileOutputNative = Int32 Function(
    Pointer<GifskiHandle>, Pointer<Utf8>);
typedef GifskiSetFileOutputDart = int Function(
    Pointer<GifskiHandle>, Pointer<Utf8>);

// GifskiError gifski_add_frame_png_file(gifski *handle, uint32_t frame_number,
//   const char *file_path, double presentation_timestamp)
typedef _GifskiAddFramePngFileNative = Int32 Function(
    Pointer<GifskiHandle>, Uint32, Pointer<Utf8>, Double);
typedef GifskiAddFramePngFileDart = int Function(
    Pointer<GifskiHandle>, int, Pointer<Utf8>, double);

// ── Bindings class ─────────────────────────────────────────────────

class GifskiBindings {
  final GifskiNewDart gifskiNew;
  final GifskiFinishDart gifskiFinish;
  final GifskiSetMotionQualityDart gifskiSetMotionQuality;
  final GifskiSetExtraEffortDart gifskiSetExtraEffort;
  final GifskiSetFileOutputDart gifskiSetFileOutput;
  final GifskiAddFramePngFileDart gifskiAddFramePngFile;

  GifskiBindings(DynamicLibrary lib)
      : gifskiNew = lib
            .lookupFunction<_GifskiNewNative, GifskiNewDart>('gifski_new'),
        gifskiFinish = lib
            .lookupFunction<_GifskiFinishNative, GifskiFinishDart>(
                'gifski_finish'),
        gifskiSetMotionQuality = lib.lookupFunction<
            _GifskiSetMotionQualityNative,
            GifskiSetMotionQualityDart>('gifski_set_motion_quality'),
        gifskiSetExtraEffort = lib.lookupFunction<
            _GifskiSetExtraEffortNative,
            GifskiSetExtraEffortDart>('gifski_set_extra_effort'),
        gifskiSetFileOutput = lib.lookupFunction<
            _GifskiSetFileOutputNative,
            GifskiSetFileOutputDart>('gifski_set_file_output'),
        gifskiAddFramePngFile = lib.lookupFunction<
            _GifskiAddFramePngFileNative,
            GifskiAddFramePngFileDart>('gifski_add_frame_png_file');
}
