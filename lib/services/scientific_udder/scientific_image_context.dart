import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

/// Shared decoded image for scientific pipeline stages.
class ScientificImageContext {
  ScientificImageContext({
    required this.sourcePath,
    required this.original,
    required this.width,
    required this.height,
    required this.working,
  });

  final String sourcePath;
  final img.Image original;
  final int width;
  final int height;
  img.Image working;

  factory ScientificImageContext.fromPath(String path) {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw FormatException('Cannot decode image: $path');
    }
    final baked = img.bakeOrientation(decoded);
    return ScientificImageContext(
      sourcePath: path,
      original: baked,
      working: img.Image.from(baked),
      width: baked.width,
      height: baked.height,
    );
  }

  /// Normalized coords [0,1] → pixel.
  img.Point pixelFromNorm(double nx, double ny) {
    final x = (nx * width).round().clamp(0, width - 1);
    final y = (ny * height).round().clamp(0, height - 1);
    return img.Point(x, y);
  }

  double normDistance(Offset a, Offset b) {
    final dx = (a.dx - b.dx) * width;
    final dy = (a.dy - b.dy) * height;
    return math.sqrt(dx * dx + dy * dy);
  }

  Future<String?> writeWorkingToTemp(String suffix) async {
    final dir = Directory.systemTemp.createTempSync('milk_mirror_sci_');
    final out = File('${dir.path}/$suffix.jpg');
    await out.writeAsBytes(img.encodeJpg(working, quality: 88));
    return out.path;
  }
}
