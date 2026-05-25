import 'dart:ui';

import '../../../models/scientific_udder_models.dart';
import '../../inference_logger.dart';
import '../../rear_anatomy_detector.dart';
import '../scientific_image_context.dart';

/// Stage 2 — hindquarter + udder ROI + midline (reuses [RearAnatomyDetector]).
class Stage2AnatomyLocalization {
  Stage2AnatomyLocalization({RearAnatomyDetector? detector})
      : _detector = detector ?? RearAnatomyDetector();

  final RearAnatomyDetector _detector;

  ({ScientificStageMetric metric, AnatomyRoi? roi, RearAnatomyLandmarks? anatomy})
      run(ScientificImageContext ctx) {
    final sw = Stopwatch()..start();
    final anatomy = _detector.detect(ctx.working);
    if (anatomy == null) {
      return (
        metric: ScientificStageMetric(
          stageId: 'anatomy_localization',
          passed: false,
          score: 0,
          durationMs: sw.elapsedMilliseconds,
          issues: const ['anatomy_not_found'],
        ),
        roi: null,
        anatomy: null,
      );
    }

    final pinL = anatomy.leftPin;
    final pinR = anatomy.rightPin;
    final udder = anatomy.udder;
    final midlineX = (pinL.dx + pinR.dx) / 2;

    final padX = 0.12;
    final padY = 0.08;
    final left = (pinL.dx - padX).clamp(0.0, 1.0);
    final right = (pinR.dx + padX).clamp(0.0, 1.0);
    final top = (anatomy.pointA.dy - padY).clamp(0.0, 1.0);
    final bottom = (udder.dy + 0.18).clamp(0.0, 1.0);

    final hindquarter = Rect.fromLTRB(left, top, right, bottom);
    final udderRoi = Rect.fromLTRB(
      (pinL.dx - 0.06).clamp(0.0, 1.0),
      (pinL.dy - 0.02).clamp(0.0, 1.0),
      (pinR.dx + 0.06).clamp(0.0, 1.0),
      bottom,
    );

    final spread = (pinR.dx - pinL.dx).abs();
    final issues = <String>[];
    if (anatomy.isTemplateFallback) issues.add('template_fallback');
    if (spread < 0.08) issues.add('pin_spread_too_small');

    final score = (anatomy.confidence * 0.7 + (spread / 0.35).clamp(0.0, 1.0) * 0.3)
        .clamp(0.0, 1.0);
    final passed = spread >= 0.08 && !anatomy.isTemplateFallback;

    InferenceLogger.log(
      'SCI-S2',
      'ROI midline=${midlineX.toStringAsFixed(2)} spread=${spread.toStringAsFixed(2)}',
    );

    return (
      metric: ScientificStageMetric(
        stageId: 'anatomy_localization',
        passed: passed,
        score: score,
        durationMs: sw.elapsedMilliseconds,
        issues: issues,
      ),
      roi: AnatomyRoi(
        hindquarter: hindquarter,
        udder: udderRoi,
        midlineX: midlineX,
      ),
      anatomy: anatomy,
    );
  }
}
