import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/milk_mirror_measurement_service.dart';

/// Draws Milk Mirror landmarks on the fitted image rect (normalized 0–1 coords).
class AnatomyOverlayPainter extends CustomPainter {
  final MilkMirrorUiMetrics? metrics;
  final List<Offset> fallbackKeypoints;

  AnatomyOverlayPainter({
    this.metrics,
    this.fallbackKeypoints = const [],
  });

  Offset _pt(Offset n, Size size) => Offset(n.dx * size.width, n.dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    if (m == null ||
        m.pointA == null ||
        m.pointB == null ||
        m.pointC == null ||
        m.pointD == null) {
      return;
    }

    final pointA = _pt(m.pointA!, size);
    final pointB = _pt(m.pointB!, size);
    final pointC = _pt(m.pointC!, size);
    final pointD = _pt(m.pointD!, size);

    final leftPin = pointC;
    final rightPin = pointD;
    final udder = pointB;
    final spine = pointA;

    final escutcheonPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Escutcheon box: pins define width at hip row; A/B on spine midline.
    final spineX = (pointC.dx + pointD.dx) / 2;
    final escutcheonRect = ui.Rect.fromLTRB(
      pointC.dx,
      pointA.dy,
      pointD.dx,
      pointB.dy,
    );
    canvas.drawRect(escutcheonRect, fillPaint);
    canvas.drawRect(escutcheonRect, escutcheonPaint);

    canvas.drawLine(Offset(spineX, pointA.dy), Offset(spineX, pointB.dy), escutcheonPaint);
    canvas.drawLine(pointC, pointD, escutcheonPaint);

    canvas.drawLine(spine, leftPin, linePaint);
    canvas.drawLine(spine, rightPin, linePaint);
    canvas.drawLine(leftPin, udder, linePaint);
    canvas.drawLine(rightPin, udder, linePaint);

    _drawMarker(canvas, pointA, 'A', const Color(0xFFFFD54F));
    _drawMarker(canvas, pointB, 'B', const Color(0xFFFFD54F));
    _drawMarker(canvas, pointC, 'C', const Color(0xFFFFD54F));
    _drawMarker(canvas, pointD, 'D', const Color(0xFFFFD54F));
    _drawMarker(canvas, leftPin, 'L Pin', Colors.redAccent);
    _drawMarker(canvas, rightPin, 'R Pin', Colors.redAccent);
    _drawMarker(canvas, udder, 'Udder', Colors.blueAccent);

    final measurementText =
        'H: ${(m.heightNorm * 100).toStringAsFixed(0)}%  W: ${(m.widthNorm * 100).toStringAsFixed(0)}%';
    final tp = TextPainter(
      text: TextSpan(
        text: measurementText,
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(escutcheonRect.left + 4, escutcheonRect.top + 4));
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
      old.metrics != metrics || old.fallbackKeypoints != fallbackKeypoints;
}
