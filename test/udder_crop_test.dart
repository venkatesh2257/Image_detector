import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/services/udder_escutcheon_crop_service.dart';

void main() {
  test('builds escutcheon crop from 10 lit buffalo', () {
    const path = r'assets/images/animal photos/10 lit/k3 (2).jpg';
    if (!File(path).existsSync()) return;

    final crop = UdderEscutcheonCropService().buildCrop(path);
    expect(crop, isNotNull);
    expect(crop!.isValid, isTrue);
    expect(File(crop.cropPath).existsSync(), isTrue);
    expect(crop.cropWidth, greaterThan(64));
    expect(crop.cropHeight, greaterThan(64));
  });
}
