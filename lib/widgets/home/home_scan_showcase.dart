import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/model_status_store.dart';
import '../../theme/app_theme.dart';
import '../enterprise/dairy_showcase_svgs.dart';

/// Simplified rear-view scan showcase for the Home dashboard.
class HomeScanShowcase extends StatefulWidget {
  const HomeScanShowcase({super.key});

  @override
  State<HomeScanShowcase> createState() => _HomeScanShowcaseState();
}

class _HomeScanShowcaseState extends State<HomeScanShowcase>
    with SingleTickerProviderStateMixin {
  static const _items = [
    DairyShowcaseItem(
      title: 'Buffalo rear',
      subtitle: 'Rear escutcheon',
      svgAsset: DairyShowcaseAssets.buffaloRear,
    ),
    DairyShowcaseItem(
      title: 'Cow rear',
      subtitle: 'Herd comparison',
      svgAsset: DairyShowcaseAssets.cowRear,
    ),
    DairyShowcaseItem(
      title: 'Milking',
      subtitle: 'Yield context',
      svgAsset: DairyShowcaseAssets.milking,
    ),
  ];

  late final PageController _pageController;
  late final AnimationController _scanController;
  Timer? _autoTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients) return;
      final next = (_index + 1) % _items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ModelStatusStore.instance,
      builder: (context, _) {
        final ready = ModelStatusStore.instance.isReady;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Scan Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rear udder views analyzed by పాల Predictor',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primarySoft.withValues(alpha: 0.35),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, _) => CustomPaint(
                        painter: _EnhancedScanPainter(
                          progress: _scanController.value,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Row(
                            children: [
                              _statusPill(
                                ready ? 'AI ONLINE' : 'LOADING',
                                ready ? AppColors.success : AppColors.warning,
                              ),
                              const Spacer(),
                              _statusPill('పాల PREDICTOR', AppColors.primary),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _items.length,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              final active = i == _index;
                              return AnimatedScale(
                                scale: active ? 1.0 : 0.9,
                                duration: const Duration(milliseconds: 350),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: _SlideCard(item: item, active: active),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Column(
                            children: [
                              Text(
                                _items[_index].title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _items[_index].subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_items.length, (i) {
                                  final active = i == _index;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: active ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? AppColors.primary
                                          : AppColors.primary.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusPill(String text, Color color) {
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
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.item, required this.active});
  final DairyShowcaseItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 0.95 : 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: item.svgAsset != null
          ? SvgPicture.asset(item.svgAsset!, fit: BoxFit.contain)
          : const SizedBox.shrink(),
    );
  }
}

class _EnhancedScanPainter extends CustomPainter {
  _EnhancedScanPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.accentGold.withValues(alpha: 0.5),
          AppColors.primary.withValues(alpha: 0.65),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 28, size.width, 56));

    canvas.drawLine(Offset(0, y), Offset(size.width, y), beam);

    final glow = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRect(Rect.fromLTWH(0, y - 24, size.width, 48), glow);

    final pulse = progress * math.pi * 2;
    final cx = size.width * 0.5;
    final cy = size.height * 0.45;
    final radius = 36 + 6 * math.sin(pulse);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.primary.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(cx, cy), radius, ring);

    final corner = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const len = 18.0;
    const inset = 12.0;
    canvas.drawLine(Offset(inset, inset), Offset(inset + len, inset), corner);
    canvas.drawLine(Offset(inset, inset), Offset(inset, inset + len), corner);
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset - len, inset),
      corner,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + len),
      corner,
    );
  }

  @override
  bool shouldRepaint(covariant _EnhancedScanPainter old) => old.progress != progress;
}
