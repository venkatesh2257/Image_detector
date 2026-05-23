import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../theme/app_theme.dart';
import 'dairy_showcase_svgs.dart';
import 'responsive_layout.dart';

/// Premium horizontal AI dairy showcase for the empty capture zone.
class DairyAiShowcaseCarousel extends StatefulWidget {
  final bool modelReady;

  const DairyAiShowcaseCarousel({super.key, required this.modelReady});

  @override
  State<DairyAiShowcaseCarousel> createState() => _DairyAiShowcaseCarouselState();
}

class _DairyAiShowcaseCarouselState extends State<DairyAiShowcaseCarousel>
    with SingleTickerProviderStateMixin {
  static const _items = DairyShowcaseItem.all;
  static const _loopMultiplier = 400;

  PageController? _pageController;
  double? _pageViewportFraction;
  late final AnimationController _scanController;
  Timer? _autoTimer;
  int _logicalIndex = 0;

  PageController _ensurePageController(BuildContext context) {
    final vf = ResponsiveLayout.showcaseViewportFraction(context);
    if (_pageController == null || _pageViewportFraction != vf) {
      final start = _items.length * _loopMultiplier;
      final old = _pageController;
      _pageViewportFraction = vf;
      _pageController = PageController(
        viewportFraction: vf,
        initialPage: start,
      );
      old?.dispose();
    }
    return _pageController!;
  }

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      final pc = _pageController;
      if (!mounted || pc == null || !pc.hasClients) return;
      final next = (pc.page ?? 0).round() + 1;
      pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _scanController.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  int _indexFromPage(int page) => page % _items.length;

  @override
  Widget build(BuildContext context) {
    final pageController = _ensurePageController(context);
    final tier = ResponsiveLayout.tier(context);
    final compact = tier == ScreenTier.compact;
    final cardH = ResponsiveLayout.showcaseCardHeight(context);
    final captionGap = compact ? 14.0 : 18.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.lavender],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ambientGlow(),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (context, _) => CustomPaint(
                painter: _AiScanLinePainter(progress: _scanController.value),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, compact ? 12 : 14, 8, 0),
                child: Row(
                  children: [
                    _pill(
                      widget.modelReady ? 'AI ONLINE' : 'BOOTING AI',
                      widget.modelReady ? AppColors.success : AppColors.warning,
                    ),
                    const Spacer(),
                    _pill('MILK MIRROR', AppColors.primary),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  onPageChanged: (page) {
                    setState(() => _logicalIndex = _indexFromPage(page));
                  },
                  itemBuilder: (context, page) {
                    final index = _indexFromPage(page);
                    final item = _items[index];
                    final isActive = index == _logicalIndex;
                    return AnimatedScale(
                      scale: isActive ? 1.0 : 0.88,
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: isActive ? 1.0 : 0.55,
                        duration: const Duration(milliseconds: 350),
                        child: _ShowcaseCard(
                          item: item,
                          height: cardH,
                          isActive: isActive,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: captionGap),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, compact ? 28 : 32),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _items[_logicalIndex].title,
                        key: ValueKey(_logicalIndex),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 14 : 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _items[_logicalIndex].subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSmoothIndicator(
                      activeIndex: _logicalIndex,
                      count: _items.length,
                      effect: ExpandingDotsEffect(
                        activeDotColor: AppColors.primary,
                        dotColor: AppColors.primary.withValues(alpha: 0.22),
                        dotHeight: 6,
                        dotWidth: 6,
                        expansionFactor: 3.2,
                        spacing: 6,
                      ),
                      onDotClicked: (i) {
                        final base = (pageController.page ?? 0).round();
                        final aligned = base - _indexFromPage(base) + i;
                        pageController.animateToPage(
                          aligned,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ambientGlow() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1.08, 1.08),
              duration: 3.seconds,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }

  static Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  final DairyShowcaseItem item;
  final double height;
  final bool isActive;

  const _ShowcaseCard({
    required this.item,
    required this.height,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SizedBox(
        height: height,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isActive ? 0.98 : 0.88),
                AppColors.primarySoft.withValues(alpha: isActive ? 0.35 : 0.18),
              ],
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
              builder: (context, constraints) {
                final pad = ShowcaseSize.iconPaddingSides;
                final top = ShowcaseSize.iconPaddingTop;
                final bottom = ShowcaseSize.iconPaddingBottom;
                final artW = constraints.maxWidth - pad * 2;
                final artH = constraints.maxHeight - top - bottom;

                return Padding(
                  padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
                  child: _ShowcaseSvg(
                    item: item,
                    width: artW,
                    height: artH,
                  ),
                );
              },
            ),
        ),
      ),
    );
  }

}

class _ShowcaseSvg extends StatelessWidget {
  final DairyShowcaseItem item;
  final double width;
  final double height;

  const _ShowcaseSvg({
    required this.item,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final Widget graphic = item.svgAsset != null
        ? SvgPicture.asset(
            item.svgAsset!,
            semanticsLabel: item.title,
          )
        : SvgPicture.string(item.svg!);

    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: graphic,
      ),
    );
  }
}

class _AiScanLinePainter extends CustomPainter {
  final double progress;

  _AiScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 24, size.width, 48))
      ..strokeWidth = 2;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    final glow = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRect(Rect.fromLTWH(0, y - 20, size.width, 40), glow);
  }

  @override
  bool shouldRepaint(covariant _AiScanLinePainter old) => old.progress != progress;
}
