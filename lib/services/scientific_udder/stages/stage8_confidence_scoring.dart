import '../../../config/scientific_udder_config.dart';
import '../../../models/scientific_udder_models.dart';

/// Stage 8 — aggregate per-stage, per-trait, and global scientific confidence.
class Stage8ConfidenceScoring {
  const Stage8ConfidenceScoring();

  ({
    double globalConfidence,
    bool scientificallyValid,
    String? rejectReason,
  }) score({
    required List<ScientificStageMetric> stages,
    ScientificUdderTraits? traits,
    PoseEstimate? pose,
  }) {
    if (stages.isEmpty) {
      return (
        globalConfidence: 0.0,
        scientificallyValid: false,
        rejectReason: 'no_stages',
      );
    }

    final critical = {'quality', 'animal_rear_validity', 'keypoints', 'traits'};
    for (final id in critical) {
      final s = stages.where((e) => e.stageId == id).firstOrNull;
      if (s != null && !s.passed) {
        return (
          globalConfidence: 0.0,
          scientificallyValid: false,
          rejectReason: 'failed_$id',
        );
      }
    }

    var weighted = 0.0;
    var weightSum = 0.0;
    const weights = {
      'quality': 1.0,
      'animal_rear_validity': 1.2,
      'anatomy_localization': 1.0,
      'pose': 0.9,
      'perspective': 1.0,
      'segmentation': 0.85,
      'keypoints': 1.2,
      'traits': 1.3,
    };

    for (final s in stages) {
      final w = weights[s.stageId] ?? 0.8;
      weighted += s.score * w;
      weightSum += w;
    }

    var global = weightSum > 0 ? weighted / weightSum : 0.0;

    if (traits != null) {
      final traitMean = traits.perTraitConfidence.values.isEmpty
          ? 0.0
          : traits.perTraitConfidence.values.reduce((a, b) => a + b) /
              traits.perTraitConfidence.length;
      global = global * 0.65 + traitMean * 0.35;
    }

    if (pose != null) {
      global = global * 0.9 + pose.confidence * 0.1;
    }

    global = global.clamp(0.0, 1.0);
    final valid = global >= ScientificUdderConfig.minGlobalConfidence;

    return (
      globalConfidence: global,
      scientificallyValid: valid,
      rejectReason: valid ? null : 'global_confidence_below_threshold',
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
