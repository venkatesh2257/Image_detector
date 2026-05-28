import 'classifier_service_new.dart';
import '../models/ai_pipeline_report.dart';
import 'inference_logger.dart';

/// Stage 2: reject humans, devices, dogs/cats, non-livestock scenes.
class AnimalValidationService {
  AnimalValidationService();

  final _detector = VeterinaryBuffaloDetector();

  StageValidationResult validate(
    String imagePath, {
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) {
    final sw = Stopwatch()..start();
    InferenceLogger.log('PIPELINE', 'Animal validation START');

    final gate = _detector.identifyBuffalo(
      imagePath,
      breed: breed,
      age: age,
      lactation: lactation,
      daysInMilk: daysInMilk,
      feed: feed,
    );

    final passed = gate.status == 'valid';
    final issues = <String>[];
    if (!passed) {
      issues.add(_issueCode(gate.reason));
    }

    InferenceLogger.log(
      'PIPELINE',
      'Animal validation ${passed ? "PASS" : "FAIL"}: ${gate.reason ?? "ok"}',
    );

    return StageValidationResult(
      stage: PipelineStage.animal,
      passed: passed,
      score: passed ? gate.confidence.clamp(0.0, 1.0) : 0.0,
      issues: issues,
      detail: gate.reason ?? 'buffalo_validated',
      durationMs: sw.elapsedMilliseconds,
    );
  }

  /// Expose gate output for milk prediction (keypoints, features).
  BuffaloAnalysisResult analyzeFull(
    String imagePath, {
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) =>
      _detector.identifyBuffalo(
        imagePath,
        breed: breed,
        age: age,
        lactation: lactation,
        daysInMilk: daysInMilk,
        feed: feed,
      );

  String _issueCode(String? reason) {
    final r = (reason ?? '').toLowerCase();
    if (r.contains('human') || r.contains('selfie') || r.contains('face')) {
      return 'human_detected';
    }
    if (r.contains('laptop') || r.contains('screen') || r.contains('phone')) {
      return 'electronic_device';
    }
    if (r.contains('dog') || r.contains('cat')) return 'non_livestock_pet';
    if (r.contains('object')) return 'random_object';
    return 'not_buffalo';
  }
}
