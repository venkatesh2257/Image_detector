import '../../config/scientific_udder_config.dart';
import '../../models/scientific_udder_models.dart';
import '../inference_logger.dart';
import 'scientific_image_context.dart';
import 'stages/stage0_quality_bridge.dart';
import 'stages/stage1_validity_bridge.dart';
import 'stages/stage2_anatomy_localization.dart';
import 'stages/stage3_pose_estimation.dart';
import 'stages/stage4_perspective_correction.dart';
import 'stages/stage5_udder_segmentation.dart';
import 'stages/stage6_keypoint_estimation.dart';
import 'stages/stage7_trait_derivation.dart';
import 'stages/stage8_confidence_scoring.dart';
import 'stages/stage9_trait_regression.dart';

/// Research-grade udder trait extraction pipeline (stages 0–9).
///
/// Extension only — does not replace [AiPipelineOrchestrator] or legacy fusion.
class ScientificUdderPipeline {
  ScientificUdderPipeline({
    Stage0QualityBridge? stage0,
    Stage1ValidityBridge? stage1,
    Stage2AnatomyLocalization? stage2,
    Stage3PoseEstimation? stage3,
    Stage4PerspectiveCorrection? stage4,
    Stage5UdderSegmentation? stage5,
    Stage6KeypointEstimation? stage6,
    Stage7TraitDerivation? stage7,
    Stage8ConfidenceScoring? stage8,
    Stage9TraitRegression? stage9,
  })  : _s0 = stage0 ?? const Stage0QualityBridge(),
        _s1 = stage1 ?? Stage1ValidityBridge(),
        _s2 = stage2 ?? Stage2AnatomyLocalization(),
        _s3 = stage3 ?? const Stage3PoseEstimation(),
        _s4 = stage4 ?? const Stage4PerspectiveCorrection(),
        _s5 = stage5 ?? const Stage5UdderSegmentation(),
        _s6 = stage6 ?? const Stage6KeypointEstimation(),
        _s7 = stage7 ?? const Stage7TraitDerivation(),
        _s8 = stage8 ?? const Stage8ConfidenceScoring(),
        _s9 = stage9 ?? const Stage9TraitRegression();

  final Stage0QualityBridge _s0;
  final Stage1ValidityBridge _s1;
  final Stage2AnatomyLocalization _s2;
  final Stage3PoseEstimation _s3;
  final Stage4PerspectiveCorrection _s4;
  final Stage5UdderSegmentation _s5;
  final Stage6KeypointEstimation _s6;
  final Stage7TraitDerivation _s7;
  final Stage8ConfidenceScoring _s8;
  final Stage9TraitRegression _s9;

  Future<ScientificUdderReport> extract({
    required String imagePath,
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) async {
    if (!ScientificUdderConfig.enabled) {
      return const ScientificUdderReport(
        stages: [],
        scientificallyValid: false,
        globalConfidence: 0,
        rejectReason: 'scientific_pipeline_disabled',
      );
    }

    final totalSw = Stopwatch()..start();
    InferenceLogger.banner('SCIENTIFIC UDDER PIPELINE — start');

    final stages = <ScientificStageMetric>[];

    late ScientificImageContext ctx;
    try {
      ctx = ScientificImageContext.fromPath(imagePath);
    } catch (e) {
      return ScientificUdderReport(
        stages: [
          ScientificStageMetric(
            stageId: 'load',
            passed: false,
            score: 0,
            durationMs: 0,
            issues: ['decode_failed'],
            detail: '$e',
          ),
        ],
        scientificallyValid: false,
        globalConfidence: 0,
        rejectReason: 'decode_failed',
      );
    }

    final s0 = await _s0.run(ctx);
    stages.add(s0);
    if (!s0.passed) {
      return _reject(stages, s0.issues.join(','));
    }

    final s1 = _s1.run(
      ctx,
      imagePath: imagePath,
      breed: breed,
      age: age,
      lactation: lactation,
      daysInMilk: daysInMilk,
      feed: feed,
    );
    stages.add(s1);
    if (!s1.passed) {
      return _reject(stages, s1.issues.join(','));
    }

    final loc = _s2.run(ctx);
    stages.add(loc.metric);
    if (!loc.metric.passed || loc.anatomy == null || loc.roi == null) {
      return _reject(stages, 'anatomy_localization_failed');
    }

    final pose = _s3.estimate(ctx, loc.anatomy!, loc.roi!.midlineX);
    final s3 = _s3.toStageMetric(pose);
    stages.add(s3);
    if (!s3.passed) {
      return _reject(stages, s3.issues.join(','), pose: pose);
    }

    final s4result = _s4.run(ctx, loc.anatomy!, pose, loc.roi!);
    stages.add(s4result.metric);
    if (!s4result.metric.passed) {
      return _reject(stages, s4result.metric.issues.join(','), pose: pose);
    }

    final seg = _s5.run(ctx, loc.anatomy!, loc.roi!);
    stages.add(seg.stage);
    if (!seg.stage.passed) {
      return _reject(stages, seg.stage.issues.join(','), pose: pose);
    }

    final keypoints = _s6.estimate(ctx, loc.anatomy!, segmentation: seg);
    final s6 = _s6.toStageMetric(keypoints);
    stages.add(s6);
    if (!s6.passed) {
      return _reject(stages, s6.issues.join(','), pose: pose);
    }

    final traits = _s7.derive(ctx, keypoints, segmentation: seg);
    stages.add(
      ScientificStageMetric(
        stageId: 'traits',
        passed: true,
        score: traits.perTraitConfidence.values.isEmpty
            ? 0.5
            : traits.perTraitConfidence.values.reduce((a, b) => a + b) /
                traits.perTraitConfidence.length,
        durationMs: 0,
      ),
    );

    final conf = _s8.score(stages: stages, traits: traits, pose: pose);
    if (!conf.scientificallyValid) {
      return ScientificUdderReport(
        stages: stages,
        scientificallyValid: false,
        globalConfidence: conf.globalConfidence,
        rejectReason: conf.rejectReason,
        traits: traits,
        pose: pose,
      );
    }

    final reg = _s9.predict(
      traits: traits,
      globalConfidence: conf.globalConfidence,
      lactation: lactation,
      daysInMilk: daysInMilk,
      breed: breed,
    );

    final rectPath = await ctx.writeWorkingToTemp('rectified');

    InferenceLogger.log(
      'SCI-PIPE',
      'done ${totalSw.elapsedMilliseconds}ms valid=true liters=${reg.liters}',
    );

    return ScientificUdderReport(
      stages: stages,
      scientificallyValid: true,
      globalConfidence: conf.globalConfidence,
      rejectReason: null,
      traits: traits,
      predictedLiters: reg.liters,
      regressionConfidence: reg.confidence,
      rectifiedImagePath: rectPath,
      pose: pose,
    );
  }

  ScientificUdderReport _reject(
    List<ScientificStageMetric> stages,
    String reason, {
    PoseEstimate? pose,
  }) {
    InferenceLogger.log('SCI-PIPE', 'REJECT: $reason');
    return ScientificUdderReport(
      stages: stages,
      scientificallyValid: false,
      globalConfidence: stages.isEmpty
          ? 0
          : stages.map((s) => s.score).reduce((a, b) => a + b) / stages.length,
      rejectReason: reason,
      pose: pose,
    );
  }
}
