"""Flag low-confidence Firestore samples for priority labeling / retrain."""
from __future__ import annotations

import os
from pathlib import Path

CONFIG_PATH = Path(__file__).resolve().parent / "config" / "retrain_config.json"


def flag_hard_examples() -> int:
    import json

    import firebase_admin
    from firebase_admin import credentials, firestore

    cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    threshold = cfg.get("hard_example_confidence_threshold", 0.45)

    if not firebase_admin._apps:
        cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        if not cred_path:
            raise SystemExit("Set GOOGLE_APPLICATION_CREDENTIALS")
        firebase_admin.initialize_app(credentials.Certificate(cred_path))

    db = firestore.client()
    count = 0
    for doc in db.collection_group("samples").stream():
        data = doc.to_dict() or {}
        conf = float(data.get("confidence") or 1.0)
        if conf <= threshold and not data.get("hardExample"):
            doc.reference.update({"hardExample": True, "needsReview": True})
            count += 1
    print(f"Flagged {count} hard examples (confidence <= {threshold})")
    return count


if __name__ == "__main__":
    flag_hard_examples()
