import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/milk_mirror_measurement_service.dart';
import 'anatomy_overlay_painter.dart';

/// Positions anatomy overlay exactly on [BoxFit.contain] image bounds.
class AnatomyOverlayLayer extends StatelessWidget {
  final File imageFile;
  final MilkMirrorUiMetrics? metrics;
  final List<Offset> fallbackKeypoints;

  const AnatomyOverlayLayer({
    super.key,
    required this.imageFile,
    this.metrics,
    this.fallbackKeypoints = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Size>(
          future: _decodeSize(imageFile),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final fit = _containFit(snap.data!, constraints.biggest);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: fit.offset.dx,
                  top: fit.offset.dy,
                  width: fit.size.width,
                  height: fit.size.height,
                  child: CustomPaint(
                    painter: AnatomyOverlayPainter(
                      metrics: metrics,
                      fallbackKeypoints: fallbackKeypoints,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Size> _decodeSize(File file) async {
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) return const Size(1, 1);
    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  }

  _Fit _containFit(Size image, Size box) {
    final ia = image.width / image.height;
    final ca = box.width / box.height;
    if (ia > ca) {
      final w = box.width;
      final h = w / ia;
      return _Fit(Size(w, h), Offset(0, (box.height - h) / 2));
    }
    final h = box.height;
    final w = h * ia;
    return _Fit(Size(w, h), Offset((box.width - w) / 2, 0));
  }
}

class _Fit {
  final Size size;
  final Offset offset;
  const _Fit(this.size, this.offset);
}
