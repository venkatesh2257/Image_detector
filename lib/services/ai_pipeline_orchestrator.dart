import '../models/ai_pipeline_report.dart';
import 'animal_validation_service.dart';
import 'angle_validation_service.dart';
import 'image_quality_validator.dart';
import 'inference_logger.dart';
import 'rear_udder_detection_service.dart';

/// Multi-stage on-device pipeline: quality → animal → angle → rear udder → milk.
class AiPipelineOrchestrator {
  AiPipelineOrchestrator({
    ImageQualityValidator? quality,
    AnimalValidationService? animal,
    AngleValidationService? angle,
    RearUdderDetectionService? udder,
  })  : _quality = quality ?? const ImageQualityValidator(),
        _animal = animal ?? AnimalValidationService(),
        _angle = angle ?? const AngleValidationService(),
        _udder = udder ?? RearUdderDetectionService();

  final ImageQualityValidator _quality;
  final AnimalValidationService _animal;
  final AngleValidationService _angle;
  final RearUdderDetectionService _udder;

  /// Stages 1–4 for upload / training eligibility (no TFLite).
  Future<AiPipelineReport> validateForTraining({
    required String imagePath,
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) async {
    return _run(
      imagePath: imagePath,
      includeAnimal: true,
      breed: breed,
      age: age,
      lactation: lactation,
      daysInMilk: daysInMilk,
      feed: feed,
    );
  }

  /// Quality + angle + udder only (animal rules gate runs in ClassifierService).
  Future<AiPipelineReport> validatePreMilk({required String imagePath}) async {
    return _run(imagePath: imagePath, includeAnimal: false);
  }

  /// Full pre-inference validation before milk prediction.
  Future<AiPipelineReport> validateForInference({
    required String imagePath,
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) async {
    return _run(
      imagePath: imagePath,
      includeAnimal: true,
      breed: breed,
      age: age,
      lactation: lactation,
      daysInMilk: daysInMilk,
      feed: feed,
    );
  }

  Future<AiPipelineReport> _run({
    required String imagePath,
    required bool includeAnimal,
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) async {
    InferenceLogger.banner('AI PIPELINE — multi-stage validation');
    final stages = <StageValidationResult>[];

    final qSw = Stopwatch()..start();
    final quality = await _quality.validateFile(imagePath);
    final qualityStage = StageValidationResult(
      stage: PipelineStage.quality,
      passed: quality.passed,
      score: quality.score,
      issues: quality.issues,
      detail: 'blur=${quality.blurVariance.toStringAsFixed(1)}',
      durationMs: qSw.elapsedMilliseconds,
    );
    stages.add(qualityStage);
    if (!quality.passed) {
      return _fail(stages, PipelineStage.quality, quality.issues.join(', '));
    }

    if (includeAnimal) {
      final animal = _animal.validate(
        imagePath,
        breed: breed,
        age: age,
        lactation: lactation,
        daysInMilk: daysInMilk,
        feed: feed,
      );
      stages.add(animal);
      if (!animal.passed) {
        return _fail(stages, PipelineStage.animal, animal.detail);
      }
    }

    final angle = _angle.validate(imagePath);
    stages.add(angle);
    if (!angle.passed) {
      return _fail(stages, PipelineStage.angle, angle.issues.join(', '));
    }

    final udderResult = _udder.detect(imagePath);
    stages.add(udderResult.stageResult);
    if (!udderResult.stageResult.passed) {
      return _fail(
        stages,
        PipelineStage.rearUdder,
        udderResult.stageResult.issues.join(', '),
        cropPath: udderResult.crop?.cropPath,
      );
    }

    final overall = _aggregateScore(stages);
    InferenceLogger.banner('AI PIPELINE — ALL STAGES PASSED');
    return AiPipelineReport(
      stages: stages,
      overallPassed: true,
      overallScore: overall,
      inferenceImagePath: udderResult.inferencePath ?? imagePath,
      cropPath: udderResult.crop?.cropPath,
    );
  }

  AiPipelineReport _fail(
    List<StageValidationResult> stages,
    PipelineStage failed,
    String reason, {
    String? cropPath,
  }) {
    InferenceLogger.log('PIPELINE', 'FAILED at $failed: $reason');
    return AiPipelineReport(
      stages: stages,
      overallPassed: false,
      overallScore: _aggregateScore(stages),
      failedStage: failed,
      rejectReason: reason,
      cropPath: cropPath,
    );
  }

  double _aggregateScore(List<StageValidationResult> stages) {
    if (stages.isEmpty) return 0;
    var sum = 0.0;
    for (final s in stages) {
      sum += s.score;
    }
    return (sum / stages.length).clamp(0.0, 1.0);
  }
}
