import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/services/sex_classifier_service.dart';

void main() {
  test('sex classifier on 7 lit sample photo', () {
    final path = r'assets/images/animal photos/7 lit/k2 (2).jpg';
    if (!File(path).existsSync()) {
      // Skip when asset path not available in CI
      return;
    }
    final result = SexClassifierService().classifyFile(path, udderKeypointDetected: true);
    expect(result.label, 'Female');
    expect(result.confidence, greaterThan(0.5));
  });
}
