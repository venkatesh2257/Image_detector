import 'dart:convert';
import 'dart:typed_data';

/// Web stub: gallery paths are blob URLs — prefer [XFile.readAsBytes] at pick time.
class ImageDataStore {
  const ImageDataStore();

  Future<Uint8List> readBytes(String path) async {
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma < 0) {
        throw ImageDataStoreException('Invalid data URL');
      }
      return base64Decode(path.substring(comma + 1));
    }
    throw ImageDataStoreException(
      'Cannot read filesystem path on web. Use XFile.readAsBytes() when picking.',
    );
  }

  bool fileExists(String path) => false;
}

class ImageDataStoreException implements Exception {
  ImageDataStoreException(this.message);
  final String message;

  @override
  String toString() => message;
}
