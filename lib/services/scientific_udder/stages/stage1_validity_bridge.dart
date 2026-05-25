import '../../../models/scientific_udder_models.dart';
import '../../angle_validation_service.dart';
import '../../animal_validation_service.dart';
import '../../inference_logger.dart';
import '../scientific_image_context.dart';

/// Stage 1 — animal + rear-view (reuses existing validators).
class Stage1ValidityBridge {
  Stage1ValidityBridge({
    AnimalValidationService? animal,
    AngleValidationService? angle,
  })  : _animal = animal ?? AnimalValidationService(),
        _angle = angle ?? const AngleValidationService();

  final AnimalValidationService _animal;
  final AngleValidationService _angle;

  ScientificStageMetric run(
    ScientificImageContext ctx, {
    required String imagePath,
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) {
    final sw = Stopwatch()..start();
    final animal = _animal.validate(
      imagePath,
      breed: breed,
      age: age,
      lactation: lactation,
      daysInMilk: daysInMilk,
      feed: feed,
    );
    final angle = _angle.validate(imagePath);

    final issues = <String>[
      ...animal.issues,
      ...angle.issues,
    ];
    final passed = animal.passed && angle.passed;
    final score = ((animal.score + angle.score) / 2).clamp(0.0, 1.0);

    InferenceLogger.log(
      'SCI-S1',
      'validity passed=$passed animal=${animal.passed} angle=${angle.passed}',
    );

    return ScientificStageMetric(
      stageId: 'animal_rear_validity',
      passed: passed,
      score: score,
      durationMs: sw.elapsedMilliseconds,
      issues: issues,
      detail: animal.detail,
    );
  }
}
