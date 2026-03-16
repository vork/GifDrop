import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'gifski_bindings.dart';

class GifskiLibrary {
  static GifskiBindings? _bindings;

  static GifskiBindings get bindings {
    _bindings ??= GifskiBindings(_openLibrary());
    return _bindings!;
  }

  static DynamicLibrary _openLibrary() {
    final execDir = p.dirname(Platform.resolvedExecutable);
    String bundledPath;

    if (Platform.isMacOS) {
      bundledPath = p.join(execDir, '..', 'Resources', 'libgifski.dylib');
    } else if (Platform.isWindows) {
      bundledPath = p.join(execDir, 'data', 'gifski.dll');
    } else {
      bundledPath = p.join(execDir, 'lib', 'libgifski.so');
    }

    if (File(bundledPath).existsSync()) {
      return DynamicLibrary.open(bundledPath);
    }

    // Fall back to system library search
    final name = Platform.isMacOS
        ? 'libgifski.dylib'
        : Platform.isWindows
            ? 'gifski.dll'
            : 'libgifski.so';
    return DynamicLibrary.open(name);
  }
}
