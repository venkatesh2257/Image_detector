/// Feature flags and thresholds for research-grade udder trait extraction.
abstract final class ScientificUdderConfig {
  /// When false, [ScientificUdderPipeline] is skipped; legacy path only.
  static const bool enabled = true;

  /// Blend trait-regression liters with legacy fusion when global confidence ≥
  /// this value.
  static const double minConfidenceToBlendLiters = 0.52;

  static const double blendWeightTraits = 0.42;
  static const double blendWeightLegacy = 0.58;

  /// Pose limits (radians).
  static const double maxYawRad = 0.35;
  static const double maxPitchProxy = 0.45;
  static const double maxRollRad = 0.28;

  /// Typical pin spread in cm for Murrah rear (calibration anchor).
  static const double referencePinSpreadCm = 48.0;

  /// Expected normalized pin spread in rectified rear view.
  static const double referencePinSpreadNorm = 0.32;

  /// Trait regression (MLR-inspired; recalibrate with field data).
  static const double regressionIntercept = 8.2;
  static const double coeffRuhNorm = -4.5;
  static const double coeffRuwNorm = 12.0;
  static const double coeffRtdNorm = 3.2;
  static const double coeffSymmetry = 2.0;
  static const double coeffDepthProxy = 1.8;
  static const double coeffLactation = 1.1;
  static const double coeffDim = 0.015;

  static const double minGlobalConfidence = 0.38;
  static const double minTraitConfidence = 0.25;

  /// Rectified processing size (mobile-friendly).
  static const int rectifyWidth = 320;
  static const int rectifyHeight = 400;
}
