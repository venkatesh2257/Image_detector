/// Results from the multi-stage on-device AI validation pipeline.
enum PipelineStage {
  quality,
  animal,
  angle,
  rearUdder,
  milkPrediction,
}

class StageValidationResult {
  const StageValidationResult({
    required this.stage,
    required this.passed,
    required this.score,
    this.issues = const [],
    this.detail = '',
    this.durationMs = 0,
  });

  final PipelineStage stage;
  final bool passed;
  final double score;
  final List<String> issues;
  final String detail;
  final int durationMs;

  Map<String, dynamic> toFirestore() => {
        'stage': stage.name,
        'passed': passed,
        'score': score,
        'issues': issues,
        if (detail.isNotEmpty) 'detail': detail,
        'durationMs': durationMs,
      };
}

class AiPipelineReport {
  const AiPipelineReport({
    required this.stages,
    required this.overallPassed,
    required this.overallScore,
    this.failedStage,
    this.rejectReason,
    this.inferenceImagePath,
    this.cropPath,
  });

  final List<StageValidationResult> stages;
  final bool overallPassed;
  final double overallScore;
  final PipelineStage? failedStage;
  final String? rejectReason;
  /// Path used for TFLite / Milk Mirror (may be escutcheon crop).
  final String? inferenceImagePath;
  final String? cropPath;

  StageValidationResult? stageResult(PipelineStage s) {
    for (final r in stages) {
      if (r.stage == s) return r;
    }
    return null;
  }

  Map<String, dynamic> toFirestore() => {
        'pipelinePassed': overallPassed,
        'pipelineScore': overallScore,
        if (failedStage != null) 'pipelineFailedStage': failedStage!.name,
        if (rejectReason != null) 'pipelineRejectReason': rejectReason,
        'pipelineStages': stages.map((s) => s.toFirestore()).toList(),
        if (cropPath != null) 'escutcheonCropPath': cropPath,
      };
}
