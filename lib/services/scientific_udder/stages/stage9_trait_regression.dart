import '../../../config/scientific_udder_config.dart';
import '../../../models/scientific_udder_models.dart';
import '../../inference_logger.dart';
import '../../milk_production_scale.dart';

/// Stage 9 — MLR-style trait regression → liters/day (on-device, no cloud).
class Stage9TraitRegression {
  const Stage9TraitRegression();

  ({double liters, double confidence}) predict({
    required ScientificUdderTraits traits,
    required double globalConfidence,
    int lactation = 1,
    int daysInMilk = 30,
    String breed = 'Local/Desi',
  }) {
    final ln = lactation.clamp(1, 12);
    final dim = daysInMilk.clamp(1, 400);

    var y = ScientificUdderConfig.regressionIntercept;
    y += ScientificUdderConfig.coeffRuhNorm * traits.ruhNorm;
    y += ScientificUdderConfig.coeffRuwNorm * traits.ruwNorm;
    y += ScientificUdderConfig.coeffRtdNorm * traits.rtdNorm;
    y += ScientificUdderConfig.coeffSymmetry * traits.symmetryIndex;
    y += ScientificUdderConfig.coeffDepthProxy *
        (traits.udderDepthProxyCm / 20.0);
    y += ScientificUdderConfig.coeffLactation * ln;
    y += ScientificUdderConfig.coeffDim * dim;

  if (breed.toLowerCase().contains('murrah')) {
      y += 0.4;
    }

    final liters = MilkProductionScale.clamp(y);
    final traitConf = traits.perTraitConfidence.values.isEmpty
        ? globalConfidence
        : traits.perTraitConfidence.values.reduce((a, b) => a + b) /
            traits.perTraitConfidence.length;

    final confidence =
        (globalConfidence * 0.55 + traitConf * 0.45).clamp(0.0, 1.0);

    InferenceLogger.log(
      'SCI-S9',
      'regression liters=${liters.toStringAsFixed(1)} conf=${confidence.toStringAsFixed(2)}',
    );

    return (liters: liters, confidence: confidence);
  }
}
