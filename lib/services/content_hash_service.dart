import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Perceptual-ish hash for duplicate detection in training pipeline.
class ContentHashService {
  static Future<String> hashFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return hashBytes(bytes);
  }

  static String hashBytes(List<int> bytes) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      return sha256.convert(bytes).toString();
    }
    final small = img.copyResize(decoded, width: 16, height: 16);
    final buffer = StringBuffer();
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final p = small.getPixel(x, y);
        buffer.write(p.r.toInt().toRadixString(16).padLeft(2, '0'));
      }
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }
}
