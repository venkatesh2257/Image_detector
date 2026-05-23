import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/services/yield_fusion_service.dart';

void main() {
  test('fusion produces min-max band around mirror liters', () {
    final result = YieldFusionService().fuse(
      const YieldFusionInput(
        mirrorLiters: 8.0,
        mirrorConfidence: 0.74,
        mirrorSuccess: true,
        tfliteTrained: true,
        tfliteValAccuracy: 0.36,
        daysInMilk: 120,
        lactation: 2,
        areaNorm: 0.22,
      ),
    );

    expect(result.litersPerDay, greaterThan(0));
    expect(result.yieldMin, lessThanOrEqualTo(result.litersPerDay));
    expect(result.yieldMax, greaterThanOrEqualTo(result.litersPerDay));
    expect(result.displayLabel, contains('L/day'));
  });

  test('low mirror confidence yields caution status', () {
    final result = YieldFusionService().fuse(
      const YieldFusionInput(
        mirrorLiters: 5.0,
        mirrorConfidence: 0.3,
        mirrorSuccess: false,
        tfliteTrained: false,
      ),
    );

    expect(result.status, YieldPredictionStatus.caution);
  });
}
