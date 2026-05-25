import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../../../config/scientific_udder_config.dart';
import '../../../models/scientific_udder_models.dart';
import '../../inference_logger.dart';
import '../../rear_anatomy_detector.dart';
import '../scientific_image_context.dart';

/// Stage 3 — estimate yaw, pitch proxy, roll, off-center from rear anatomy + mass.
class Stage3PoseEstimation {
  const Stage3PoseEstimation();

  PoseEstimate estimate(
    ScientificImageContext ctx,
    RearAnatomyLandmarks anatomy,
    double midlineX,
  ) {
    final rollRad = math.atan2(
      anatomy.rightPin.dy - anatomy.leftPin.dy,
      anatomy.rightPin.dx - anatomy.leftPin.dx,
    );

    final gray = img.grayscale(
      img.copyResize(ctx.working, width: 240, height: (240 * ctx.height / ctx.width).round()),
    );
    final yawRad = _estimateYaw(gray, midlineX);
    final pitchProxy = _estimatePitchProxy(gray);
    final offCenterX = midlineX - 0.5;

    var conf = 0.85;
    if (yawRad.abs() > ScientificUdderConfig.maxYawRad) conf -= 0.25;
    if (rollRad.abs() > ScientificUdderConfig.maxRollRad) conf -= 0.2;
    if (pitchProxy > ScientificUdderConfig.maxPitchProxy) conf -= 0.15;
    if (offCenterX.abs() > 0.18) conf -= 0.1;

    InferenceLogger.log(
      'SCI-S3',
      'pose yaw=${yawRad.toStringAsFixed(3)} roll=${rollRad.toStringAsFixed(3)} '
      'pitch=$pitchProxy off=${offCenterX.toStringAsFixed(2)}',
    );

    return PoseEstimate(
      yawRad: yawRad,
      pitchProxy: pitchProxy,
      rollRad: rollRad,
      offCenterX: offCenterX,
      confidence: conf.clamp(0.2, 1.0),
    );
  }

  ScientificStageMetric toStageMetric(PoseEstimate pose) {
    final issues = <String>[];
    if (pose.yawRad.abs() > ScientificUdderConfig.maxYawRad) {
      issues.add('yaw_excessive');
    }
    if (pose.rollRad.abs() > ScientificUdderConfig.maxRollRad) {
      issues.add('roll_excessive');
    }
    if (pose.pitchProxy > ScientificUdderConfig.maxPitchProxy) {
      issues.add('pitch_excessive');
    }

    final passed = issues.isEmpty;
    return ScientificStageMetric(
      stageId: 'pose',
      passed: passed,
      score: passed ? pose.confidence : pose.confidence * 0.4,
      durationMs: 0,
      issues: issues,
    );
  }

  double _estimateYaw(img.Image gray, double midlineNorm) {
    final w = gray.width;
    final h = gray.height;
    final mid = (midlineNorm * w).round().clamp(1, w - 2);
    var leftMass = 0.0;
    var rightMass = 0.0;
    for (var y = (h * 0.4).round(); y < h; y += 2) {
      for (var x = 0; x < mid; x += 2) {
        final br = gray.getPixel(x, y).r;
        if (br > 40 && br < 200) leftMass++;
      }
      for (var x = mid; x < w; x += 2) {
        final br = gray.getPixel(x, y).r;
        if (br > 40 && br < 200) rightMass++;
      }
    }
    final total = leftMass + rightMass;
    if (total == 0) return 0;
    return ((leftMass - rightMass) / total).clamp(-0.6, 0.6) * 0.5;
  }

  double _estimatePitchProxy(img.Image gray) {
    final h = gray.height;
    var upper = 0;
    var lower = 0;
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < gray.width; x += 2) {
        final br = gray.getPixel(x, y).r;
        if (br < 40 || br > 200) continue;
        if (y < h * 0.4) {
          upper++;
        } else {
          lower++;
        }
      }
    }
    final t = upper + lower;
    if (t == 0) return 0.5;
    return (upper / t).clamp(0.0, 1.0);
  }
}
