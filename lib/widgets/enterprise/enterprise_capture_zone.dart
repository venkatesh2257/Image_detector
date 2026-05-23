import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'dairy_ai_showcase_carousel.dart';
import 'glass_card.dart';
import 'responsive_layout.dart';

/// AI camera / vision preview — responsive height & width on all screen sizes.
class EnterpriseCaptureZone extends StatelessWidget {
  final File? image;
  final Widget? overlay;
  final bool modelReady;

  const EnterpriseCaptureZone({
    super.key,
    this.image,
    this.overlay,
    required this.modelReady,
  });

  @override
  Widget build(BuildContext context) {
    final radius = ResponsiveLayout.captureRadius(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth;
        if (!parentW.isFinite || parentW <= 0) {
          return const SizedBox.shrink();
        }

        final maxW = ResponsiveLayout.captureMaxWidth(context, parentW);
        final maxH = ResponsiveLayout.captureMaxHeight(context);
        final aspect = ResponsiveLayout.captureAspectRatio(context);

        var width = maxW;
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }
        final minH = ResponsiveLayout.tier(context) == ScreenTier.compact
            ? 160.0
            : 220.0;
        height = math.max(height, minH);

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: width,
            height: height,
            child: GlassCard(
              padding: EdgeInsets.zero,
              radius: radius,
              glow: image != null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image == null)
                      DairyAiShowcaseCarousel(modelReady: modelReady)
                    else
                      Image.file(image!, fit: BoxFit.contain),
                    if (image != null && overlay != null) overlay!,
                    if (image == null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: ResponsiveLayout.tier(context) ==
                                    ScreenTier.compact
                                ? 0.78
                                : 0.52,
                            child: _captureHint(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _captureHint(BuildContext context) {
    final compact = ResponsiveLayout.tier(context) == ScreenTier.compact;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              modelReady ? Icons.sensors_rounded : Icons.hourglass_top_rounded,
              color: modelReady ? AppColors.success : AppColors.warning,
              size: compact ? 12 : 14,
            ),
            SizedBox(width: compact ? 4 : 5),
            Flexible(
              child: Text(
                modelReady ? 'AI ready · Camera / Gallery' : 'Loading AI…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: compact ? 9.5 : 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
