# Multi-Stage Intelligent AI Pipeline

Production accuracy improvements without replacing Flutter + on-device TFLite.

## Pipeline stages

```
User capture / upload
        ↓
┌───────────────────┐
│ 1. Quality        │  blur, dark, exposure, noise, resolution
└─────────┬─────────┘
          ↓
┌───────────────────┐
│ 2. Animal         │  human, laptop, pets, non-livestock (rules gate)
└─────────┬─────────┘
          ↓
┌───────────────────┐
│ 3. Angle          │  rear view, symmetry, pin/udder geometry
└─────────┬─────────┘
          ↓
┌───────────────────┐
│ 4. Rear Udder     │  anatomy landmarks, escutcheon crop, YOLO-ready
└─────────┬─────────┘
          ↓
┌───────────────────┐
│ 5. Milk Prediction│  Milk Mirror + TFLite + fusion (existing)
└─────────┬─────────┘
          ↓
Firebase Storage + Firestore (if stages 1–4 pass for training)
        ↓
Dataset export → auto_retrain.py → improved .tflite
```

## Dart files

| Stage | Service |
|-------|---------|
| Orchestrator | `lib/services/ai_pipeline_orchestrator.dart` |
| Quality | `lib/services/image_quality_validator.dart` |
| Animal | `lib/services/animal_validation_service.dart` |
| Angle | `lib/services/angle_validation_service.dart` |
| Rear udder | `lib/services/rear_udder_detection_service.dart` |
| Milk | `lib/services/classifier_service_new.dart` (unchanged core) |

## Integration points

- **Upload:** `CaptureFirestoreService.saveCaptureDraft()` runs full pipeline (`validateForTraining`).
- **Inference:** `ClassifierService.classifyImage()` runs `validatePreMilk()` then existing rules gate + TFLite.
- **Training:** Only samples with `pipelinePassed: true` are mirrored to `training_assets/`.

## Future YOLO

Add `assets/model/udder_yolo.tflite` and implement `YoloUdderDetector` in `rear_udder_detection_service.dart`. Heuristic backend remains fallback.

## Continuous learning

See [CONTINUOUS_LEARNING.md](CONTINUOUS_LEARNING.md). Retrain triggers at **300+** validated samples, not per upload.

## Python mirror

`training/pipeline_validation.py` applies quality + angle filters during `dataset_manager.py`.
