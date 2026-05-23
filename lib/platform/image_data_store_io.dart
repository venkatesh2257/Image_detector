import 'dart:io';
import 'dart:typed_data';

/// Reads image bytes from a local filesystem path (Windows, Android, iOS, etc.).
class ImageDataStore {
  const ImageDataStore();

  Future<Uint8List> readBytes(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw ImageDataStoreException('File not found: $path');
    }
    return file.readAsBytes();
  }

  bool fileExists(String path) => File(path).existsSync();
}

class ImageDataStoreException implements Exception {
  ImageDataStoreException(this.message);
  final String message;

  @override
  String toString() => message;
}
