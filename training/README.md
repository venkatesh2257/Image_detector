# Admin Training Automation

## 1) Collect data from app
- Open the app and go to the `Admin` tab.
- Add image + primary label + hashtags + metadata.
- Click `Export manifest for automated training`.

## 2) Prepare dataset folders
From project root:

```powershell
cd training
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python prepare_dataset.py
```

When prompted, paste the `admin_dataset` path shown in the app admin panel.

## 3) Train model

```powershell
python train_model.py
```

Generated files:
- `training/output/model.tflite`
- `training/output/labels.txt`

## 4) Integrate into Flutter app
Copy:
- `training/output/model.tflite` -> `assets/model/model.tflite`
- `training/output/labels.txt` -> `assets/labels/labels.txt`

Then run:

```powershell
cd ..
flutter pub get
flutter run -d windows
```

## Retrain flow
After collecting more samples in Admin panel:
1. Export manifest again
2. Run `prepare_dataset.py`
3. Run `train_model.py`
4. Replace app model and labels
