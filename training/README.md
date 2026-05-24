# Training & Continuous Learning

## Quick start

```bash
cd training
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"

# Export user uploads from Firestore → raw_pool
python export_firestore_dataset.py

# Build train/val/test with QA + balance
python dataset_manager.py

# Train + evaluate (confusion matrix in output/)
python train_model.py
```

## Automatic retrain (production)

```bash
python auto_retrain.py          # only when ≥300 new samples (config)
python auto_retrain.py --force  # ignore threshold
```

Pipeline:

1. `export_firestore_dataset.py` — Firestore/Storage → `data/raw_pool/`
2. `dataset_manager.py` — QA, dedupe, train/val/test split
3. `train_model.py` — candidate model + metrics
4. Compare accuracy → deploy only if improved
5. `upload_model.py` — Storage + `ml_pipeline/state`
6. Flutter app downloads new `.tflite` on next launch

## Other scripts

| Script | Purpose |
|--------|---------|
| `calibrate_milk_mirror.py` | Escutcheon → liters calibration |
| `hard_example_mining.py` | Flag low-confidence samples for review |
| `export_bootstrap_model.py` | Untrained TFLite for first install |
| `prepare_dataset.py` | Legacy: local `assets/images/animal photos` only |

## Full documentation

See [docs/CONTINUOUS_LEARNING.md](../docs/CONTINUOUS_LEARNING.md).
