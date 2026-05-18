import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/services/rear_anatomy_detector.dart';

void main() {
  test('anatomy constraints on multiple folder images', () {
    final root = Directory(r'assets/images/animal photos');
    if (!root.existsSync()) return;

    final detector = RearAnatomyDetector();
    var tested = 0;

    for (final folder in root.listSync().whereType<Directory>()) {
      for (final file in folder.listSync().whereType<File>()) {
        final path = file.path.toLowerCase();
        if (!path.endsWith('.jpg') && !path.endsWith('.jpeg') && !path.endsWith('.png')) {
          continue;
        }
        final lm = detector.detectFromPath(file.path);
        expect(lm, isNotNull, reason: file.path);

        expect(lm!.leftPin.dx, lessThan(lm.rightPin.dx));
        expect(lm.leftPin.dy, lessThan(lm.udder.dy));
        expect(lm.pointA.dy, lessThan(lm.udder.dy));
        expect(lm.udder.dx, greaterThan(lm.leftPin.dx));
        expect(lm.udder.dx, lessThan(lm.rightPin.dx));
        expect(lm.udder.dy, lessThan(0.85));
        tested++;
        if (tested >= 12) break;
      }
      if (tested >= 12) break;
    }

    expect(tested, greaterThan(3));
  });
}
