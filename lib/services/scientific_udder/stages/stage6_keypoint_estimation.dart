import 'dart:ui';

import '../../../models/scientific_udder_models.dart';
import '../../inference_logger.dart';
import '../../rear_anatomy_detector.dart';
import '../scientific_image_context.dart';
import 'stage5_udder_segmentation.dart';

/// Stage 6 — keypoints from anatomy + mask refinement (heatmap TFLite slot later).
class Stage6KeypointEstimation {
  const Stage6KeypointEstimation();

  UdderKeypointSet estimate(
    ScientificImageContext ctx,
    RearAnatomyLandmarks anatomy, {
    UdderSegmentationResult? segmentation,
  }) {
    final pinMidY = (anatomy.leftPin.dy + anatomy.rightPin.dy) / 2;
    final vulva = Offset(
      (anatomy.leftPin.dx + anatomy.rightPin.dx) / 2,
      (pinMidY + anatomy.udder.dy) / 2 + 0.04,
    );
    final udderTop = Offset(
      (anatomy.pointA.dx + anatomy.pointB.dx) / 2,
      anatomy.pointA.dy.clamp(0.0, anatomy.udder.dy),
    );
    final udderBottom = Offset(
      anatomy.udder.dx,
      anatomy.udder.dy.clamp(anatomy.leftPin.dy, 1.0),
    );

    var teatL = Offset(
      (anatomy.leftPin.dx + anatomy.udder.dx) / 2,
      anatomy.udder.dy,
    );
    var teatR = Offset(
      (anatomy.rightPin.dx + anatomy.udder.dx) / 2,
      anatomy.udder.dy,
    );

    if (segmentation != null) {
      final refined = _refineTeatsFromMask(segmentation);
      if (refined != null) {
        teatL = refined.$1;
        teatR = refined.$2;
      }
    }

    final conf = anatomy.isTemplateFallback
        ? anatomy.confidence * 0.5
        : anatomy.confidence;

    InferenceLogger.log('SCI-S6', 'keypoints conf=${conf.toStringAsFixed(2)}');

    return UdderKeypointSet(
      leftPin: anatomy.leftPin,
      rightPin: anatomy.rightPin,
      vulva: vulva,
      udderTop: udderTop,
      udderBottom: udderBottom,
      teatLeft: teatL,
      teatRight: teatR,
      confidence: conf.clamp(0.0, 1.0),
      fromHeuristicFallback: anatomy.isTemplateFallback,
    );
  }

  (Offset, Offset)? _refineTeatsFromMask(UdderSegmentationResult seg) {
    final w = seg.width;
    final h = seg.height;
  final ys = <int>[];
    for (var y = (h * 0.55).round(); y < h; y++) {
      var row = 0;
      for (var x = 0; x < w; x++) {
        if (seg.teatMask[y * w + x] == 1) row++;
      }
      if (row > w * 0.05) ys.add(y);
    }
    if (ys.isEmpty) return null;
    final y = ys.reduce((a, b) => a + b) ~/ ys.length;
    var leftX = w;
    var rightX = 0;
    for (var x = 0; x < w; x++) {
      if (seg.teatMask[y * w + x] == 1) {
        if (x < leftX) leftX = x;
        if (x > rightX) rightX = x;
      }
    }
    if (rightX <= leftX) return null;
    return (
      Offset(leftX / w, y / h),
      Offset(rightX / w, y / h),
    );
  }

  ScientificStageMetric toStageMetric(UdderKeypointSet kp) {
    final issues = <String>[];
    if (kp.fromHeuristicFallback) issues.add('heuristic_fallback');
    if (kp.udderBottom.dy <= kp.udderTop.dy) issues.add('invalid_udder_axis');
    if (kp.confidence < 0.3) issues.add('low_keypoint_confidence');

    final passed = kp.udderBottom.dy > kp.udderTop.dy && kp.confidence >= 0.28;
    return ScientificStageMetric(
      stageId: 'keypoints',
      passed: passed,
      score: kp.confidence,
      durationMs: 0,
      issues: issues,
    );
  }
}
