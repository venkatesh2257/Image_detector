import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'inference_logger.dart';

/// Rear milk-mirror landmarks (normalized 0–1 image coordinates).
class RearAnatomyLandmarks {
  final Offset pointA;
  final Offset pointB;
  final Offset pointC;
  final Offset pointD;
  final Offset leftPin;
  final Offset rightPin;
  final Offset udder;
  final double confidence;
  /// True when landmarks are a fixed template (not silhouette-derived).
  final bool isTemplateFallback;

  const RearAnatomyLandmarks({
    required this.pointA,
    required this.pointB,
    required this.pointC,
    required this.pointD,
    required this.leftPin,
    required this.rightPin,
    required this.udder,
    required this.confidence,
    this.isTemplateFallback = false,
  });

  List<Offset> get overlayKeypoints => [leftPin, rightPin, udder, pointA];
}

/// Robust rear-view anatomy for varying farm photos (mud, offset animal, light).
class RearAnatomyDetector {
  static const int _step = 2;

  RearAnatomyLandmarks? detectFromPath(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) return null;
    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) return null;
    return detect(img.bakeOrientation(decoded));
  }

  RearAnatomyLandmarks? detect(img.Image image) {
    image = img.bakeOrientation(image);
    final w = image.width;
    final h = image.height;
    if (w < 32 || h < 32) return null;

    final torso = _buildTorsoModel(image);
    if (torso == null) {
      InferenceLogger.log('ANATOMY', 'Fallback: full-frame template');
      return _templateLandmarksToResult(
        image,
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        w / 2,
        h * 0.45,
      );
    }

    final pinPair = _findPinPair(image, torso);
    var leftPin = pinPair.leftPin;
    var rightPin = pinPair.rightPin;
    var udder = _findUdder(image, torso, leftPin, rightPin);
    var pointA = _findTailPoint(image, torso, leftPin, rightPin);

    final corrected = _validateAndCorrect(
      image,
      torso,
      pointA,
      leftPin,
      rightPin,
      udder,
    );
    final aligned = _alignToSpineAxis(
      image,
      torso,
      corrected.pointA,
      corrected.leftPin,
      corrected.rightPin,
      corrected.udder,
    );
    pointA = aligned.pointA;
    leftPin = aligned.leftPin;
    rightPin = aligned.rightPin;
    udder = aligned.udder;

    final pointB = udder;
    final pointC = leftPin;
    final pointD = rightPin;

    final conf = _scoreConfidence(leftPin, rightPin, udder, torso);

    InferenceLogger.log(
      'ANATOMY',
      'Torso cx=${torso.cxNorm.toStringAsFixed(2)} '
      'box=(${torso.box.left / w}).${(torso.box.top / h)} '
      'L=(${leftPin.dx.toStringAsFixed(2)},${leftPin.dy.toStringAsFixed(2)}) '
      'R=(${rightPin.dx.toStringAsFixed(2)},${rightPin.dy.toStringAsFixed(2)}) '
      'U=(${udder.dx.toStringAsFixed(2)},${udder.dy.toStringAsFixed(2)}) '
      'conf=${(conf * 100).toStringAsFixed(0)}%',
    );

    return RearAnatomyLandmarks(
      pointA: pointA,
      pointB: pointB,
      pointC: pointC,
      pointD: pointD,
      leftPin: leftPin,
      rightPin: rightPin,
      udder: udder,
      confidence: conf,
      isTemplateFallback: false,
    );
  }

  // ─── Torso model ─────────────────────────────────────────────────────

  _TorsoModel? _buildTorsoModel(img.Image image) {
    final w = image.width;
    final h = image.height;
    final mask = List.generate(h, (_) => List<bool>.filled(w, false));

    var sumX = 0.0;
    var sumY = 0.0;
    var count = 0;

    for (var y = 0; y < h; y += _step) {
      for (var x = 0; x < w; x += _step) {
        if (_isAnimalPixel(image.getPixel(x, y))) {
          mask[y][x] = true;
          sumX += x;
          sumY += y;
          count++;
        }
      }
    }

    if (count < (w * h) / (_step * _step * 45)) return null;

    final cenX = sumX / count;
    final cenY = sumY / count;

    // Keep pixels near centroid (drops side mud / distant fence)
    var minX = w.toDouble();
    var minY = h.toDouble();
    var maxX = 0.0;
    var maxY = 0.0;
    var kept = 0;
    final maxDist = math.min(w, h) * 0.48;

    for (var y = 0; y < h; y += _step) {
      for (var x = 0; x < w; x += _step) {
        if (!mask[y][x]) continue;
        final d = math.sqrt((x - cenX) * (x - cenX) + (y - cenY) * (y - cenY));
        if (d > maxDist) continue;
        kept++;
        minX = math.min(minX, x.toDouble());
        minY = math.min(minY, y.toDouble());
        maxX = math.max(maxX, x.toDouble());
        maxY = math.max(maxY, y.toDouble());
      }
    }

    if (kept < count * 0.35) {
      minX = sumX / count - w * 0.2;
      maxX = sumX / count + w * 0.2;
      minY = sumY / count - h * 0.25;
      maxY = sumY / count + h * 0.25;
    }

    // Trim horizontal extent using column occupancy (drops side mud/fence)
    final colCounts = List<int>.filled(w, 0);
    for (var y = 0; y < h; y += _step) {
      for (var x = 0; x < w; x += _step) {
        if (!mask[y][x]) continue;
        final d = math.sqrt((x - cenX) * (x - cenX) + (y - cenY) * (y - cenY));
        if (d > maxDist) continue;
        colCounts[x]++;
      }
    }
    var peakCol = 0;
    for (var x = 0; x < w; x++) {
      peakCol = math.max(peakCol, colCounts[x]);
    }
    if (peakCol > 0) {
      final colThresh = peakCol * 0.14;
      var trimL = w.toDouble();
      var trimR = 0.0;
      for (var x = 0; x < w; x++) {
        if (colCounts[x] < colThresh) continue;
        trimL = math.min(trimL, x.toDouble());
        trimR = math.max(trimR, x.toDouble());
      }
      if (trimR > trimL + w * 0.15) {
        minX = math.max(minX, trimL);
        maxX = math.min(maxX, trimR);
      }
    }

    final padX = (maxX - minX) * 0.03;
    final padY = (maxY - minY) * 0.02;
    final box = ui.Rect.fromLTRB(
      (minX - padX).clamp(0, w - 1).toDouble(),
      (minY - padY).clamp(0, h - 1).toDouble(),
      (maxX + padX).clamp(0, w - 1).toDouble(),
      (maxY + padY).clamp(0, h - 1).toDouble(),
    );

    return _TorsoModel(
      box: box,
      cxNorm: (cenX / w).clamp(0.0, 1.0),
      cyNorm: (cenY / h).clamp(0.0, 1.0),
      centroidX: cenX,
      centroidY: cenY,
    );
  }

  bool _isAnimalPixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    if (br > 220 || br < 18) return false;
    if (g > r + 28 && g > b + 22 && br > 75) return false;
    if (b > r + 35 && b > g + 15 && br > 90) return false; // sky
    return br < 175;
  }

  // ─── Landmark finders ──────────────────────────────────────────────────

  /// Pin row from silhouette width (hips ~18–24% in from each flank).
  _LandmarkSet _findPinPair(img.Image image, _TorsoModel torso) {
    final w = image.width;
    final h = image.height;
    final box = torso.box;
    final bh = box.height;

    var bestY = box.top + bh * 0.36;
    var bestScore = -1.0;

    for (var y = box.top + bh * 0.28; y <= box.top + bh * 0.46; y += 2) {
      final sil = _silhouetteAtRow(image, box, y.round());
      if (sil == null) continue;
      final width = sil.right - sil.left;
      if (width < box.width * 0.35) continue;
      final edgeScore = _pinRowScore(image, box, y.round(), sil.centerX);
      final score = width * 0.4 + edgeScore * 0.6;
      if (score > bestScore) {
        bestScore = score;
        bestY = y;
      }
    }

    final yPx = bestY.round().clamp(0, h - 1);
    final sil = _silhouetteAtRow(image, box, yPx);
    if (sil == null) {
      final cx = torso.centroidX;
      return _LandmarkSet(
        Offset.zero,
        Offset((cx - box.width * 0.2) / w, 0.38),
        Offset((cx + box.width * 0.2) / w, 0.38),
        Offset.zero,
      );
    }

    final width = sil.right - sil.left;
    // Pin bones sit inward from the outer flank on rear view.
    const inset = 0.21;
    var leftX = sil.left + width * inset;
    var rightX = sil.right - width * inset;

    // Nudge toward strongest horizontal edges near silhouette insets.
    leftX = _refinePinX(image, yPx, leftX, sil.left, sil.centerX, isLeft: true);
    rightX = _refinePinX(image, yPx, rightX, sil.centerX, sil.right, isLeft: false);

    final pinY = (bestY / h).clamp(0.22, 0.50);
    return _LandmarkSet(
      Offset.zero,
      Offset((leftX / w).clamp(0.05, 0.95), pinY),
      Offset((rightX / w).clamp(0.05, 0.95), pinY),
      Offset.zero,
    );
  }

  _RowSilhouette? _silhouetteAtRow(img.Image image, ui.Rect box, int y) {
    if (y < 0 || y >= image.height) return null;
    final x0 = box.left.round();
    final x1 = box.right.round();
    var left = x1;
    var right = x0;
    for (var x = x0; x <= x1; x++) {
      if (!_isAnimalPixel(image.getPixel(x, y))) continue;
      left = math.min(left, x);
      right = math.max(right, x);
    }
    if (right <= left + 4) return null;
    return _RowSilhouette(left.toDouble(), right.toDouble());
  }

  double _refinePinX(
    img.Image image,
    int y,
    double estimate,
    double searchMin,
    double searchMax, {
    required bool isLeft,
  }) {
    final lo = (estimate - 12).clamp(searchMin, searchMax).round();
    final hi = (estimate + 12).clamp(searchMin, searchMax).round();
    var bestX = estimate;
    var bestEdge = -1.0;
    for (var x = lo; x <= hi; x++) {
      if (x < 2 || x >= image.width - 2) continue;
      final edge = _edgeStrength(image, x, y);
      final bias = isLeft ? (searchMin + 8 - x).abs() * 0.15 : (x - searchMax + 8).abs() * 0.15;
      final score = edge - bias;
      if (score > bestEdge) {
        bestEdge = score;
        bestX = x.toDouble();
      }
    }
    return bestX;
  }

  double _pinRowScore(img.Image image, ui.Rect box, int y, double cx) {
    if (y < 1 || y >= image.height - 1) return 0;
    final x0 = box.left.round();
    final x1 = box.right.round();
    final mid = cx.round();
    var leftPeak = 0.0;
    var rightPeak = 0.0;

    for (var x = x0; x < mid; x++) {
      leftPeak = math.max(leftPeak, _edgeStrength(image, x, y));
    }
    for (var x = mid; x < x1; x++) {
      rightPeak = math.max(rightPeak, _edgeStrength(image, x, y));
    }
    return leftPeak + rightPeak;
  }

  Offset _findUdder(
    img.Image image,
    _TorsoModel torso,
    Offset leftPin,
    Offset rightPin,
  ) {
    final w = image.width;
    final h = image.height;
    final box = torso.box;
    final bh = box.height;
    final pinY = ((leftPin.dy + rightPin.dy) / 2) * h;

    final yMin = math.max(box.top + bh * 0.52, pinY + bh * 0.08);
    final yMax = box.top + bh * 0.80;
    final xMin = (math.min(leftPin.dx, rightPin.dx) * w + box.width * 0.05)
        .clamp(box.left, box.right);
    final xMax = (math.max(leftPin.dx, rightPin.dx) * w - box.width * 0.05)
        .clamp(box.left, box.right);
    final spineX = ((leftPin.dx + rightPin.dx) / 2) * w;

    var bestY = yMin + (yMax - yMin) * 0.45;
    var bestX = spineX;
    var bestScore = -1.0;

    for (var y = yMin; y <= yMax; y += _step) {
      var rowScore = 0.0;
      var massX = 0.0;
      var massW = 0.0;
      for (var x = xMin.round(); x <= xMax.round(); x += _step) {
        final p = image.getPixel(x, y.round());
        if (!_isUdderPixel(p)) continue;
        final s = _udderWeight(p);
        rowScore += s;
        massX += x * s;
        massW += s;
      }
      if (rowScore > bestScore && massW > 0) {
        bestScore = rowScore;
        bestY = y;
        bestX = massX / massW;
      }
    }

    if (bestScore < 0) {
      bestX = spineX;
      bestY = pinY + bh * 0.22;
    }

    var udderX = bestX / w;
    if ((udderX - (leftPin.dx + rightPin.dx) / 2).abs() < 0.10) {
      udderX = (leftPin.dx + rightPin.dx) / 2;
    }

    return Offset(
      udderX.clamp(leftPin.dx + 0.02, rightPin.dx - 0.02),
      (bestY / h).clamp(pinY / h + 0.08, 0.82),
    );
  }

  bool _isUdderPixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final pink = r > 90 && g > 65 && b > 70 && r < 200 && g < 165;
    return pink || (br > 35 && br < 140);
  }

  double _udderWeight(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    if (r > 95 && g > 70 && b > 75) return 3.0;
    return 1.0;
  }

  Offset _findTailPoint(
    img.Image image,
    _TorsoModel torso,
    Offset leftPin,
    Offset rightPin,
  ) {
    final w = image.width;
    final h = image.height;
    final box = torso.box;
    final spineX = ((leftPin.dx + rightPin.dx) / 2) * w;
    final top = box.top;
    final pinY = ((leftPin.dy + rightPin.dy) / 2) * h;
    final ySearchEnd = math.min(box.top + box.height * 0.28, pinY - box.height * 0.08);

    var bestY = top + box.height * 0.08;
    var bestScore = double.infinity;

    // Tail base: narrowest spine column just above the pin row.
    for (var y = top; y <= ySearchEnd; y += 2) {
      var colWidth = 0;
      final x0 = (spineX - box.width * 0.08).round().clamp(0, w - 1);
      final x1 = (spineX + box.width * 0.08).round().clamp(0, w - 1);
      for (var x = x0; x <= x1; x++) {
        if (_isAnimalPixel(image.getPixel(x, y.round()))) colWidth++;
      }
      final yNorm = (y - top) / math.max(1, ySearchEnd - top);
      final score = colWidth + yNorm * 3; // prefer higher rows when similar
      if (colWidth > 0 && score < bestScore) {
        bestScore = score;
        bestY = y;
      }
    }

    return Offset(
      (spineX / w).clamp(0.0, 1.0),
      (bestY / h).clamp(0.04, leftPin.dy - 0.04),
    );
  }

  // ─── Validation / fallback ─────────────────────────────────────────────

  _LandmarkSet _validateAndCorrect(
    img.Image image,
    _TorsoModel torso,
    Offset pointA,
    Offset leftPin,
    Offset rightPin,
    Offset udder,
  ) {
    final w = image.width.toDouble();
    final box = torso.box;

    var l = leftPin;
    var r = rightPin;
    var u = udder;
    var a = pointA;

    if (l.dx > r.dx) {
      final t = l;
      l = r;
      r = t;
    }

    var spread = r.dx - l.dx;
    final margin = 0.02;
    final minX = (box.left / w) + margin;
    final maxX = (box.right / w) - margin;

    // Rescale pin spread to escutcheon proportions before falling back to template
    if (spread < 0.12 || spread > 0.65) {
      final mid = (l.dx + r.dx) / 2;
      final target = ((box.width / w) * 0.48).clamp(0.22, 0.48);
      l = Offset((mid - target / 2).clamp(minX, maxX), l.dy);
      r = Offset((mid + target / 2).clamp(minX, maxX), r.dy);
      spread = r.dx - l.dx;
      InferenceLogger.log(
        'ANATOMY',
        'Rescaled pin spread → ${spread.toStringAsFixed(2)}',
      );
    }

    final validSpread = spread >= 0.12 && spread <= 0.65;
    final validOrder = l.dy < u.dy && a.dy < u.dy;
    final uInBox = u.dx > l.dx && u.dx < r.dx;

    if (!validSpread || !validOrder || !uInBox) {
      InferenceLogger.log(
        'ANATOMY',
        'Validation fail (spread=$validSpread order=$validOrder uInBox=$uInBox) → template',
      );
      return _templateLandmarks(box, torso.centroidX, image.width, image.height);
    }

    // Snap udder X to centroid if drifted outside pin span
    if (u.dx <= l.dx + 0.03 || u.dx >= r.dx - 0.03) {
      u = Offset(
        ((l.dx + r.dx) / 2).clamp(l.dx + 0.05, r.dx - 0.05),
        u.dy,
      );
    }

    // Keep escutcheon inside torso horizontally
    l = Offset(l.dx.clamp(minX, maxX), l.dy);
    r = Offset(r.dx.clamp(minX, maxX), r.dy);

    return _LandmarkSet(a, l, r, u);
  }

  /// Centers escutcheon on spine: level pins, vertical A–B axis, udder on midline.
  _LandmarkSet _alignToSpineAxis(
    img.Image image,
    _TorsoModel torso,
    Offset pointA,
    Offset leftPin,
    Offset rightPin,
    Offset udder,
  ) {
    final h = image.height.toDouble();
    final box = torso.box;

    var l = leftPin;
    var r = rightPin;
    if (l.dx > r.dx) {
      final t = l;
      l = r;
      r = t;
    }

    final spineX = ((l.dx + r.dx) / 2).clamp(0.05, 0.95);
    final pinY = ((l.dy + r.dy) / 2).clamp(0.20, 0.52);

    l = Offset(l.dx, pinY);
    r = Offset(r.dx, pinY);

    var a = Offset(spineX, pointA.dy.clamp(box.top / h + 0.02, pinY - 0.06));
    var u = udder;

    // Keep udder centered unless pink mass is clearly off-axis (<12% offset).
    if ((u.dx - spineX).abs() < 0.12) {
      u = Offset(spineX, u.dy);
    } else {
      u = Offset(
        u.dx.clamp(l.dx + 0.03, r.dx - 0.03),
        u.dy,
      );
    }

    u = Offset(
      u.dx,
      u.dy.clamp(pinY + 0.10, (box.bottom / h) - 0.02).clamp(pinY + 0.08, 0.88),
    );

    return _LandmarkSet(a, l, r, u);
  }

  RearAnatomyLandmarks _templateLandmarksToResult(
    img.Image image,
    ui.Rect box,
    double cxPx,
    double cyPx,
  ) {
    final set = _templateLandmarks(box, cxPx, image.width, image.height);
    return RearAnatomyLandmarks(
      pointA: set.pointA,
      pointB: set.udder,
      pointC: set.leftPin,
      pointD: set.rightPin,
      leftPin: set.leftPin,
      rightPin: set.rightPin,
      udder: set.udder,
      confidence: 0.5,
      isTemplateFallback: true,
    );
  }

  _LandmarkSet _templateLandmarks(
    ui.Rect box,
    double cxPx,
    int imgW,
    int imgH,
  ) {
    final w = imgW.toDouble();
    final h = imgH.toDouble();
    final cx = cxPx / w;
    final top = box.top / h;
    final bh = box.height / h;
    final spread = (bh * 0.42).clamp(0.18, 0.48);

    final l = Offset((cx - spread / 2).clamp(0.05, 0.95), top + bh * 0.38);
    final r = Offset((cx + spread / 2).clamp(0.05, 0.95), top + bh * 0.38);
    final u = Offset(cx.clamp(l.dx + 0.05, r.dx - 0.05), top + bh * 0.68);
    final a = Offset(cx, top + bh * 0.12);
    return _LandmarkSet(a, l, r, u);
  }

  double _scoreConfidence(Offset l, Offset r, Offset u, _TorsoModel torso) {
    final spread = (r.dx - l.dx).clamp(0.0, 1.0);
    final vertical = (u.dy - l.dy).clamp(0.0, 1.0);
    return (0.4 +
            spread.clamp(0.15, 0.55) * 0.5 +
            vertical.clamp(0.12, 0.45) * 0.4)
        .clamp(0.35, 0.92);
  }

  double _edgeStrength(img.Image image, int x, int y) {
    final c = image.getPixel(x, y).r;
    final l = image.getPixel(x - 1, y).r;
    final r = image.getPixel(x + 1, y).r;
    final u = image.getPixel(x, y - 1).r;
    final d = image.getPixel(x, y + 1).r;
    return ((c - l).abs() + (c - r).abs() + (c - u).abs() + (c - d).abs()) / 4;
  }
}

class _TorsoModel {
  final ui.Rect box;
  final double cxNorm;
  final double cyNorm;
  final double centroidX;
  final double centroidY;

  const _TorsoModel({
    required this.box,
    required this.cxNorm,
    required this.cyNorm,
    required this.centroidX,
    required this.centroidY,
  });
}

class _LandmarkSet {
  final Offset pointA;
  final Offset leftPin;
  final Offset rightPin;
  final Offset udder;

  _LandmarkSet(this.pointA, this.leftPin, this.rightPin, this.udder);
}

class _RowSilhouette {
  final double left;
  final double right;
  _RowSilhouette(this.left, this.right);
  double get centerX => (left + right) / 2;
  double get width => right - left;
}
