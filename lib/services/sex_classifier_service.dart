import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'inference_logger.dart';

/// Rear-view sex classification for dairy buffalo (female vs bull).
///
/// Uses escutcheon / lower-body vision cues: udder & pink tissue (female),
/// absent udder + bilateral hindquarter mass without teat tissue (bull).
class SexClassificationResult {
  final String label;
  final double confidence;
  final double femaleProbability;
  final double udderTissueScore;
  final double bullStructureScore;
  final String detail;

  const SexClassificationResult({
    required this.label,
    required this.confidence,
    required this.femaleProbability,
    required this.udderTissueScore,
    required this.bullStructureScore,
    required this.detail,
  });

  bool get isFemale => label == 'Female';
  bool get isBull => label == 'Male (Bull)';
}

class SexClassifierService {
  static const int _sampleStep = 2;

  SexClassificationResult classifyFile(
    String imagePath, {
    bool udderKeypointDetected = false,
    String? udderSizeHint,
  }) {
    try {
      final bytes = File(imagePath).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return _uncertain('Could not decode image');
      }
      return classifyImage(
        decoded,
        udderKeypointDetected: udderKeypointDetected,
        udderSizeHint: udderSizeHint,
      );
    } catch (e) {
      InferenceLogger.log('SEX', 'classifyFile error: $e');
      return _uncertain('Analysis error');
    }
  }

  SexClassificationResult classifyImage(
    img.Image image, {
    bool udderKeypointDetected = false,
    String? udderSizeHint,
  }) {
    final w = image.width;
    final h = image.height;
    final lowerY = (h * 0.55).round();
    final centerX = w ~/ 2;
    final bandW = (w * 0.38).round();

    int lowerTotal = 0;
    int pinkPixels = 0;
    int udderSoftPixels = 0;
    int darkCompactPixels = 0;
    int leftMass = 0;
    int rightMass = 0;

    for (int y = lowerY; y < h; y += _sampleStep) {
      for (int x = 0; x < w; x += _sampleStep) {
        if ((x - centerX).abs() > bandW) continue;
        lowerTotal++;
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final brightness = (r + g + b) / 3;

        final isPinkUdder =
            r > 95 && g > 70 && b > 80 && r < 195 && g < 165 && b < 175;
        if (isPinkUdder) pinkPixels++;

        if (brightness > 25 && brightness < 125) udderSoftPixels++;

        if (brightness > 15 && brightness < 55) darkCompactPixels++;

        if (x < centerX) {
          if (brightness > 30 && brightness < 140) leftMass++;
        } else {
          if (brightness > 30 && brightness < 140) rightMass++;
        }
      }
    }

    if (lowerTotal == 0) return _uncertain('Empty lower region');

    final pinkRatio = pinkPixels / lowerTotal;
    final udderRatio = udderSoftPixels / lowerTotal;
    final darkRatio = darkCompactPixels / lowerTotal;
    final symmetry =
        1.0 - ((leftMass - rightMass).abs() / math.max(leftMass + rightMass, 1));

    var udderTissueScore = (pinkRatio * 2.8 + udderRatio * 1.2 + symmetry * 0.15)
        .clamp(0.0, 1.0);
    if (udderKeypointDetected) udderTissueScore = math.min(1.0, udderTissueScore + 0.22);
    if (udderSizeHint == 'large') udderTissueScore = math.min(1.0, udderTissueScore + 0.12);
    if (udderSizeHint == 'small') udderTissueScore = math.max(0.0, udderTissueScore - 0.08);

    var bullScore = ((1.0 - pinkRatio.clamp(0.0, 0.35) / 0.35) * 0.35 +
            darkRatio.clamp(0.0, 0.5) * 0.45 +
            symmetry * 0.1)
        .clamp(0.0, 1.0);
    if (!udderKeypointDetected && pinkRatio < 0.02) {
      bullScore = math.min(1.0, bullScore + 0.25);
    }
    if (udderKeypointDetected && pinkRatio > 0.03) {
      bullScore = math.max(0.0, bullScore - 0.35);
    }

    final femaleProb =
        (udderTissueScore / (udderTissueScore + bullScore + 0.001)).clamp(0.0, 1.0);

    String label;
    double confidence;
    String detail;

    if (femaleProb >= 0.58 && udderTissueScore >= 0.42) {
      label = 'Female';
      confidence = (0.55 + femaleProb * 0.4).clamp(0.0, 0.98);
      detail =
          'Udder tissue ${(udderTissueScore * 100).toStringAsFixed(0)}% · pink ${(pinkRatio * 100).toStringAsFixed(1)}%';
    } else if (femaleProb <= 0.38 && bullScore >= 0.48) {
      label = 'Male (Bull)';
      confidence = (0.5 + (1 - femaleProb) * 0.45).clamp(0.0, 0.95);
      detail =
          'No udder signal · hind structure ${(bullScore * 100).toStringAsFixed(0)}%';
    } else {
      label = 'Uncertain';
      confidence = 0.45;
      detail =
          'Female ${(femaleProb * 100).toStringAsFixed(0)}% · retake clear rear udder view';
    }

    InferenceLogger.log(
      'SEX',
      '$label @ ${(confidence * 100).toStringAsFixed(1)}% | '
      'udder=${udderTissueScore.toStringAsFixed(2)} bull=${bullScore.toStringAsFixed(2)} '
      'pink=${pinkRatio.toStringAsFixed(3)} kp=$udderKeypointDetected',
    );

    return SexClassificationResult(
      label: label,
      confidence: confidence,
      femaleProbability: femaleProb,
      udderTissueScore: udderTissueScore,
      bullStructureScore: bullScore,
      detail: detail,
    );
  }

  SexClassificationResult _uncertain(String reason) => SexClassificationResult(
        label: 'Uncertain',
        confidence: 0.4,
        femaleProbability: 0.5,
        udderTissueScore: 0,
        bullStructureScore: 0,
        detail: reason,
      );
}
