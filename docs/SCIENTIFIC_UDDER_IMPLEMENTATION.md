# Scientific Udder Trait Extraction — Implementation Plan

Extension of Milk Mirror (no rewrite). See `lib/services/scientific_udder/`.

## Architecture

```
ClassifierService.classifyImage()
  ├── AiPipelineOrchestrator (existing pre-milk)
  ├── Rules gate + Milk Mirror + TFLite + YieldFusion (existing)
  └── ScientificUdderPipeline.extract()  [NEW, optional blend]
        Stage 0 → … → Stage 9
```

**Feature flag:** `ScientificUdderConfig.enabled` (default `true`). Set `false` to disable scientific path only.

## New files

| Path | Responsibility |
|------|----------------|
| `lib/config/scientific_udder_config.dart` | Thresholds, regression coeffs, blend weights |
| `lib/models/scientific_udder_models.dart` | Traits, pose, keypoints, report |
| `lib/services/scientific_udder/scientific_image_context.dart` | Decoded image + norm distance |
| `lib/services/scientific_udder/scientific_udder_pipeline.dart` | Orchestrator stages 0–9 |
| `lib/services/scientific_udder/stages/stage0_quality_bridge.dart` | Wraps `ImageQualityValidator` |
| `stage1_validity_bridge.dart` | Animal + angle validators |
| `stage2_anatomy_localization.dart` | ROI via `RearAnatomyDetector` |
| `stage3_pose_estimation.dart` | Yaw, roll, pitch proxy |
| `stage4_perspective_correction.dart` | Roll + mild yaw shear + crop |
| `stage5_udder_segmentation.dart` | Heuristic mask (TFLite slot) |
| `stage6_keypoint_estimation.dart` | Extended landmarks |
| `stage7_trait_derivation.dart` | RUH, RUW, RTD, symmetry, depth |
| `stage8_confidence_scoring.dart` | Global + per-trait confidence |
| `stage9_trait_regression.dart` | MLR-style liters prediction |

## Integration (unchanged when disabled)

| File | Change |
|------|--------|
| `classifier_service_new.dart` | Optional blend after fusion; `scientificReport` on result |
| `capture_firestore_service.dart` | Persists `scientificReport.toFirestore()` |

## Reused (untouched logic)

- `ImageQualityValidator`, `AnimalValidationService`, `AngleValidationService`
- `RearAnatomyDetector`, `UdderEscutcheonCropService`
- `YieldFusionService`, `TfliteClassifierService`
- Firebase continuous learning scripts

## TFLite models (future assets)

| Asset | Stage | Suggested model |
|-------|-------|-----------------|
| `udder_seg.tflite` | 5 | DeepLabV3-Mobile / U-Net 256² INT8 |
| `udder_keypoints.tflite` | 6 | MobilePose / HRNet-lite heatmaps |
| `hindquarter_det.tflite` | 2 | YOLOv8-nano bbox |
| `trait_regressor.tflite` | 9 | FC network replacing hand coeffs |

## Trait math (Stage 7)

- `ruhNorm = |udderTop.y - vulva.y|`
- `ruwNorm = |rightPin.x - leftPin.x|`
- `rtdNorm = distance(teatL, teatR)`
- `scale = referencePinSpreadCm / referencePinSpreadNorm`
- `ruhCm = ruhNorm * scale * 1.1` (calibrate with manual NDDB measures)
- `symmetryIndex = 1 - |leftMass - rightMass| / totalMass`

## Homography (Stage 4, current)

1. Roll-correct via pin line angle  
2. Mild yaw shear if `|yaw| ≤ maxYawRad`  
3. Crop udder ROI → resize 320×400  

Full 4-point homography when keypoint TFLite is added.

## Confidence (Stage 8)

Weighted mean of stage scores + trait confidences. Reject if `< minGlobalConfidence` (0.38).

## Firebase fields (captures)

`scientificallyValid`, `globalConfidence`, `traits.{ruhCm,ruwCm,...}`, `predictedLitersTraits`, `stages[]`.

## Implementation order

1. ✅ Config + models + pipeline skeleton  
2. ✅ Stages 0–9 heuristic implementation  
3. ✅ Classifier blend + Firestore  
4. Collect 50 animals manual RUH/RUW calibration  
5. Export TFLite seg + keypoints  
6. Retrain Stage 9 regression on Firestore trait + peak yield  

## Validation

- Unit: `test/scientific_udder_trait_test.dart`  
- Field: compare CV RUH/RUW vs tape on 30 buffaloes  
- Target: RMSE ≤ 2.5 L/day on peak yield after regression retrain  

## Debugging

Filter logcat for `SCI-S0` … `SCI-S9`, `SCI-PIPE`.

## Dataset labeling

```
labels/
  {animal_id}/
    images/rear_001.jpg
    annotations.json  # keypoints normalized, RUH cm manual, peak_yield_kg
```

Export script should read Firestore `traits` + farmer peak yield for Python retrain.
