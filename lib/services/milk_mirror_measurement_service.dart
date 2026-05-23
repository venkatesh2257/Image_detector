import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'inference_logger.dart';
import 'milk_mirror_calibration.dart';
import 'milk_production_scale.dart';
import 'rear_anatomy_detector.dart';

/// Milk Mirror escutcheon logic (master diagram):
/// A–B = height, C–D = width, area, symmetry → yield estimate.
class MilkMirrorMeasurementService {
  static const int _sampleStep = 3;
  MilkMirrorCalibration? _calibration;
  bool _calibrationLoaded = false;

  Future<void> ensureCalibrationLoaded() async {
    if (_calibrationLoaded) return;
    _calibration = await MilkMirrorCalibration.loadFromAssets();
    _calibrationLoaded = true;
    if (_calibration != null) {
      InferenceLogger.log('MILK_MIRROR', 'Using dataset calibration coefficients');
    }
  }

  MilkMirrorResult measureFromImage(
    String imagePath, {
    Offset? leftHip,
    Offset? rightHip,
    Offset? udder,
    Offset? spine,
  }) {
    InferenceLogger.log('MILK_MIRROR', 'Starting escutcheon measurement');

    final file = File(imagePath);
    if (!file.existsSync()) {
      return MilkMirrorResult.failed('Image file not found');
    }

    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return MilkMirrorResult.failed('Could not decode image');
    }
    final image = img.bakeOrientation(decoded);

    late final Offset leftPin;
    late final Offset rightPin;
    late final Offset udderPt;
    late final Offset pointA;
    late final Offset pointB;
    late final Offset pointC;
    late final Offset pointD;
    var anatomyConfidence = 0.0;

    if (leftHip != null && rightHip != null && udder != null) {
      leftPin = leftHip;
      rightPin = rightHip;
      udderPt = udder;
      pointA = spine ?? Offset((leftHip.dx + rightHip.dx) / 2, leftHip.dy - 0.08);
      pointB = udder;
      pointC = Offset(leftPin.dx, (leftPin.dy + udderPt.dy) / 2);
      pointD = Offset(rightPin.dx, (rightPin.dy + udderPt.dy) / 2);
      anatomyConfidence = 0.85;
      InferenceLogger.log('MILK_MIRROR', 'Using landmarks from rules gate');
    } else {
      final anatomy = RearAnatomyDetector().detect(image);
      if (anatomy != null) {
        leftPin = anatomy.leftPin;
        rightPin = anatomy.rightPin;
        udderPt = anatomy.udder;
        pointA = anatomy.pointA;
        pointB = anatomy.pointB;
        pointC = anatomy.leftPin;
        pointD = anatomy.rightPin;
        anatomyConfidence = anatomy.confidence;
        InferenceLogger.log('MILK_MIRROR', 'Using rear anatomy detector landmarks');
      } else {
      final w = image.width.toDouble();
      final h = image.height.toDouble();
        final l = leftHip ?? _detectLeftHip(image, w, h);
        final r = rightHip ?? _detectRightHip(image, w, h);
        final u = udder ?? _detectUdder(image, w, h);
        final s = spine ?? _detectSpine(image, w, h);
        if (l == null || r == null || u == null) {
          InferenceLogger.log('MILK_MIRROR', 'Missing landmarks L=$l R=$r U=$u');
          return MilkMirrorResult.failed(
            'Could not find pin bones / udder — use rear milk-mirror photo (3–5 ft, full udder)',
          );
        }
        leftPin = l;
        rightPin = r;
        udderPt = u;
        pointA = s ?? Offset((l.dx + r.dx) / 2, l.dy - 0.08);
        pointB = u;
        pointC = Offset(l.dx, (l.dy + u.dy) / 2);
        pointD = Offset(r.dx, (r.dy + u.dy) / 2);
      }
    }

    var height = (pointB.dy - pointA.dy).abs();
    var width = (pointD.dx - pointC.dx).abs();
    // Reject degenerate escutcheon from bad alignment
    if (height < 0.08 || width < 0.06) {
      return MilkMirrorResult.failed(
        'Could not align Milk Mirror on this photo — use centered rear view, full udder visible',
      );
    }
    height = height.clamp(0.05, 0.95);
    width = width.clamp(0.05, 0.95);
    final areaNorm = height * width;

    final symmetry = _symmetryIndex(image, udderPt);
    final fullness = _udderFullness(image, pointC, pointD, pointB);
    final texture = _textureScore(image, pointC, pointD, pointA, pointB);

    var liters = 1.0 +
        (areaNorm * (MilkProductionScale.maxLiters - 1.0)) +
        (fullness * 2.5) -
        (symmetry * 2.0);
    if (_calibration != null) {
      liters = _calibration!.predict(
        areaNorm: areaNorm,
        fullness: fullness,
        symmetryIndex: symmetry,
      );
    }
    liters = MilkProductionScale.clamp(liters);

    var confidence =
        (0.35 + areaNorm * 0.4 + (1 - symmetry) * 0.15 + fullness * 0.1)
            .clamp(0.2, 0.92);
    if (anatomyConfidence > 0) {
      confidence = ((confidence + anatomyConfidence) / 2).clamp(0.2, 0.95);
    }

    final keypoints = [leftPin, rightPin, udderPt, pointA];

    InferenceLogger.log(
      'MILK_MIRROR',
      'A=$pointA B=$pointB C=$pointC D=$pointD',
    );
    InferenceLogger.log(
      'MILK_MIRROR',
      'H=${height.toStringAsFixed(3)} W=${width.toStringAsFixed(3)} '
      'Area=${areaNorm.toStringAsFixed(3)} Sym=${symmetry.toStringAsFixed(3)}',
    );
    InferenceLogger.log(
      'MILK_MIRROR',
      'Predicted ${liters.toStringAsFixed(1)} L/day conf=${(confidence * 100).toStringAsFixed(1)}%',
    );

    return MilkMirrorResult(
      success: true,
      litersPerDay: liters,
      confidence: confidence,
      keypoints: keypoints,
      pointA: pointA,
      pointB: pointB,
      pointC: pointC,
      pointD: pointD,
      heightNorm: height,
      widthNorm: width,
      areaNorm: areaNorm,
      symmetryIndex: symmetry,
      udderFullness: fullness,
      textureScore: texture,
    );
  }

  double _symmetryIndex(img.Image image, Offset udderCenter) {
    final cx = (udderCenter.dx * image.width).round();
    final y0 = (image.height * 0.55).round();
    var left = 0;
    var right = 0;
    for (var y = y0; y < image.height; y += _sampleStep) {
      for (var x = 0; x < image.width; x += _sampleStep) {
        final p = image.getPixel(x, y);
        final b = (p.r + p.g + p.b) / 3;
        if (b < 35 || b > 200) continue;
        if (x < cx) {
          left++;
        } else {
          right++;
        }
      }
    }
    final total = left + right;
    if (total == 0) return 0.5;
    return ((left - right).abs() / total).clamp(0.0, 1.0);
  }

  double _udderFullness(
    img.Image image,
    Offset c,
    Offset d,
    Offset b,
  ) {
    final x0 = (c.dx * image.width).round();
    final x1 = (d.dx * image.width).round();
    final y0 = (b.dy * image.height * 0.85).round();
    final y1 = image.height;
    var udderPx = 0;
    var total = 0;
    for (var y = y0; y < y1; y += _sampleStep) {
      for (var x = x0; x < x1; x += _sampleStep) {
        if (x < 0 || x >= image.width) continue;
        total++;
        final p = image.getPixel(x, y);
        final bVal = (p.r + p.g + p.b) / 3;
        if (bVal > 30 && bVal < 140) udderPx++;
      }
    }
    if (total == 0) return 0.3;
    return (udderPx / total).clamp(0.0, 1.0);
  }

  double _textureScore(
    img.Image image,
    Offset c,
    Offset d,
    Offset a,
    Offset b,
  ) {
    var edges = 0;
    var samples = 0;
    final x0 = (c.dx * image.width).round().clamp(0, image.width - 2);
    final x1 = (d.dx * image.width).round().clamp(1, image.width - 1);
    final y0 = (a.dy * image.height).round().clamp(0, image.height - 2);
    final y1 = (b.dy * image.height).round().clamp(1, image.height - 1);
    for (var y = y0; y < y1; y += _sampleStep) {
      for (var x = x0; x < x1; x += _sampleStep) {
        samples++;
        final p = image.getPixel(x, y).r;
        final px = image.getPixel(x + 1, y).r;
        final py = image.getPixel(x, y + 1).r;
        if ((p - px).abs() > 25 || (p - py).abs() > 25) edges++;
      }
    }
    if (samples == 0) return 0.5;
    return (edges / samples).clamp(0.0, 1.0);
  }

  Offset? _detectSpine(img.Image image, double w, double h) {
    final cx = w / 2;
    return Offset(cx / w, 0.18);
  }

  Offset? _detectLeftHip(img.Image image, double w, double h) {
    final cx = w / 2;
    final hipY = h * 0.48;
    final hipW = w / 3;
    var best = 0;
    var bx = cx - hipW / 2;
    for (var y = (hipY - 15).round(); y <= (hipY + 15).round(); y++) {
      for (var x = (cx - hipW).round(); x < cx.round(); x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        final br = (image.getPixel(x, y).r +
                image.getPixel(x, y).g +
                image.getPixel(x, y).b) /
            3;
        if (br > 45 && br < 155) best++;
      }
    }
    return best > 2 ? Offset((cx - hipW / 2) / w, hipY / h) : null;
  }

  Offset? _detectRightHip(img.Image image, double w, double h) {
    final cx = w / 2;
    final hipY = h * 0.48;
    final hipW = w / 3;
    var best = 0;
    for (var y = (hipY - 15).round(); y <= (hipY + 15).round(); y++) {
      for (var x = cx.round(); x < (cx + hipW).round(); x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        final br = (image.getPixel(x, y).r +
                image.getPixel(x, y).g +
                image.getPixel(x, y).b) /
            3;
        if (br > 45 && br < 155) best++;
      }
    }
    return best > 2 ? Offset((cx + hipW / 2) / w, hipY / h) : null;
  }

  Offset? _detectUdder(img.Image image, double w, double h) {
    final cx = w / 2;
    final y0 = h * 0.62;
    var score = 0.0;
    var bestY = y0;
    for (var y = y0.round(); y < h; y++) {
      var row = 0;
      for (var x = (cx - w / 5).round(); x < (cx + w / 5).round(); x++) {
        if (x < 0 || x >= w) continue;
        final br = (image.getPixel(x, y).r +
                image.getPixel(x, y).g +
                image.getPixel(x, y).b) /
            3;
        if (br > 25 && br < 130) row++;
      }
      if (row > score) {
        score = row.toDouble();
        bestY = y.toDouble();
      }
    }
    return score > 3 ? Offset(cx / w, bestY / h) : null;
  }
}

class MilkMirrorResult {
  final bool success;
  final String? error;
  final double litersPerDay;
  final double confidence;
  final List<Offset> keypoints;
  final Offset? pointA;
  final Offset? pointB;
  final Offset? pointC;
  final Offset? pointD;
  final double heightNorm;
  final double widthNorm;
  final double areaNorm;
  final double symmetryIndex;
  final double udderFullness;
  final double textureScore;

  const MilkMirrorResult({
    required this.success,
    this.error,
    this.litersPerDay = 0,
    this.confidence = 0,
    this.keypoints = const [],
    this.pointA,
    this.pointB,
    this.pointC,
    this.pointD,
    this.heightNorm = 0,
    this.widthNorm = 0,
    this.areaNorm = 0,
    this.symmetryIndex = 0,
    this.udderFullness = 0,
    this.textureScore = 0,
  });

  factory MilkMirrorResult.failed(String message) => MilkMirrorResult(
        success: false,
        error: message,
      );

  String get rangeLabel => MilkProductionScale.formatBand(litersPerDay);

  String get exactLabel => MilkProductionScale.formatExact(litersPerDay);

  MilkMirrorUiMetrics toUiMetrics({
    String tfliteBand = '',
    double tfliteConfidence = 0,
  }) =>
      MilkMirrorUiMetrics(
        litersPerDay: litersPerDay,
        rangeLabel: rangeLabel,
        confidence: confidence,
        heightNorm: heightNorm,
        widthNorm: widthNorm,
        areaNorm: areaNorm,
        symmetryIndex: symmetryIndex,
        symmetryPercent: ((1 - symmetryIndex) * 100).clamp(0, 100),
        udderFullness: udderFullness,
        textureScore: textureScore,
        pointA: pointA,
        pointB: pointB,
        pointC: pointC,
        pointD: pointD,
        tfliteBand: tfliteBand,
        tfliteConfidence: tfliteConfidence,
      );
}

/// Data for Milk Mirror UI (escutcheon card + overlay labels A–D).
class MilkMirrorUiMetrics {
  final double litersPerDay;
  final String rangeLabel;
  final double confidence;
  final double heightNorm;
  final double widthNorm;
  final double areaNorm;
  final double symmetryIndex;
  final double symmetryPercent;
  final double udderFullness;
  final double textureScore;
  final Offset? pointA;
  final Offset? pointB;
  final Offset? pointC;
  final Offset? pointD;
  final String tfliteBand;
  final double tfliteConfidence;

  const MilkMirrorUiMetrics({
    required this.litersPerDay,
    required this.rangeLabel,
    required this.confidence,
    required this.heightNorm,
    required this.widthNorm,
    required this.areaNorm,
    required this.symmetryIndex,
    required this.symmetryPercent,
    required this.udderFullness,
    required this.textureScore,
    this.pointA,
    this.pointB,
    this.pointC,
    this.pointD,
    this.tfliteBand = '',
    this.tfliteConfidence = 0,
  });
}
