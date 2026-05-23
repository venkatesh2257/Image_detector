import '../models/dairy_pipeline_report.dart';
import 'classifier_service_new.dart';
import 'milk_mirror_measurement_service.dart';
import 'milk_production_scale.dart';
import 'yield_fusion_service.dart';

/// Builds infographic-style pipeline report from existing analyzers.
class DairyPipelineBuilder {
  DairyPipelineReport build({
    required BuffaloAnalysisResult? gate,
    required MilkMirrorResult? mirror,
    required String predictionSource,
    required double displayConfidence,
    required String displayLabel,
    required double estimatedLiters,
    required String? tfliteBand,
    int daysInMilk = 30,
    double? yieldMin,
    double? yieldMax,
    YieldPredictionStatus? fusionStatus,
  }) {
    final gateOk = gate?.status == 'valid';
    final mirrorOk = mirror?.success == true;

    final buffaloProb = (gate?.features?['buffalo_prob'] as num?)?.toDouble() ?? 0.85;
    final species = gateOk ? 'Buffalo' : 'Unknown';
    final speciesConf = gateOk ? buffaloProb.clamp(0.0, 1.0) : 0.0;

    final sexLabel = gate?.features?['sex'] as String? ?? 'Uncertain';
    final sexConf = (gate?.features?['sex_confidence'] as num?)?.toDouble() ?? 0.45;
    final sexDetail = gate?.features?['sex_detail'] as String? ?? '';
    final isBull = gate?.features?['sex_is_bull'] == true;
    final sexSubtitle =
        sexDetail.isNotEmpty ? '$sexLabel — $sexDetail' : sexLabel;

    final udderVisible = (gate?.keypoints.length ?? 0) >= 3;
    final lactationState = udderVisible ? 'Lactating' : 'Dry / not visible';

    final symmetry = mirror?.symmetryIndex ?? 0.5;
    final quality = mirror?.textureScore ?? 0.5;
    String healthStatus = 'Normal';
    if (symmetry > 0.45) healthStatus = 'Check asymmetry';
    if (quality < 0.25) healthStatus = 'Poor image quality';

    String stage;
    if (daysInMilk < 100) {
      stage = 'Early (0–100 DIM)';
    } else if (daysInMilk < 200) {
      stage = 'Mid (100–200 DIM)';
    } else {
      stage = 'Late (>200 DIM)';
    }

    DairyAlert alert;
    String alertMessage;
    String? tip;

    if (!gateOk) {
      alert = DairyAlert.blocked;
      alertMessage = gate?.reason ?? 'Prediction blocked — fix photo or animal';
    } else if (isBull && sexConf >= 0.55) {
      alert = DairyAlert.blocked;
      alertMessage = 'Male buffalo detected — milk yield prediction is for lactating females only';
      tip = 'Use a rear photo of a lactating female with visible udder.';
    } else if (!mirrorOk) {
      alert = DairyAlert.caution;
      alertMessage = mirror?.error ?? 'Could not measure escutcheon — use rear udder view';
      tip = 'Stand 3–5 ft behind, camera at udder height, full udder in frame.';
    } else if (fusionStatus == YieldPredictionStatus.caution ||
        displayConfidence < 0.45) {
      alert = DairyAlert.caution;
      alertMessage = 'Prediction with caution — train TFLite or retake photo';
      tip = 'Use a clear rear udder photo; add more labeled training images for accuracy.';
    } else if (displayConfidence >= 0.7) {
      alert = DairyAlert.success;
      alertMessage = 'High-confidence milk mirror analysis';
      tip = 'Maintain nutrition and monitor udder health weekly.';
    } else {
      alert = DairyAlert.info;
      alertMessage = 'Analysis complete — review measurements below';
      tip = 'Log DIM and parity in farmer inputs for better stage accuracy.';
    }

    final steps = <PipelineStep>[
      PipelineStep(
        index: 1,
        title: 'Capture image',
        subtitle: 'Rear milk-mirror photo',
        status: PipelineStepStatus.pass,
      ),
      PipelineStep(
        index: 2,
        title: 'Animal detection',
        subtitle: gateOk ? 'Animal detected' : 'Failed',
        status: gateOk ? PipelineStepStatus.pass : PipelineStepStatus.fail,
      ),
      PipelineStep(
        index: 3,
        title: 'Species',
        subtitle: '$species ${(speciesConf * 100).toStringAsFixed(0)}%',
        status: speciesConf > 0.65 ? PipelineStepStatus.pass : PipelineStepStatus.partial,
      ),
      PipelineStep(
        index: 4,
        title: 'Sex check',
        subtitle: sexSubtitle,
        status: isBull && sexConf >= 0.55
            ? PipelineStepStatus.fail
            : sexLabel == 'Female' && sexConf >= 0.55
                ? PipelineStepStatus.pass
                : PipelineStepStatus.partial,
      ),
      PipelineStep(
        index: 5,
        title: 'Lactation',
        subtitle: lactationState,
        status: udderVisible ? PipelineStepStatus.pass : PipelineStepStatus.fail,
      ),
      PipelineStep(
        index: 6,
        title: 'Health screen',
        subtitle: healthStatus,
        status: healthStatus == 'Normal'
            ? PipelineStepStatus.pass
            : PipelineStepStatus.partial,
      ),
      PipelineStep(
        index: 7,
        title: 'Yield predict',
        subtitle: displayLabel,
        status: mirrorOk || predictionSource.contains('tflite')
            ? PipelineStepStatus.pass
            : PipelineStepStatus.partial,
      ),
    ];

    return DairyPipelineReport(
      workflowSteps: steps,
      species: species,
      speciesConfidence: speciesConf,
      sex: sexLabel,
      sexConfidence: sexConf,
      lactationState: lactationState,
      healthStatus: healthStatus,
      lactationStage: stage,
      yieldRange: yieldMin != null && yieldMax != null
          ? '${MilkProductionScale.clamp(yieldMin).toStringAsFixed(1)} – '
              '${MilkProductionScale.clamp(yieldMax).toStringAsFixed(1)} L/day'
          : MilkProductionScale.formatBand(
              MilkProductionScale.clamp(estimatedLiters),
            ),
      yieldLiters: MilkProductionScale.clamp(estimatedLiters),
      yieldConfidence: displayConfidence,
      alert: alert,
      alertMessage: alertMessage,
      recommendation: tip,
    );
  }
}
