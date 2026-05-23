import 'dart:io';

import 'package:image/image.dart' as img;

import 'inference_logger.dart';
import 'rear_anatomy_detector.dart';
import 'udder_escutcheon_crop_service.dart';

/// Species decision on escutcheon crop only (Phase A — heuristic v1).
class CropSpeciesResult {
  const CropSpeciesResult({
    required this.isBuffalo,
    required this.confidence,
    required this.reason,
    this.escutcheonAspect = 0,
    this.organicRatio = 0,
  });

  final bool isBuffalo;
  final double confidence;
  final String reason;
  final double escutcheonAspect;
  final double organicRatio;
}

/// Buffalo vs non-buffalo using crop geometry + hide (no full-frame background).
class CropSpeciesGateService {
  static const double _minBuffaloConfidence = 0.72;

  CropSpeciesResult analyze({
    required String cropPath,
    required RearAnatomyLandmarks anatomy,
  }) {
    final file = File(cropPath);
    if (!file.existsSync()) {
      return const CropSpeciesResult(
        isBuffalo: false,
        confidence: 0,
        reason: 'Crop missing',
      );
    }

    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      return const CropSpeciesResult(
        isBuffalo: false,
        confidence: 0,
        reason: 'Crop decode failed',
      );
    }

    final image = img.bakeOrientation(decoded);
    final organic = _organicRatio(image);
    final aspect = _escutcheonAspect(anatomy);
    final hideScore = _darkHideScore(image);

    var score = 0.35;
    if (organic >= 0.18) score += 0.22;
    if (organic >= 0.28) score += 0.10;
    if (aspect >= 1.15 && aspect <= 2.8) score += 0.18;
    if (hideScore >= 0.12) score += 0.12;
    if (anatomy.confidence >= 0.55) score += 0.12;
    if (anatomy.isTemplateFallback) score -= 0.25;

    // Cow-like: very narrow escutcheon in crop
    if (aspect < 0.95) score -= 0.35;
    if (organic < 0.10) score -= 0.30;

    score = score.clamp(0.0, 1.0);
    final isBuffalo = score >= _minBuffaloConfidence;

    InferenceLogger.log(
      'SPECIES_CROP',
      'buffalo=$isBuffalo conf=${(score * 100).toStringAsFixed(0)}% '
      'organic=${(organic * 100).toStringAsFixed(0)}% aspect=${aspect.toStringAsFixed(2)}',
    );

    return CropSpeciesResult(
      isBuffalo: isBuffalo,
      confidence: score,
      reason: isBuffalo
          ? 'Rear escutcheon matches buffalo milk mirror'
          : 'Crop does not match buffalo rear (possible cow/goat/other)',
      escutcheonAspect: aspect,
      organicRatio: organic,
    );
  }

  CropSpeciesResult analyzeFromFullImage(String imagePath) {
    final cropSvc = UdderEscutcheonCropService();
    final crop = cropSvc.buildCrop(imagePath);
    if (crop == null || !crop.isValid) {
      return const CropSpeciesResult(
        isBuffalo: false,
        confidence: 0,
        reason: 'Could not build escutcheon crop',
      );
    }
    return analyze(cropPath: crop.cropPath, anatomy: crop.anatomy);
  }

  double _escutcheonAspect(RearAnatomyLandmarks a) {
    final w = (a.rightPin.dx - a.leftPin.dx).abs().clamp(0.05, 0.95);
    final h = (a.udder.dy - a.pointA.dy).abs().clamp(0.08, 0.9);
    return w / h;
  }

  double _organicRatio(img.Image image) {
    final w = image.width;
    final h = image.height;
    var organic = 0;
    var n = 0;
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < w; x += 2) {
        n++;
        if (_isHideOrMud(image.getPixel(x, y))) organic++;
      }
    }
    return n == 0 ? 0 : organic / n;
  }

  double _darkHideScore(img.Image image) {
    final w = image.width;
    final h = image.height;
    var dark = 0;
    var n = 0;
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < w; x += 2) {
        n++;
        final p = image.getPixel(x, y);
        final br = (p.r + p.g + p.b) / 3;
        if (br < 70 && br > 12) dark++;
      }
    }
    return n == 0 ? 0 : dark / n;
  }

  bool _isHideOrMud(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    if (g > r + 14 && g > b + 10 && br > 45) return true;
    if (br < 75 && br > 15 && r >= g - 12) return true;
    return false;
  }
}
