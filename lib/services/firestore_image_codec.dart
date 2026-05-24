import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

/// Resize + base64-encode photos for Firestore (1 MiB field limit).
class FirestoreImageCodec {
  static const maxBase64Chars = 700000;

  static Future<String> encodeFile(String sourceImagePath) async {
    final bytes = await File(sourceImagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw FirestoreImageCodecException('Could not decode image');
    }

    final resized = img.copyResize(
      decoded,
      width: decoded.width > 640 ? 640 : decoded.width,
    );
    final jpgBytes = img.encodeJpg(resized, quality: 65);
    final base64Data = base64Encode(jpgBytes);
    if (base64Data.length > maxBase64Chars) {
      throw FirestoreImageCodecException(
        'Image too large for Firestore. Use a smaller photo.',
      );
    }
    return 'data:image/jpeg;base64,$base64Data';
  }

  /// Decode `data:image/jpeg;base64,...` for Storage upload fallback.
  static List<int>? decodeDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

class FirestoreImageCodecException implements Exception {
  FirestoreImageCodecException(this.message);
  final String message;

  @override
  String toString() => message;
}
