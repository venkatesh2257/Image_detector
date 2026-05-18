import 'dart:convert';

import 'package:flutter/services.dart';

/// Dataset-fitted coefficients from `training/calibrate_milk_mirror.py`.
class MilkMirrorCalibration {
  final double intercept;
  final double cArea;
  final double cFull;
  final double cSym;
  final double minLiters;
  final double maxLiters;

  const MilkMirrorCalibration({
    required this.intercept,
    required this.cArea,
    required this.cFull,
    required this.cSym,
    this.minLiters = 1.0,
    this.maxLiters = 30.0,
  });

  double predict({
    required double areaNorm,
    required double fullness,
    required double symmetryIndex,
  }) {
    final liters = intercept +
        cArea * areaNorm +
        cFull * fullness +
        cSym * symmetryIndex;
    return liters.clamp(minLiters, maxLiters);
  }

  static Future<MilkMirrorCalibration?> loadFromAssets() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/model/milk_mirror_calibration.json',
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MilkMirrorCalibration(
        intercept: (map['intercept'] as num).toDouble(),
        cArea: (map['c_area'] as num).toDouble(),
        cFull: (map['c_full'] as num).toDouble(),
        cSym: (map['c_sym'] as num).toDouble(),
        minLiters: (map['min_liters'] as num?)?.toDouble() ?? 1.0,
        maxLiters: (map['max_liters'] as num?)?.toDouble() ?? 30.0,
      );
    } catch (_) {
      return null;
    }
  }
}
