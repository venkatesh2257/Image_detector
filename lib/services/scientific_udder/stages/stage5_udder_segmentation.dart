import 'dart:ui';

import 'package:image/image.dart' as img;

import '../../../models/scientific_udder_models.dart';
import '../../inference_logger.dart';
import '../../rear_anatomy_detector.dart';
import '../scientific_image_context.dart';

/// Stage 5 — heuristic udder + teat masks (TFLite seg slot for future asset).
class Stage5UdderSegmentation {
  const Stage5UdderSegmentation();

  static const String tfliteAsset = 'assets/model/udder_seg.tflite';

  UdderSegmentationResult run(
    ScientificImageContext ctx,
    RearAnatomyLandmarks anatomy,
    AnatomyRoi roi,
  ) {
    final sw = Stopwatch()..start();
    final w = ctx.working.width;
    final h = ctx.working.height;

    final udderMask = List.generate(w * h, (_) => 0);
    final teatMask = List.generate(w * h, (_) => 0);

    final y0 = (anatomy.leftPin.dy * h * 0.85).round().clamp(0, h - 1);
    final y1 = h - 1;
    final x0 = (roi.udder.left * w).round().clamp(0, w - 1);
    final x1 = (roi.udder.right * w).round().clamp(0, w - 1);

    var udderPixels = 0;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final p = ctx.working.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final br = (r + g + b) / 3;
        final isPink = r > 95 && g > 70 && b > 80 && r < 200;
        final isUdderTone = br > 35 && br < 165;
        if (isPink || isUdderTone) {
          udderMask[y * w + x] = 1;
          udderPixels++;
        }
      }
    }

    final teatRow = (anatomy.udder.dy * h).round().clamp(y0, y1);
    for (var x = x0; x <= x1; x++) {
      for (var dy = -3; dy <= 8; dy++) {
        final y = (teatRow + dy).clamp(0, h - 1);
        final idx = y * w + x;
        if (udderMask[idx] == 1 && _isTeatPixel(ctx.working.getPixel(x, y))) {
          teatMask[idx] = 1;
        }
      }
    }

    final minArea = w * h * 0.04;
    final passed = udderPixels >= minArea;
    final score = (udderPixels / (w * h * 0.25)).clamp(0.0, 1.0);

    InferenceLogger.log(
      'SCI-S5',
      'seg udderPx=$udderPixels passed=$passed',
    );

    return UdderSegmentationResult(
      stage: ScientificStageMetric(
        stageId: 'segmentation',
        passed: passed,
        score: score,
        durationMs: sw.elapsedMilliseconds,
        issues: passed ? const [] : const ['udder_mask_too_small'],
      ),
      udderMask: udderMask,
      teatMask: teatMask,
      width: w,
      height: h,
      udderPixelCount: udderPixels,
    );
  }

  bool _isTeatPixel(img.Pixel p) {
    final br = (p.r + p.g + p.b) / 3;
    return br > 45 && br < 140;
  }
}

class UdderSegmentationResult {
  const UdderSegmentationResult({
    required this.stage,
    required this.udderMask,
    required this.teatMask,
    required this.width,
    required this.height,
    required this.udderPixelCount,
  });

  final ScientificStageMetric stage;
  final List<int> udderMask;
  final List<int> teatMask;
  final int width;
  final int height;
  final int udderPixelCount;
}
