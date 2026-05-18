import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/services/milk_production_scale.dart';
import 'package:image_detector/services/tflite_classifier_service.dart';

void main() {
  test('clamps liters to 1–30', () {
    expect(MilkProductionScale.clamp(0), 1.0);
    expect(MilkProductionScale.clamp(50), 30.0);
    expect(MilkProductionScale.clamp(12.4), 12.4);
  });

  test('TFLite expected liters is softmax-weighted', () {
    final expected = TfliteClassifierService.expectedLitersFromScores({
      '6_lit': 0.1,
      '7_lit': 0.2,
      '8_lit': 0.2,
      '9_lit': 0.2,
      '10_lit': 0.3,
    });
    expect(expected, isNotNull);
    expect(expected!, greaterThan(8.0));
    expect(expected, lessThan(10.0));
  });
}
