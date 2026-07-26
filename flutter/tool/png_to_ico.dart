// Converts a single square PNG into a proper multi-resolution Windows .ico
// (16, 32, 48, 64, 128, 256 px) using the `image` package already vendored
// for this Flutter project.
//
// Note: this deliberately bypasses image's top-level `encodeIco()` helper.
// That helper infers per-size frames from a single Image's `.frames` list
// built via `addFrame()`, but frame 0 in that list is the same object used
// as the container, so it still reports `hasAnimation == true` (it holds
// all the frames, including itself). PngEncoder then encodes THAT entry as
// an animated APNG embedding every resolution again, bloating the "16x16"
// directory entry to tens of KB instead of a plain small PNG. Encoding each
// resized image independently via IcoEncoder.encodeImages() avoids that.
//
// Usage (from flutter/): dart run tool/png_to_ico.dart <source.png> <dest.ico>
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image/src/formats/ico_encoder.dart';

const _sizes = [16, 32, 48, 64, 128, 256];

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
        'Usage: dart run tool/png_to_ico.dart <source.png> <dest.ico>');
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

  final frames = _sizes
      .map((size) => img.copyResize(src,
          width: size, height: size, interpolation: img.Interpolation.cubic))
      .toList();
  for (final frame in frames) {
    assert(!frame.hasAnimation);
  }

  final icoBytes = IcoEncoder().encodeImages(frames);
  File(destPath).writeAsBytesSync(icoBytes);
  stdout.writeln('  OK  $srcPath -> $destPath (${_sizes.join(", ")} px)');
}
