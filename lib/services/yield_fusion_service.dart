import 'dart:math' as math;

import 'inference_logger.dart';
import 'milk_production_scale.dart';
import 'tflite_classifier_service.dart';

/// Farmer + image fusion output (Phase B).
enum YieldPredictionStatus {
  highConfidence,
  caution,
  blocked,
}

class YieldFusionInput {
  const YieldFusionInput({
    required this.mirrorLiters,
    required this.mirrorConfidence,
    required this.mirrorSuccess,
    this.tflite,
    this.tfliteValAccuracy = 0,
    this.tfliteTrained = false,
    this.age = 5,
    this.lactation = 1,
    this.daysInMilk = 30,
    this.feed = 'Standard',
    this.symmetryIndex = 0.5,
    this.areaNorm = 0.2,
  });

  final double mirrorLiters;
  final double mirrorConfidence;
  final bool mirrorSuccess;
  final TflitePrediction? tflite;
  final double tfliteValAccuracy;
  final bool tfliteTrained;
  final int age;
  final int lactation;
  final int daysInMilk;
  final String feed;
  final double symmetryIndex;
  final double areaNorm;
}

class YieldFusionResult {
  const YieldFusionResult({
    required this.litersPerDay,
    required this.yieldMin,
    required this.yieldMax,
    required this.confidence,
    required this.status,
    required this.displayLabel,
    required this.source,
    this.detail = '',
  });

  final double litersPerDay;
  final double yieldMin;
  final double yieldMax;
  final double confidence;
  final YieldPredictionStatus status;
  final String displayLabel;
  final String source;
  final String detail;
}

/// Blends Milk Mirror geometry, TFLite band, and farmer context (Phase B).
class YieldFusionService {
  static const double _farmerWeight = 0.10;

  YieldFusionResult fuse(YieldFusionInput input) {
    final tflite = input.tflite;
    final trustThreshold =
        input.tfliteTrained && input.tfliteValAccuracy >= 0.45 ? 0.38 : 0.45;
    final tfliteTrusted = tflite != null &&
        !tflite.lowConfidence &&
        tflite.confidence >= trustThreshold;
    final tfliteLiters = tflite?.expectedLiters ?? tflite?.litersPerDay;

    double liters;
    double confidence;
    String source;

    if (input.mirrorSuccess) {
      liters = input.mirrorLiters;
      confidence = input.mirrorConfidence;
      source = tfliteTrusted ? 'milk_mirror+tflite' : 'milk_mirror';

      if (tfliteTrusted && tfliteLiters != null) {
        final delta = (liters - tfliteLiters).abs();
        if (delta <= 2.5) {
          liters = liters * 0.58 + tfliteLiters * 0.42;
          confidence = math.min(0.96, confidence + tflite.confidence * 0.14);
        }
      }
    } else if (tfliteTrusted && tfliteLiters != null) {
      liters = tfliteLiters;
      confidence = tflite.confidence;
      source = 'tflite';
    } else {
      liters = tfliteLiters ?? input.mirrorLiters;
      confidence = math.max(tflite?.confidence ?? 0.15, 0.2);
      source = 'tflite_untrained';
    }

    final farmerAdj = _farmerPeakLiters(
      age: input.age,
      lactation: input.lactation,
      daysInMilk: input.daysInMilk,
      feed: input.feed,
      areaNorm: input.areaNorm,
    );
    liters = liters * (1 - _farmerWeight) + farmerAdj * _farmerWeight;
    liters = MilkProductionScale.clamp(liters);

    if (input.symmetryIndex > 0.42) {
      confidence *= 0.92;
    }
    if (!input.tfliteTrained || (tflite?.lowConfidence ?? true)) {
      confidence = math.min(confidence, 0.72);
    }
    if (!input.mirrorSuccess) {
      confidence = math.min(confidence, 0.55);
    }

    confidence = confidence.clamp(0.0, 1.0);

    final spread = _yieldSpread(confidence, tfliteTrusted, input.mirrorSuccess);
    final yieldMin = MilkProductionScale.clamp(liters - spread);
    final yieldMax = MilkProductionScale.clamp(liters + spread);

    YieldPredictionStatus status;
    if (confidence >= 0.68 && input.mirrorSuccess) {
      status = YieldPredictionStatus.highConfidence;
    } else {
      status = YieldPredictionStatus.caution;
    }

    InferenceLogger.log(
      'FUSION',
      'liters=${liters.toStringAsFixed(1)} range=$yieldMin–$yieldMax '
      'conf=${(confidence * 100).toStringAsFixed(0)}% source=$source '
      'farmerPeak=${farmerAdj.toStringAsFixed(1)} DIM=${input.daysInMilk}',
    );

    return YieldFusionResult(
      litersPerDay: liters,
      yieldMin: yieldMin,
      yieldMax: yieldMax,
      confidence: confidence,
      status: status,
      displayLabel: MilkProductionScale.formatExact(liters),
      source: source,
      detail: 'Band ${tflite?.label ?? "—"} · ${status.name}',
    );
  }

  double _farmerPeakLiters({
    required int age,
    required int lactation,
    required int daysInMilk,
    required String feed,
    required double areaNorm,
  }) {
    var peak = 6.0 + lactation * 0.8 + (age.clamp(3, 12) - 3) * 0.15;
    final dim = daysInMilk.clamp(0, 400);
    if (dim < 60) {
      peak *= 0.75 + dim / 240;
    } else if (dim < 200) {
      peak *= 1.0;
    } else if (dim < 305) {
      peak *= 1.0 - (dim - 200) / 400;
    } else {
      peak *= 0.72;
    }
    if (feed.toLowerCase().contains('green') ||
        feed.toLowerCase().contains('high')) {
      peak *= 1.08;
    }
    peak += areaNorm * 4.0;
    return MilkProductionScale.clamp(peak);
  }

  double _yieldSpread(
    double confidence,
    bool tfliteTrusted,
    bool mirrorSuccess,
  ) {
    if (confidence >= 0.75 && tfliteTrusted && mirrorSuccess) return 0.5;
    if (confidence >= 0.55) return 0.8;
    return 1.2;
  }
}
