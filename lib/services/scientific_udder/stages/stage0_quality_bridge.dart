import 'package:image/image.dart' as img;

import '../../../models/scientific_udder_models.dart';
import '../../image_quality_validator.dart';
import '../../inference_logger.dart';
import '../scientific_image_context.dart';

/// Stage 0 — extends existing quality validator (blur, exposure, noise, framing).
class Stage0QualityBridge {
  const Stage0QualityBridge();

  static const _minFramingScore = 0.45;

  Future<ScientificStageMetric> run(ScientificImageContext ctx) async {
    final sw = Stopwatch()..start();
    const validator = ImageQualityValidator();
    final bytes = img.encodeJpg(ctx.working);
    final result = validator.validateBytes(bytes);

    final aspect = ctx.width / ctx.height;
    final issues = List<String>.from(result.issues);
    if (aspect < 0.72 || aspect > 1.85) {
      issues.add('framing_aspect_out_of_range');
    }

    final framingScore = (aspect >= 0.85 && aspect <= 1.45) ? 1.0 : 0.7;
    final passed = result.passed && framingScore >= _minFramingScore;
    final score = (result.score * 0.85 + framingScore * 0.15).clamp(0.0, 1.0);

    InferenceLogger.log(
      'SCI-S0',
      'quality passed=$passed score=${score.toStringAsFixed(2)} issues=$issues',
    );

    return ScientificStageMetric(
      stageId: 'quality',
      passed: passed,
      score: passed ? score : score * 0.5,
      durationMs: sw.elapsedMilliseconds,
      issues: issues,
      detail: 'blur=${result.blurVariance.toStringAsFixed(1)}',
    );
  }
}
