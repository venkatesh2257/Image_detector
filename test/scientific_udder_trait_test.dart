import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/models/scientific_udder_models.dart';
import 'package:image_detector/services/scientific_udder/stages/stage8_confidence_scoring.dart';
import 'package:image_detector/services/scientific_udder/stages/stage9_trait_regression.dart';

void main() {
  test('confidence scoring accepts passing stages', () {
    const scorer = Stage8ConfidenceScoring();
    const traits = ScientificUdderTraits(
      ruhCm: 10,
      ruwCm: 45,
      rtdCm: 8,
      frtdCm: 9,
      udderDepthProxyCm: 12,
      symmetryIndex: 0.9,
      ruhNorm: 0.2,
      ruwNorm: 0.3,
      rtdNorm: 0.12,
      perTraitConfidence: {'ruh': 0.8, 'ruw': 0.85},
      scaleCmPerNorm: 150,
    );

    final result = scorer.score(
      stages: const [
        ScientificStageMetric(stageId: 'quality', passed: true, score: 0.9, durationMs: 1),
        ScientificStageMetric(
          stageId: 'animal_rear_validity',
          passed: true,
          score: 0.85,
          durationMs: 1,
        ),
        ScientificStageMetric(
          stageId: 'keypoints',
          passed: true,
          score: 0.8,
          durationMs: 1,
        ),
        ScientificStageMetric(stageId: 'traits', passed: true, score: 0.82, durationMs: 1),
      ],
      traits: traits,
    );

    expect(result.scientificallyValid, isTrue);
    expect(result.globalConfidence, greaterThan(0.5));
  });

  test('trait regression returns clamped liters', () {
    const reg = Stage9TraitRegression();
    const traits = ScientificUdderTraits(
      ruhCm: 10,
      ruwCm: 48,
      rtdCm: 9,
      frtdCm: 10,
      udderDepthProxyCm: 11,
      symmetryIndex: 0.88,
      ruhNorm: 0.18,
      ruwNorm: 0.32,
      rtdNorm: 0.11,
      perTraitConfidence: {'ruh': 0.7, 'ruw': 0.75},
      scaleCmPerNorm: 150,
    );

    final out = reg.predict(
      traits: traits,
      globalConfidence: 0.7,
      lactation: 2,
      daysInMilk: 90,
    );

    expect(out.liters, inInclusiveRange(1.0, 30.0));
    expect(out.confidence, greaterThan(0));
  });
}
