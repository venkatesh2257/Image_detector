import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../../../config/scientific_udder_config.dart';
import '../../../models/scientific_udder_models.dart';
import '../../inference_logger.dart';
import '../../rear_anatomy_detector.dart';
import '../scientific_image_context.dart';

/// Stage 4 — roll correction + rear-plane crop normalize (homography-lite).
class Stage4PerspectiveCorrection {
  const Stage4PerspectiveCorrection();

  ({ScientificStageMetric metric, String? rectifiedPath}) run(
    ScientificImageContext ctx,
    RearAnatomyLandmarks anatomy,
    PoseEstimate pose,
    AnatomyRoi roi,
  ) {
    final sw = Stopwatch()..start();
    var image = img.Image.from(ctx.working);

    final rollDeg = -pose.rollRad * 180 / math.pi;
    if (rollDeg.abs() > 0.5) {
      image = img.copyRotate(image, angle: rollDeg);
    }

    if (pose.yawRad.abs() > 0.08 && pose.yawRad.abs() <= ScientificUdderConfig.maxYawRad) {
      image = _mildYawShear(image, pose.yawRad);
    }

    final cropRect = _pixelRect(image, roi.udder, padding: 0.06);
    if (cropRect.width < 32 || cropRect.height < 32) {
      return (
        metric: ScientificStageMetric(
          stageId: 'perspective',
          passed: false,
          score: 0,
          durationMs: sw.elapsedMilliseconds,
          issues: const ['crop_too_small'],
        ),
        rectifiedPath: null,
      );
    }

    var cropped = img.copyCrop(
      image,
      x: cropRect.left.toInt(),
      y: cropRect.top.toInt(),
      width: cropRect.width.toInt(),
      height: cropRect.height.toInt(),
    );

    cropped = img.copyResize(
      cropped,
      width: ScientificUdderConfig.rectifyWidth,
      height: ScientificUdderConfig.rectifyHeight,
      interpolation: img.Interpolation.linear,
    );

    ctx.working = cropped;

    final score = pose.confidence * (pose.yawRad.abs() < 0.2 ? 1.0 : 0.75);
    final passed = pose.yawRad.abs() <= ScientificUdderConfig.maxYawRad;

    InferenceLogger.log(
      'SCI-S4',
      'rectified ${cropped.width}x${cropped.height} roll=${rollDeg.toStringAsFixed(1)}°',
    );

    return (
      metric: ScientificStageMetric(
        stageId: 'perspective',
        passed: passed,
        score: score.clamp(0.0, 1.0),
        durationMs: sw.elapsedMilliseconds,
        issues: passed ? const [] : const ['yaw_not_correctable'],
        detail: 'roll_deg=${rollDeg.toStringAsFixed(1)}',
      ),
      rectifiedPath: null,
    );
  }

  img.Image _mildYawShear(img.Image src, double yawRad) {
    final out = img.Image(width: src.width, height: src.height);
    final shear = yawRad.clamp(-0.25, 0.25);
    for (var y = 0; y < src.height; y++) {
      final shift = (shear * (y - src.height / 2)).round();
      for (var x = 0; x < src.width; x++) {
        final sx = (x - shift).clamp(0, src.width - 1);
        out.setPixel(x, y, src.getPixel(sx, y));
      }
    }
    return out;
  }

  Rect _pixelRect(img.Image image, Rect normRoi, {double padding = 0}) {
    final l = ((normRoi.left - padding) * image.width).round().clamp(0, image.width - 1);
    final t = ((normRoi.top - padding) * image.height).round().clamp(0, image.height - 1);
    final r = ((normRoi.right + padding) * image.width).round().clamp(l + 1, image.width);
    final b = ((normRoi.bottom + padding) * image.height).round().clamp(t + 1, image.height);
    return Rect.fromLTRB(
      l.toDouble(),
      t.toDouble(),
      r.toDouble(),
      b.toDouble(),
    );
  }
}
