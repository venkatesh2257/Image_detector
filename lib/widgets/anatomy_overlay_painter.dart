import 'package:flutter/material.dart';

import '../services/milk_mirror_measurement_service.dart';
import 'anatomy_escutcheon_debug.dart';

/// Draws rear-view diamond landmarks (tail head, escutcheon sides, udder center).
class AnatomyOverlayPainter extends CustomPainter {
  final MilkMirrorUiMetrics? metrics;
  final List<Offset> fallbackKeypoints;
  final String leftLandmarkLabel;
  final String rightLandmarkLabel;
  final String udderLabel;

  AnatomyOverlayPainter({
    this.metrics,
    this.fallbackKeypoints = const [],
    this.leftLandmarkLabel = 'C',
    this.rightLandmarkLabel = 'D',
    this.udderLabel = 'Udder',
  });

  Offset _pt(Offset n, Size size) => Offset(n.dx * size.width, n.dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final kps = fallbackKeypoints;
    if (kps.length < 3) return;

    final leftPin = _pt(kps[0], size);
    final rightPin = _pt(kps[1], size);
    final udder = _pt(kps[2], size);
    final tailHead = kps.length > 3
        ? _pt(kps[3], size)
        : Offset((leftPin.dx + rightPin.dx) / 2, leftPin.dy - 40);

    paintEscutcheonDebugLayer(
      canvas,
      size,
      metrics: metrics,
      keypoints: kps,
    );

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final diamond = Path()
      ..moveTo(tailHead.dx, tailHead.dy)
      ..lineTo(leftPin.dx, leftPin.dy)
      ..lineTo(udder.dx, udder.dy)
      ..lineTo(rightPin.dx, rightPin.dy)
      ..close();
    canvas.drawPath(diamond, fillPaint);
    canvas.drawPath(diamond, linePaint);

    _drawMarker(canvas, tailHead, 'Tail', const Color(0xFFFFD54F));
    _drawMarker(canvas, leftPin, leftLandmarkLabel, Colors.redAccent);
    _drawMarker(canvas, rightPin, rightLandmarkLabel, Colors.redAccent);
    _drawMarker(canvas, udder, udderLabel, Colors.blueAccent);

    final pelvicW = (kps[1].dx - kps[0].dx).abs();
    final udderH = (kps[2].dy - (kps.length > 3 ? kps[3].dy : kps[0].dy - 0.08)).abs();
    final ratio = pelvicW > 0.01 ? udderH / pelvicW : 0.0;

    final measurementText =
        'Pel W: ${(pelvicW * 100).toStringAsFixed(0)}%  '
        'Udd H: ${(udderH * 100).toStringAsFixed(0)}%  '
        'Ratio: ${ratio.toStringAsFixed(2)}';
    final tp = TextPainter(
      text: TextSpan(
        text: measurementText,
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(4, 4));
  }

  void _drawMarker(Canvas canvas, Offset point, String label, Color color) {
    canvas.drawCircle(point, 10, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(point, 5, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(point.dx - tp.width / 2, point.dy - 16));
  }

  @override
  bool shouldRepaint(covariant AnatomyOverlayPainter old) =>
      old.metrics != metrics ||
      old.fallbackKeypoints != fallbackKeypoints ||
      old.leftLandmarkLabel != leftLandmarkLabel ||
      old.rightLandmarkLabel != rightLandmarkLabel ||
      old.udderLabel != udderLabel;
}
