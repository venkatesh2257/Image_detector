import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/dairy_pipeline_report.dart';
import '../../services/milk_production_scale.dart';
import '../../theme/app_theme.dart';
import 'glass_card.dart';

/// Premium light enterprise results dashboard (infographic → interactive UI).
class EnterpriseAiDashboard extends StatelessWidget {
  final DairyPipelineReport report;
  final String? sessionId;

  const EnterpriseAiDashboard({
    super.key,
    required this.report,
    this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _alertBanner(),
        const SizedBox(height: 16),
        _yieldHero(),
        const SizedBox(height: 16),
        _metricsRow(),
        const SizedBox(height: 16),
        _workflowSection(),
        const SizedBox(height: 16),
        _detectionGrid(),
        const SizedBox(height: 16),
        _productionEstimateCard(),
        if (report.recommendation != null) ...[
          const SizedBox(height: 16),
          _insightCard(),
        ],
      ],
    );
  }

  Widget _alertBanner() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      glow: report.alert == DairyAlert.success,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: report.alertColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(report.alertIcon, color: report.alertColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _alertTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  report.alertMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _alertTitle() => switch (report.alert) {
        DairyAlert.success => 'Analysis successful',
        DairyAlert.caution => 'Review recommended',
        DairyAlert.blocked => 'Prediction blocked',
        DairyAlert.info => 'AI insight',
      };

  Widget _yieldHero() {
    final pct = report.yieldConfidence.clamp(0.0, 1.0);
    return GlassCard(glow: true, animateDelayMs: 80, child: Row(
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: CustomPaint(
            painter: _ConfidenceRingPainter(pct),
            child: Center(
              child: Text(
                '${(pct * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DAILY MILK PRODUCTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                MilkProductionScale.formatExact(report.yieldLiters),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.05,
                ),
              ),
              Text(
                'Range ${MilkProductionScale.minLiters.toStringAsFixed(0)}–'
                '${MilkProductionScale.maxLiters.toStringAsFixed(0)} L · '
                '${report.yieldRange}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _metricsRow() {
    return Row(
      children: [
        Expanded(
          child: _miniMetric('Species', report.species, Icons.pets_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniMetric('Lactation', report.lactationState, Icons.water_drop_outlined),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniMetric('Health', report.healthStatus, Icons.favorite_border_rounded),
        ),
      ],
    ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.03, end: 0);
  }

  Widget _miniMetric(String label, String value, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workflowSection() {
    return GlassCard(
      animateDelayMs: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Pipeline',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...report.workflowSteps.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < report.workflowSteps.length - 1 ? 12 : 0),
              child: _pipelineStep(step, isLast: i == report.workflowSteps.length - 1),
            );
          }),
        ],
      ),
    );
  }

  Widget _pipelineStep(PipelineStep step, {required bool isLast}) {
    final color = switch (step.status) {
      PipelineStepStatus.pass => AppColors.success,
      PipelineStepStatus.fail => AppColors.danger,
      PipelineStepStatus.partial => AppColors.warning,
      PipelineStepStatus.pending => AppColors.border,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(
                step.status == PipelineStepStatus.pass ? Icons.check : Icons.more_horiz,
                size: 16,
                color: color,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.index}. ${step.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  step.subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detectionGrid() {
    return GlassCard(
      animateDelayMs: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detection panel',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 14),
          _detectRow('Sex classification', report.sex, '${(report.sexConfidence * 100).round()}%'),
          _detectRow('Lactation stage', report.lactationStage, 'DIM'),
          _detectRow(
            'Species confidence',
            report.species,
            '${(report.speciesConfidence * 100).round()}%',
          ),
        ],
      ),
    );
  }

  Widget _detectRow(String label, String value, String badge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productionEstimateCard() {
    final liters = MilkProductionScale.clamp(report.yieldLiters);
    final conf = report.yieldConfidence.clamp(0.0, 1.0);

    return GlassCard(
      animateDelayMs: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Production estimate',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                liters.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 8),
                child: Text(
                  'L / day',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(conf * 100).round()}% confidence',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Identified from escutcheon measurement and on-device AI '
            '(${MilkProductionScale.minLiters.toStringAsFixed(0)}–'
            '${MilkProductionScale.maxLiters.toStringAsFixed(0)} L scale).',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (sessionId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Session $sessionId',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.info, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              report.recommendation!,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 280.ms);
  }
}

class _ConfidenceRingPainter extends CustomPainter {
  final double progress;

  _ConfidenceRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfidenceRingPainter old) => old.progress != progress;
}
