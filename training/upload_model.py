"""Upload production TFLite bundle to Firebase Storage + update pipeline state."""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

OUTPUT_DIR = Path(__file__).resolve().parent / "output"
CONFIG_PATH = Path(__file__).resolve().parent / "config" / "retrain_config.json"


def upload_production_model(
    *,
    model_path: Path | None = None,
    metadata_path: Path | None = None,
    service_account: str | None = None,
) -> None:
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore, storage
    except ImportError as e:
        raise SystemExit("pip install firebase-admin") from e

    model_path = model_path or OUTPUT_DIR / "model.tflite"
    labels_path = OUTPUT_DIR / "labels.txt"
    metadata_path = metadata_path or OUTPUT_DIR / "model_metadata.json"

    if not model_path.exists():
        raise FileNotFoundError(model_path)

    meta = json.loads(metadata_path.read_text(encoding="utf-8"))
    val_acc = meta.get("val_accuracy", 0)

    if not firebase_admin._apps:
        cred_path = service_account or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        if not cred_path:
            raise SystemExit("Set GOOGLE_APPLICATION_CREDENTIALS")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(
            cred,
            {
                "storageBucket": os.environ.get(
                    "FIREBASE_STORAGE_BUCKET",
                    "buffalomilk-aada6.firebasestorage.app",
                )
            },
        )

    bucket = storage.bucket()
    version = datetime.now(timezone.utc).strftime("v%Y%m%d_%H%M%S")

    for local, remote in (
        (model_path, "models/production/model.tflite"),
        (labels_path, "models/production/labels.txt"),
        (metadata_path, "models/production/training_metadata.json"),
    ):
        if local.exists():
            bucket.blob(remote).upload_from_filename(str(local))
            print(f"  Uploaded {remote}")

    db = firestore.client()
    db.document("ml_pipeline/state").set(
        {
            "modelVersion": version,
            "valAccuracy": val_acc,
            "testAccuracy": meta.get("test_accuracy"),
            "deployedAt": firestore.SERVER_TIMESTAMP,
            "pendingTrainingCount": 0,
            "classes": meta.get("classes", []),
        },
        merge=True,
    )
    print(f"Pipeline state updated: modelVersion={version} val_acc={val_acc:.2%}")


if __name__ == "__main__":
    upload_production_model()
