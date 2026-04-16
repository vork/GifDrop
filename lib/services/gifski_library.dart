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
      bundledPath = p.join(execDir, '..', 'Frameworks', 'libgifski.dylib');
    } else if (Platform.isWindows) {
      bundledPath = p.join(execDir, 'data', 'gifski.dll');
    } else {
      bundledPath = p.join(execDir, 'lib', 'libgifski.so');
    }

    if (File(bundledPath).existsSync()) {
      return DynamicLibrary.open(bundledPath);
    }

    throw Exception(
      'Bundled gifski library not found at:\n'
      '  $bundledPath\n'
      'This app requires the bundled gifski library and will not use system library search.',
    );
  }
}
