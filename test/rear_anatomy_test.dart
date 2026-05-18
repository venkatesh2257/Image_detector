import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/services/rear_anatomy_detector.dart';

void main() {
  test('pin bones above udder on rear buffalo photo', () {
    const path = r'assets/images/animal photos/9 lit/k3 (2).jpg';
    if (!File(path).existsSync()) return;

    final landmarks = RearAnatomyDetector().detectFromPath(path);
    expect(landmarks, isNotNull);

    expect(landmarks!.leftPin.dy, lessThan(landmarks.udder.dy));
    expect(landmarks.rightPin.dy, lessThan(landmarks.udder.dy));
    expect(landmarks.udder.dy, lessThan(0.8));
    expect(landmarks.leftPin.dy, greaterThan(0.2));
    expect(landmarks.rightPin.dx - landmarks.leftPin.dx, greaterThan(0.1));
  });
}
