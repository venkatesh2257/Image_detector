import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'inference_logger.dart';
import 'rear_anatomy_detector.dart';

/// Normalized crop box (0–1) around udder + escutcheon for species/TFLite.
class EscutcheonCropBox {
  const EscutcheonCropBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  Rect toRect(double imageWidth, double imageHeight) => Rect.fromLTWH(
        left * imageWidth,
        top * imageHeight,
        width * imageWidth,
        height * imageHeight,
      );
}

/// Result of cropping to the milk-mirror region (mandatory pipeline step).
class UdderEscutcheonCrop {
  const UdderEscutcheonCrop({
    required this.sourcePath,
    required this.cropPath,
    required this.box,
    required this.anatomy,
    this.cropWidth = 0,
    this.cropHeight = 0,
  });

  final String sourcePath;
  final String cropPath;
  final EscutcheonCropBox box;
  final RearAnatomyLandmarks anatomy;
  final int cropWidth;
  final int cropHeight;

  bool get isValid => cropWidth >= 64 && cropHeight >= 64;
}

/// Builds a tight rear udder / escutcheon crop from anatomy landmarks.
class UdderEscutcheonCropService {
  static const double _minPaddingX = 0.06;
  static const double _minPaddingY = 0.08;

  /// Detect anatomy (if needed), expand bbox, write JPEG crop to temp dir.
  UdderEscutcheonCrop? buildCrop(
    String imagePath, {
    RearAnatomyLandmarks? anatomy,
  }) {
    final file = File(imagePath);
    if (!file.existsSync()) return null;

    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) return null;
    final image = img.bakeOrientation(decoded);
    final w = image.width;
    final h = image.height;

    final landmarks =
        anatomy ?? RearAnatomyDetector().detect(image);
    if (landmarks == null) {
      InferenceLogger.log('CROP', 'No anatomy — using central rear fallback box');
      return _fallbackCrop(image, imagePath, w, h);
    }

    final xs = [
      landmarks.leftPin.dx,
      landmarks.rightPin.dx,
      landmarks.udder.dx,
      landmarks.pointA.dx,
      landmarks.pointC.dx,
      landmarks.pointD.dx,
    ];
    final ys = [
      landmarks.leftPin.dy,
      landmarks.rightPin.dy,
      landmarks.udder.dy,
      landmarks.pointA.dy,
      landmarks.pointB.dy,
    ];

    var minX = xs.reduce(math.min) - _minPaddingX;
    var maxX = xs.reduce(math.max) + _minPaddingX;
    var minY = ys.reduce(math.min) - _minPaddingY;
    var maxY = ys.reduce(math.max) + _minPaddingY;

    final spreadX = (maxX - minX).clamp(0.18, 0.92);
    final spreadY = (maxY - minY).clamp(0.22, 0.85);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    minX = (cx - spreadX / 2).clamp(0.0, 1.0);
    maxX = (cx + spreadX / 2).clamp(0.0, 1.0);
    minY = (cy - spreadY / 2).clamp(0.0, 1.0);
    maxY = (cy + spreadY / 2).clamp(0.0, 1.0);

    final box = EscutcheonCropBox(
      left: minX,
      top: minY,
      width: (maxX - minX).clamp(0.15, 1.0),
      height: (maxY - minY).clamp(0.15, 1.0),
    );

    return _writeCrop(image, imagePath, w, h, box, landmarks);
  }

  UdderEscutcheonCrop? _fallbackCrop(
    img.Image image,
    String imagePath,
    int w,
    int h,
  ) {
    const box = EscutcheonCropBox(
      left: 0.12,
      top: 0.22,
      width: 0.76,
      height: 0.58,
    );
    final anatomy = RearAnatomyLandmarks(
      pointA: const Offset(0.5, 0.28),
      pointB: const Offset(0.5, 0.62),
      pointC: const Offset(0.28, 0.48),
      pointD: const Offset(0.72, 0.48),
      leftPin: const Offset(0.28, 0.48),
      rightPin: const Offset(0.72, 0.48),
      udder: const Offset(0.5, 0.62),
      confidence: 0.35,
      isTemplateFallback: true,
    );
    return _writeCrop(image, imagePath, w, h, box, anatomy);
  }

  UdderEscutcheonCrop? _writeCrop(
    img.Image image,
    String imagePath,
    int w,
    int h,
    EscutcheonCropBox box,
    RearAnatomyLandmarks anatomy,
  ) {
    final rect = box.toRect(w.toDouble(), h.toDouble());
    final x0 = rect.left.round().clamp(0, w - 1);
    final y0 = rect.top.round().clamp(0, h - 1);
    final x1 = (rect.right).round().clamp(x0 + 1, w);
    final y1 = (rect.bottom).round().clamp(y0 + 1, h);

    final cropped = img.copyCrop(
      image,
      x: x0,
      y: y0,
      width: x1 - x0,
      height: y1 - y0,
    );

    final dir = Directory.systemTemp.createTempSync('milk_mirror_crop_');
    final fileName = imagePath.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    var base = dot > 0 ? fileName.substring(0, dot) : fileName;
    base = base.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    if (base.isEmpty) base = 'capture';
    final cropPath = '${dir.path}${Platform.pathSeparator}${base}_escutcheon.jpg';
    File(cropPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 88));

    InferenceLogger.log(
      'CROP',
      'Escutcheon crop ${cropped.width}x${cropped.height} → $cropPath '
      'box=(${box.left.toStringAsFixed(2)},${box.top.toStringAsFixed(2)} '
      '${box.width.toStringAsFixed(2)}x${box.height.toStringAsFixed(2)})',
    );

    return UdderEscutcheonCrop(
      sourcePath: imagePath,
      cropPath: cropPath,
      box: box,
      anatomy: anatomy,
      cropWidth: cropped.width,
      cropHeight: cropped.height,
    );
  }
}
