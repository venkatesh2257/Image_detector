import '../models/ai_pipeline_report.dart';
import 'inference_logger.dart';
import 'rear_anatomy_detector.dart';
import 'udder_escutcheon_crop_service.dart';

/// Pluggable backend — swap in YOLO TFLite when `assets/model/udder_yolo.tflite` exists.
abstract class UdderDetectorBackend {
  RearAnatomyLandmarks? detectLandmarks(String imagePath);
  String get name;
}

/// Current production backend: heuristic anatomy + escutcheon crop.
class HeuristicUdderDetector implements UdderDetectorBackend {
  final _anatomy = RearAnatomyDetector();
  final _cropper = UdderEscutcheonCropService();

  @override
  String get name => 'heuristic_v1';

  @override
  RearAnatomyLandmarks? detectLandmarks(String imagePath) =>
      _anatomy.detectFromPath(imagePath);

  UdderEscutcheonCrop? buildCrop(String imagePath, {RearAnatomyLandmarks? anatomy}) =>
      _cropper.buildCrop(imagePath, anatomy: anatomy);
}

/// Future: load YOLO bbox model from assets and map to landmarks.
class YoloUdderDetector implements UdderDetectorBackend {
  YoloUdderDetector({this.modelAsset = 'assets/model/udder_yolo.tflite'});

  final String modelAsset;
  bool _available = false;

  Future<bool> tryInitialize() async {
    // Placeholder — wire Interpreter.fromAsset when model is added.
    _available = false;
    return _available;
  }

  @override
  String get name => 'yolo_placeholder';

  @override
  RearAnatomyLandmarks? detectLandmarks(String imagePath) {
    if (!_available) return null;
    return null;
  }
}

/// Stage 4: rear udder region detection, crop, visibility validation.
class RearUdderDetectionService {
  RearUdderDetectionService({UdderDetectorBackend? backend})
      : _backend = backend ?? HeuristicUdderDetector();

  final UdderDetectorBackend _backend;
  final _heuristic = HeuristicUdderDetector();

  static const minAnatomyConfidence = 0.35;
  static const minCropSize = 64;

  RearUdderDetectionResult detect(String imagePath) {
    final sw = Stopwatch()..start();
    final issues = <String>[];

    var anatomy = _backend.detectLandmarks(imagePath);
    if (anatomy == null && _backend.name != 'heuristic_v1') {
      anatomy = _heuristic.detectLandmarks(imagePath);
    }

    if (anatomy == null) {
      return RearUdderDetectionResult(
        stageResult: StageValidationResult(
          stage: PipelineStage.rearUdder,
          passed: false,
          score: 0,
          issues: const ['udder_not_detected'],
          durationMs: sw.elapsedMilliseconds,
        ),
      );
    }

    if (anatomy.isTemplateFallback) {
      issues.add('template_fallback_low_confidence');
    }
    if (anatomy.confidence < minAnatomyConfidence) {
      issues.add('low_anatomy_confidence');
    }

    final spread = (anatomy.rightPin.dx - anatomy.leftPin.dx).abs();
    if (spread < 0.08) issues.add('pin_bones_not_visible');

    final udderLowEnough = anatomy.udder.dy > 0.45;
    if (!udderLowEnough) issues.add('udder_region_incomplete');

    final crop = _heuristic.buildCrop(imagePath, anatomy: anatomy);
    if (crop == null || !crop.isValid) {
      issues.add('escutcheon_crop_failed');
    } else if (crop.cropWidth < minCropSize || crop.cropHeight < minCropSize) {
      issues.add('crop_too_small');
    }

    final score = _score(anatomy.confidence, spread, issues.length);
    final passed = issues.isEmpty;

    InferenceLogger.log(
      'PIPELINE',
      'Rear udder ${passed ? "PASS" : "FAIL"} backend=${_backend.name} '
      'crop=${crop?.cropPath ?? "none"}',
    );

    return RearUdderDetectionResult(
      stageResult: StageValidationResult(
        stage: PipelineStage.rearUdder,
        passed: passed,
        score: score,
        issues: issues,
        detail: 'backend=${_backend.name}',
        durationMs: sw.elapsedMilliseconds,
      ),
      anatomy: anatomy,
      crop: crop,
    );
  }

  double _score(double conf, double spread, int issueCount) {
    var s = conf * 0.6 + (spread / 0.35).clamp(0.0, 1.0) * 0.4;
    s -= issueCount * 0.12;
    return s.clamp(0.0, 1.0);
  }
}

class RearUdderDetectionResult {
  const RearUdderDetectionResult({
    required this.stageResult,
    this.anatomy,
    this.crop,
  });

  final StageValidationResult stageResult;
  final RearAnatomyLandmarks? anatomy;
  final UdderEscutcheonCrop? crop;

  String? get inferencePath =>
      crop != null && crop!.isValid ? crop!.cropPath : null;
}
