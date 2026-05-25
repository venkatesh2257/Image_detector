import 'dart:math' as math;
import 'dart:ui';

import '../../../config/scientific_udder_config.dart';
import '../../../models/scientific_udder_models.dart';
import '../../inference_logger.dart';
import '../scientific_image_context.dart';
import 'stage5_udder_segmentation.dart';

/// Stage 7 — RUH, RUW, RTD, FRTD proxy, symmetry, depth proxy (cm calibrated).
class Stage7TraitDerivation {
  const Stage7TraitDerivation();

  ScientificUdderTraits derive(
    ScientificImageContext ctx,
    UdderKeypointSet kp, {
    UdderSegmentationResult? segmentation,
  }) {
    final ruhNorm = (kp.udderTop.dy - kp.vulva.dy).abs().clamp(0.0, 1.0);
    final ruwNorm = (kp.rightPin.dx - kp.leftPin.dx).abs().clamp(0.0, 1.0);
    final rtdNorm = _normDist(kp.teatLeft, kp.teatRight);
    final frtdNorm = rtdNorm * 1.15;

    final scale = ScientificUdderConfig.referencePinSpreadCm /
        ScientificUdderConfig.referencePinSpreadNorm;

    final ruhCm = ruhNorm * scale * 1.1;
    final ruwCm = ruwNorm * scale;
    final rtdCm = rtdNorm * scale * 0.85;
    final frtdCm = frtdNorm * scale * 0.85;

    final depthNorm = (kp.udderBottom.dy - ((kp.leftPin.dy + kp.rightPin.dy) / 2))
        .clamp(0.0, 0.5);
    final udderDepthProxyCm = depthNorm * scale * 1.2;

    final symmetryIndex = _symmetryFromMask(segmentation, kp) ??
        _symmetryFromTeats(kp);

    final perTrait = <String, double>{
      'ruh': kp.confidence * (ruhNorm > 0.05 ? 1.0 : 0.3),
      'ruw': kp.confidence * (ruwNorm > 0.08 ? 1.0 : 0.3),
      'rtd': kp.confidence * (rtdNorm > 0.03 ? 1.0 : 0.4),
      'symmetry': kp.confidence,
      'depth': kp.confidence * (depthNorm > 0.04 ? 1.0 : 0.35),
    };

    InferenceLogger.log(
      'SCI-S7',
      'traits RUH=${ruhCm.toStringAsFixed(1)}cm RUW=${ruwCm.toStringAsFixed(1)}cm '
      'RTD=${rtdCm.toStringAsFixed(1)}cm sym=${symmetryIndex.toStringAsFixed(2)}',
    );

    return ScientificUdderTraits(
      ruhCm: ruhCm,
      ruwCm: ruwCm,
      rtdCm: rtdCm,
      frtdCm: frtdCm,
      udderDepthProxyCm: udderDepthProxyCm,
      symmetryIndex: symmetryIndex,
      ruhNorm: ruhNorm,
      ruwNorm: ruwNorm,
      rtdNorm: rtdNorm,
      perTraitConfidence: perTrait,
      scaleCmPerNorm: scale,
    );
  }

  double _normDist(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy).clamp(0.0, 1.0);
  }

  double _symmetryFromTeats(UdderKeypointSet kp) {
    final mid = (kp.leftPin.dx + kp.rightPin.dx) / 2;
    final dL = (kp.teatLeft.dx - mid).abs();
    final dR = (kp.teatRight.dx - mid).abs();
    final t = dL + dR;
    if (t < 1e-6) return 0.5;
    return (1 - (dL - dR).abs() / t).clamp(0.0, 1.0);
  }

  double? _symmetryFromMask(UdderSegmentationResult? seg, UdderKeypointSet kp) {
    if (seg == null) return null;
    final w = seg.width;
    final h = seg.height;
    final mid = ((kp.leftPin.dx + kp.rightPin.dx) / 2 * w).round();
    var left = 0;
    var right = 0;
    for (var y = (h * 0.5).round(); y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (seg.udderMask[y * w + x] == 0) continue;
        if (x < mid) {
          left++;
        } else {
          right++;
        }
      }
    }
    final t = left + right;
    if (t == 0) return null;
    return (1 - (left - right).abs() / t).clamp(0.0, 1.0);
  }
}
