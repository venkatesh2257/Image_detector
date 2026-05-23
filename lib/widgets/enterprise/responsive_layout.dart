import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Breakpoints for Milk Mirror responsive UI (mobile / tablet / desktop).
enum ScreenTier { compact, medium, expanded, wide }

abstract final class ResponsiveLayout {
  static const compactMax = 600.0;
  static const mediumMax = 900.0;
  static const expandedMax = 1200.0;

  static ScreenTier tierOf(double width) {
    if (width < compactMax) return ScreenTier.compact;
    if (width < mediumMax) return ScreenTier.medium;
    if (width < expandedMax) return ScreenTier.expanded;
    return ScreenTier.wide;
  }

  static ScreenTier tier(BuildContext context) =>
      tierOf(MediaQuery.sizeOf(context).width);

  /// Max width for scrollable content column.
  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return switch (tierOf(w)) {
      ScreenTier.compact => w,
      ScreenTier.medium => 720,
      ScreenTier.expanded => 840,
      ScreenTier.wide => 960,
    };
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return switch (tier(context)) {
      ScreenTier.compact => const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ScreenTier.medium => const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ScreenTier.expanded => const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      ScreenTier.wide => const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
    };
  }

  /// Capture preview max height — keeps dashboard visible on all screens.
  static double captureMaxHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final h = size.height;
    final padding = MediaQuery.paddingOf(context);
    final usable = h - padding.top - padding.bottom;

    return switch (tier(context)) {
      ScreenTier.compact => math.min(usable * 0.36, 300),
      ScreenTier.medium => math.min(usable * 0.40, 360),
      ScreenTier.expanded => math.min(usable * 0.44, 400),
      ScreenTier.wide => math.min(usable * 0.44, 400),
    };
  }

  /// Capture preview max width (centered on large screens).
  static double captureMaxWidth(BuildContext context, double parentWidth) {
    final tier = ResponsiveLayout.tier(context);
    return switch (tier) {
      ScreenTier.compact => parentWidth,
      ScreenTier.medium => math.min(parentWidth, 560.0),
      ScreenTier.expanded => math.min(parentWidth, 620.0),
      ScreenTier.wide => math.min(parentWidth, 620.0),
    };
  }

  /// White carousel card height (phone → desktop).
  static double showcaseCardHeight(BuildContext context) {
    return switch (tier(context)) {
      ScreenTier.compact => 180,
      ScreenTier.medium => 192,
      ScreenTier.expanded => 208,
      ScreenTier.wide => 212,
    };
  }

  /// PageView slide width fraction (lower = wider cards on desktop).
  static double showcaseViewportFraction(BuildContext context) {
    return switch (tier(context)) {
      ScreenTier.compact => 0.62,
      ScreenTier.medium => 0.56,
      ScreenTier.expanded => 0.50,
      ScreenTier.wide => 0.48,
    };
  }

  /// Preferred aspect ratio for rear-udder frame (slightly wider = less vertical space).
  static double captureAspectRatio(BuildContext context) {
    return switch (tier(context)) {
      ScreenTier.compact => 1.15, // ~11:9.5
      ScreenTier.medium => 1.25,
      _ => 1.35,
    };
  }

  static double captureRadius(BuildContext context) {
    return switch (tier(context)) {
      ScreenTier.compact => 20,
      ScreenTier.medium => 24,
      _ => 28,
    };
  }
}
