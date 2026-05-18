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

  late final PageController _pageController;
  late final AnimationController _scanController;
  Timer? _autoTimer;
  int _logicalIndex = 0;

  @override
  void initState() {
    super.initState();
    final start = _items.length * _loopMultiplier;
    _pageController = PageController(
      viewportFraction: 0.62,
      initialPage: start,
    );
    _logicalIndex = 0;
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_pageController.page ?? 0).round() + 1;
      _pageController.animateToPage(
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
    _pageController.dispose();
    super.dispose();
  }

  int _indexFromPage(int page) => page % _items.length;

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveLayout.tier(context) == ScreenTier.compact;
    final cardH = compact ? 148.0 : 168.0;

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
                  controller: _pageController,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
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
                        final base = (_pageController.page ?? 0).round();
                        final aligned = base - _indexFromPage(base) + i;
                        _pageController.animateToPage(
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.92),
              AppColors.primarySoft.withValues(alpha: 0.45),
            ],
          ),
          border: Border.all(
            width: isActive ? 2 : 1,
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.65)
                : AppColors.border,
          ),
          boxShadow: isActive
              ? const [AppColors.aiGlow]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Center(
                child: SvgPicture.string(
                  item.svg,
                  width: 96,
                  height: 96,
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: isActive ? -4 : -2,
                      end: isActive ? 4 : 2,
                      duration: isActive ? 2.2.seconds : 2.8.seconds,
                      curve: Curves.easeInOut,
                    ),
              ),
            ],
          ),
        ),
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
