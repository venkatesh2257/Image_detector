import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_detector/services/image_quality_validator.dart';

void main() {
  test('rejects very dark synthetic image', () {
    final image = img.Image(width: 400, height: 500);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 10, 10, 12);
      }
    }
    final jpg = img.encodeJpg(image);
    const validator = ImageQualityValidator();
    final result = validator.validateBytes(jpg);
    expect(result.passed, isFalse);
    expect(result.issues, isNotEmpty);
  });
}
