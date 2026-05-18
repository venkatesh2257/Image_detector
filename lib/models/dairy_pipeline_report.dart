import 'package:flutter/material.dart';

enum DairyAlert { success, caution, blocked, info }

enum PipelineStepStatus { pending, pass, fail, partial }

class PipelineStep {
  final int index;
  final String title;
  final String subtitle;
  final PipelineStepStatus status;

  const PipelineStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.status,
  });
}

/// Full Milk Mirror pipeline snapshot for UI (matches infographic sections).
class DairyPipelineReport {
  final List<PipelineStep> workflowSteps;
  final String species;
  final double speciesConfidence;
  final String sex;
  final double sexConfidence;
  final String lactationState;
  final String healthStatus;
  final String lactationStage;
  final String yieldRange;
  final double yieldLiters;
  final double yieldConfidence;
  final DairyAlert alert;
  final String alertMessage;
  final String? recommendation;

  const DairyPipelineReport({
    required this.workflowSteps,
    required this.species,
    required this.speciesConfidence,
    required this.sex,
    required this.sexConfidence,
    required this.lactationState,
    required this.healthStatus,
    required this.lactationStage,
    required this.yieldRange,
    required this.yieldLiters,
    required this.yieldConfidence,
    required this.alert,
    required this.alertMessage,
    this.recommendation,
  });

  Color get alertColor => switch (alert) {
        DairyAlert.success => const Color(0xFF10B981),
        DairyAlert.caution => const Color(0xFFF59E0B),
        DairyAlert.blocked => const Color(0xFFEF4444),
        DairyAlert.info => const Color(0xFF3B82F6),
      };

  IconData get alertIcon => switch (alert) {
        DairyAlert.success => Icons.check_circle_rounded,
        DairyAlert.caution => Icons.warning_amber_rounded,
        DairyAlert.blocked => Icons.block_rounded,
        DairyAlert.info => Icons.lightbulb_rounded,
      };

  DairyPipelineReport copyWith({
    String? healthStatus,
    List<PipelineStep>? workflowSteps,
  }) {
    return DairyPipelineReport(
      workflowSteps: workflowSteps ?? this.workflowSteps,
      species: species,
      speciesConfidence: speciesConfidence,
      sex: sex,
      sexConfidence: sexConfidence,
      lactationState: lactationState,
      healthStatus: healthStatus ?? this.healthStatus,
      lactationStage: lactationStage,
      yieldRange: yieldRange,
      yieldLiters: yieldLiters,
      yieldConfidence: yieldConfidence,
      alert: alert,
      alertMessage: alertMessage,
      recommendation: recommendation,
    );
  }
}
