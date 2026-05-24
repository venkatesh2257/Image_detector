import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Lightweight on-device checks before images enter the training queue.
class ImageQualityValidator {
  const ImageQualityValidator();

  static const minBlurVariance = 45.0;
  static const minMeanBrightness = 38.0;
  static const maxMeanBrightness = 245.0;
  static const minRearAspect = 0.72;
  static const maxRearAspect = 1.85;
  static const minTorsoOrganicRatio = 0.08;
  static const maxNoiseScore = 0.72;

  Future<ImageQualityResult> validateFile(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return validateBytes(bytes);
  }

  ImageQualityResult validateBytes(List<int> bytes) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      return ImageQualityResult.failed(['corrupt_or_unreadable']);
    }

    final w = decoded.width;
    final h = decoded.height;
    if (w < 120 || h < 120) {
      return ImageQualityResult.failed(['resolution_too_low']);
    }

    final issues = <String>[];
    final aspect = w / h;
    if (aspect < minRearAspect || aspect > maxRearAspect) {
      issues.add('wrong_aspect_ratio');
    }

    final gray = img.grayscale(
      img.copyResize(decoded, width: 320, height: (320 * h / w).round()),
    );
    final blurVar = _laplacianVariance(gray);
    if (blurVar < minBlurVariance) {
      issues.add('too_blurry');
    }

    final brightness = _meanBrightness(gray);
    if (brightness < minMeanBrightness) {
      issues.add('too_dark');
    } else if (brightness > maxMeanBrightness) {
      issues.add('overexposed');
    }

    final organic = _torsoOrganicRatio(gray);
    if (organic < minTorsoOrganicRatio) {
      issues.add('low_livestock_signature');
    }

    final udderBand = _lowerBandMass(gray);
    if (udderBand < 0.04) {
      issues.add('rear_udder_not_visible');
    }

    final noise = _noiseScore(gray);
    if (noise > maxNoiseScore) {
      issues.add('noisy_image');
    }

    final score = _score(
      blurVar: blurVar,
      brightness: brightness,
      organic: organic,
      udderBand: udderBand,
      aspect: aspect,
      issueCount: issues.length,
      noise: noise,
    );

    if (issues.isNotEmpty) {
      return ImageQualityResult(
        passed: false,
        score: score,
        issues: issues,
        blurVariance: blurVar,
        meanBrightness: brightness,
        torsoOrganicRatio: organic,
      );
    }

    return ImageQualityResult(
      passed: true,
      score: score,
      issues: const [],
      blurVariance: blurVar,
      meanBrightness: brightness,
      torsoOrganicRatio: organic,
    );
  }

  double _laplacianVariance(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    if (w < 3 || h < 3) return 0;

    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final c = gray.getPixel(x, y).r.toDouble();
        final lap = -4 * c +
            gray.getPixel(x - 1, y).r +
            gray.getPixel(x + 1, y).r +
            gray.getPixel(x, y - 1).r +
            gray.getPixel(x, y + 1).r;
        sum += lap;
        sumSq += lap * lap;
        n++;
      }
    }
    if (n == 0) return 0;
    final mean = sum / n;
    return (sumSq / n) - (mean * mean);
  }

  double _meanBrightness(img.Image gray) {
    var total = 0.0;
    final n = gray.width * gray.height;
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        total += gray.getPixel(x, y).r;
      }
    }
    return total / n;
  }

  /// Organic hide/grass in central torso band (mirrors rules-gate idea).
  double _torsoOrganicRatio(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final y0 = (h * 0.25).round();
    final y1 = (h * 0.72).round();
    final x0 = (w * 0.22).round();
    final x1 = (w * 0.78).round();

    var organic = 0;
    var total = 0;
    for (var y = y0; y < y1; y += 2) {
      for (var x = x0; x < x1; x += 2) {
        total++;
        final p = gray.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final br = (r + g + b) / 3;
        if (br > 35 && br < 175 && (r - g).abs() < 35) {
          organic++;
        }
      }
    }
    return total == 0 ? 0 : organic / total;
  }

  double _lowerBandMass(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final y0 = (h * 0.55).round();
    var mass = 0;
    var total = 0;
    for (var y = y0; y < h; y += 2) {
      for (var x = (w * 0.2).round(); x < (w * 0.8).round(); x += 2) {
        total++;
        final br = gray.getPixel(x, y).r;
        if (br > 40 && br < 200) mass++;
      }
    }
    return total == 0 ? 0 : mass / total;
  }

  /// High local variance vs low structure → sensor noise / compression artifacts.
  double _noiseScore(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    if (w < 4 || h < 4) return 0;

    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var y = 0; y < h - 1; y += 2) {
      for (var x = 0; x < w - 1; x += 2) {
        final a = gray.getPixel(x, y).r.toDouble();
        final b = gray.getPixel(x + 1, y).r.toDouble();
        final d = (a - b).abs();
        sum += d;
        sumSq += d * d;
        n++;
      }
    }
    if (n == 0) return 0;
    final mean = sum / n;
    final varD = (sumSq / n) - (mean * mean);
    return (varD / 400.0).clamp(0.0, 1.0);
  }

  double _score({
    required double blurVar,
    required double brightness,
    required double organic,
    required double udderBand,
    required double aspect,
    required int issueCount,
    double noise = 0,
  }) {
    var s = 1.0;
    s *= (blurVar / 120).clamp(0.0, 1.0);
    s *= 1 - ((brightness - 128).abs() / 128).clamp(0.0, 0.5);
    s *= (organic / divisor(0.25)).clamp(0.0, 1.0);
    s *= (udderBand / divisor(0.15)).clamp(0.0, 1.0);
    s *= 1 - noise.clamp(0.0, 0.5);
    if (aspect >= 0.9 && aspect <= 1.4) s *= 1.05;
    s -= issueCount * 0.18;
    return s.clamp(0.0, 1.0);
  }

  double divisor(double target) => math.max(target, 0.001);
}

class ImageQualityResult {
  const ImageQualityResult({
    required this.passed,
    required this.score,
    required this.issues,
    this.blurVariance = 0,
    this.meanBrightness = 0,
    this.torsoOrganicRatio = 0,
  });

  factory ImageQualityResult.failed(List<String> issues) {
    return ImageQualityResult(passed: false, score: 0, issues: issues);
  }

  final bool passed;
  final double score;
  final List<String> issues;
  final double blurVariance;
  final double meanBrightness;
  final double torsoOrganicRatio;

  Map<String, dynamic> toFirestore() => {
        'imageQualityPassed': passed,
        'imageQualityScore': score,
        'imageQualityIssues': issues,
        'blurVariance': blurVariance,
        'meanBrightness': meanBrightness,
        'torsoOrganicRatio': torsoOrganicRatio,
      };
}
