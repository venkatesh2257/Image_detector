/// Milk production display range (liters per day).
class MilkProductionScale {
  static const double minLiters = 1.0;
  static const double maxLiters = 30.0;

  static double clamp(double liters) =>
      liters.clamp(minLiters, maxLiters).toDouble();

  /// Single exact figure for UI (e.g. `12.4 L/day`).
  static String formatExact(double liters) =>
      '${clamp(liters).toStringAsFixed(1)} L/day';

  /// Narrow band around the estimate (±0.6 L, within 1–30).
  static String formatBand(double liters) {
    final c = clamp(liters);
    final lo = clamp(c - 0.6);
    final hi = clamp(c + 0.6);
    if ((hi - lo).abs() < 0.15) return formatExact(c);
    return '${lo.toStringAsFixed(1)} – ${hi.toStringAsFixed(1)} L/day';
  }
}
