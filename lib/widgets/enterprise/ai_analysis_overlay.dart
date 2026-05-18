import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/dairy_pipeline_report.dart';
import '../../theme/app_theme.dart';

/// Full-screen AI scanning UI while inference runs.
class AiAnalysisOverlay extends StatelessWidget {
  final List<PipelineStep>? steps;
  final int activeStepIndex;

  const AiAnalysisOverlay({
    super.key,
    this.steps,
    this.activeStepIndex = 2,
  });

  @override
  Widget build(BuildContext context) {
    final displaySteps = steps ??
        const [
          PipelineStep(index: 1, title: 'Capture', subtitle: 'Image loaded', status: PipelineStepStatus.pass),
          PipelineStep(index: 2, title: 'Detect', subtitle: 'Animal scan', status: PipelineStepStatus.pass),
          PipelineStep(index: 3, title: 'Measure', subtitle: 'Escutcheon', status: PipelineStepStatus.partial),
          PipelineStep(index: 4, title: 'Predict', subtitle: 'TFLite', status: PipelineStepStatus.pending),
        ];

    return Material(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface.withValues(alpha: 0.98),
              AppColors.lavender.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                _scanRing(),
                const SizedBox(height: 28),
                Text(
                  'AI Analysis in progress',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Computer vision · Measurement · Prediction engine',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Expanded(child: _pipelineList(displaySteps)),
                _pulseBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scanRing() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.15, 1.15),
                duration: 1800.ms,
              )
              .then()
              .scale(
                begin: const Offset(1.15, 1.15),
                end: const Offset(0.9, 0.9),
                duration: 1800.ms,
              ),
          const Icon(Icons.hub_rounded, size: 48, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _pipelineList(List<PipelineStep> steps) {
    return ListView.separated(
      itemCount: steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final step = steps[i];
        final active = i == activeStepIndex;
        final done = i < activeStepIndex || step.status == PipelineStepStatus.pass;
        return _stepRow(step, active: active, done: done)
            .animate(delay: (i * 80).ms)
            .fadeIn(duration: 300.ms)
            .slideX(begin: 0.05, end: 0);
      },
    );
  }

  Widget _stepRow(PipelineStep step, {required bool active, required bool done}) {
    final color = done
        ? AppColors.success
        : active
            ? AppColors.primary
            : AppColors.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done
                  ? Icons.check_rounded
                  : active
                      ? Icons.auto_awesome
                      : Icons.circle_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (active)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
        ],
      ),
    );
  }

  Widget _pulseBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        minHeight: 4,
        backgroundColor: AppColors.border,
        color: AppColors.primary,
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1200.ms,
          color: AppColors.primary.withValues(alpha: 0.4),
        );
  }
}
