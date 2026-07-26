// Converts a single square PNG into a proper multi-resolution Windows .ico
// (16, 32, 48, 64, 128, 256 px) using the `image` package already vendored
// for this Flutter project.
//
// Usage (from flutter/): dart run tool/png_to_ico.dart <source.png> <dest.ico>
import 'dart:io';
import 'package:image/image.dart' as img;

const _sizes = [16, 32, 48, 64, 128, 256];

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run scripts/png_to_ico.dart <source.png> <dest.ico>');
    exit(1);
  }
  final srcPath = args[0];
  final destPath = args[1];

  final bytes = File(srcPath).readAsBytesSync();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('ERROR: could not decode image: $srcPath');
    exit(1);
  }

  img.Image? multiRes;
  for (final size in _sizes) {
    final resized = img.copyResize(src,
        width: size, height: size, interpolation: img.Interpolation.cubic);
    if (multiRes == null) {
      multiRes = resized;
    } else {
      multiRes.addFrame(resized);
    }
  }

  final icoBytes = img.encodeIco(multiRes!);
  File(destPath).writeAsBytesSync(icoBytes);
  stdout.writeln('  OK  $srcPath -> $destPath (${_sizes.join(", ")} px)');
}
