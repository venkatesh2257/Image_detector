import 'dart:io';
import 'package:image/image.dart' as img;

import '../models/ai_pipeline_report.dart';
import 'inference_logger.dart';
import 'rear_anatomy_detector.dart';

/// Stage 3: ensure rear-view capture (reject side/front/tilted).
class AngleValidationService {
  const AngleValidationService();

  static const minRearSymmetry = 0.42;
  static const minLowerMassRatio = 0.38;
  static const maxTopHeavyRatio = 0.62;
  static const minPinSpreadNorm = 0.12;

  StageValidationResult validate(String imagePath) {
    final sw = Stopwatch()..start();
    final file = File(imagePath);
    if (!file.existsSync()) {
      return StageValidationResult(
        stage: PipelineStage.angle,
        passed: false,
        score: 0,
        issues: const ['file_missing'],
        durationMs: sw.elapsedMilliseconds,
      );
    }

    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      return StageValidationResult(
        stage: PipelineStage.angle,
        passed: false,
        score: 0,
        issues: const ['corrupt_image'],
        durationMs: sw.elapsedMilliseconds,
      );
    }

    final image = img.bakeOrientation(decoded);
    final issues = <String>[];

    final aspect = image.width / image.height;
    if (aspect < 0.65) issues.add('portrait_not_rear');
    if (aspect > 2.2) issues.add('panorama_not_rear');

    final gray = img.grayscale(
      img.copyResize(image, width: 320, height: (320 * image.height / image.width).round()),
    );

    final symmetry = _leftRightSymmetry(gray);
    if (symmetry < minRearSymmetry) issues.add('side_view_asymmetric');

    final lowerRatio = _lowerHalfMassRatio(gray);
    if (lowerRatio < minLowerMassRatio) issues.add('front_or_top_view');

    final topHeavy = _topHeavyRatio(gray);
    if (topHeavy > maxTopHeavyRatio) issues.add('tilted_or_front_heavy');

    final anatomy = RearAnatomyDetector().detect(image);
    if (anatomy != null && !anatomy.isTemplateFallback) {
      final spread = (anatomy.rightPin.dx - anatomy.leftPin.dx).abs();
      if (spread < minPinSpreadNorm) issues.add('partial_crop_pins_too_close');
      final pinMidY = (anatomy.leftPin.dy + anatomy.rightPin.dy) / 2;
      if (pinMidY < 0.18) issues.add('pins_too_high_not_rear');
      if (anatomy.udder.dy < pinMidY) issues.add('udder_above_pins_invalid');
    } else {
      issues.add('rear_anatomy_incomplete');
    }

    final score = _score(symmetry, lowerRatio, topHeavy, issues.length);
    final passed = issues.isEmpty;

    InferenceLogger.log(
      'PIPELINE',
      'Angle validation ${passed ? "PASS" : "FAIL"} sym=${symmetry.toStringAsFixed(2)} '
      'issues=$issues',
    );

    return StageValidationResult(
      stage: PipelineStage.angle,
      passed: passed,
      score: score,
      issues: issues,
      detail: passed ? 'rear_angle_ok' : issues.join(','),
      durationMs: sw.elapsedMilliseconds,
    );
  }

  double _leftRightSymmetry(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final mid = w ~/ 2;
    var diff = 0.0;
    var n = 0;
    for (var y = (h * 0.35).round(); y < h; y += 3) {
      for (var dx = 1; dx < mid; dx += 3) {
        final l = gray.getPixel(mid - dx, y).r.toDouble();
        final r = gray.getPixel(mid + dx, y).r.toDouble();
        diff += (l - r).abs();
        n++;
      }
    }
    if (n == 0) return 0;
    return 1.0 - (diff / n / 128.0).clamp(0.0, 1.0);
  }

  double _lowerHalfMassRatio(img.Image gray) {
    final h = gray.height;
    final y0 = h ~/ 2;
    var lower = 0;
    var upper = 0;
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < gray.width; x += 2) {
        final br = gray.getPixel(x, y).r;
        if (br > 35 && br < 200) {
          if (y >= y0) {
            lower++;
          } else {
            upper++;
          }
        }
      }
    }
    final total = lower + upper;
    return total == 0 ? 0 : lower / total;
  }

  double _topHeavyRatio(img.Image gray) {
    final h = gray.height;
    final topEnd = (h * 0.35).round();
    var top = 0;
    var bottom = 0;
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < gray.width; x += 2) {
        final br = gray.getPixel(x, y).r;
        if (br > 40 && br < 200) {
          if (y < topEnd) {
            top++;
          } else {
            bottom++;
          }
        }
      }
    }
    final total = top + bottom;
    return total == 0 ? 1 : top / total;
  }

  double _score(double sym, double lower, double topHeavy, int issueCount) {
    var s = sym * 0.35 + lower * 0.35 + (1 - topHeavy) * 0.2;
    s = s.clamp(0.0, 1.0);
    s -= issueCount * 0.15;
    return s.clamp(0.0, 1.0);
  }
}
