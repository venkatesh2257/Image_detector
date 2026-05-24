"""Export Firestore training samples + Storage images → raw_pool for retraining."""
from __future__ import annotations

import base64
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

TRAINING_ROOT = Path(__file__).resolve().parent
RAW_POOL = TRAINING_ROOT / "data" / "raw_pool"
EXPORT_MANIFEST = TRAINING_ROOT / "data" / "export_manifest.json"
PROJECT_ROOT = TRAINING_ROOT.parent
LOCAL_ASSETS = PROJECT_ROOT / "assets" / "images" / "animal photos"
CONFIG_PATH = TRAINING_ROOT / "config" / "retrain_config.json"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG"}


def load_config() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def parse_label(name: str) -> str | None:
    m = re.search(r"(\d+)\s*lit", name.lower())
    return f"{m.group(1)}_lit" if m else None


def decode_data_url(data_url: str) -> bytes | None:
    if "," not in data_url:
        return None
    try:
        return base64.b64decode(data_url.split(",", 1)[1])
    except (ValueError, TypeError):
        return None


def export_firestore(service_account: str | None = None) -> int:
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore, storage
    except ImportError as e:
        raise SystemExit(
            "Install firebase-admin: pip install firebase-admin"
        ) from e

    if not firebase_admin._apps:
        cred_path = service_account or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        if not cred_path:
            raise SystemExit(
                "Set GOOGLE_APPLICATION_CREDENTIALS to service account JSON path"
            )
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred, {
            "storageBucket": os.environ.get(
                "FIREBASE_STORAGE_BUCKET",
                "buffalomilk-aada6.firebasestorage.app",
            )
        })

    db = firestore.client()
    bucket = storage.bucket()

    manifest: dict = {"exported_ids": [], "exported_at": None, "count": 0}
    if EXPORT_MANIFEST.exists():
        manifest = json.loads(EXPORT_MANIFEST.read_text(encoding="utf-8"))
    exported_ids = set(manifest.get("exported_ids", []))

    RAW_POOL.mkdir(parents=True, exist_ok=True)
    count = 0

    docs = db.collection_group("samples").stream()
    for doc in docs:
        data = doc.to_dict() or {}
        doc_id = doc.id
        if doc_id in exported_ids:
            continue
        if data.get("exportedForTraining") is True:
            continue

        label = data.get("primaryLabel") or doc.reference.parent.parent.id
        if not label or label in ("rejected", "uncategorized"):
            continue
        if not re.match(r"^\d+_lit$", str(label)):
            continue

        dest_dir = RAW_POOL / label
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{doc_id}.jpg"

        saved = False
        storage_path = data.get("imageStoragePath")
        if storage_path:
            blob = bucket.blob(storage_path)
            if blob.exists():
                blob.download_to_filename(str(dest))
                saved = True

        if not saved:
            url = data.get("imageStorageUrl")
            if url and url.startswith("http"):
                import urllib.request

                urllib.request.urlretrieve(url, dest)
                saved = True

        if not saved:
            image_path = data.get("imagePath", "")
            if isinstance(image_path, str) and image_path.startswith("data:image"):
                raw = decode_data_url(image_path)
                if raw:
                    dest.write_bytes(raw)
                    saved = True

        if not saved or not dest.exists() or dest.stat().st_size < 500:
            if dest.exists():
                dest.unlink()
            continue

        exported_ids.add(doc_id)
        count += 1
        doc.reference.update({
            "exportedForTraining": True,
            "exportedAt": firestore.SERVER_TIMESTAMP,
        })

    manifest["exported_ids"] = sorted(exported_ids)
    manifest["exported_at"] = datetime.now(timezone.utc).isoformat()
    manifest["count"] = len(exported_ids)
    EXPORT_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    EXPORT_MANIFEST.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Exported {count} new samples → {RAW_POOL}")
    return count


def merge_local_assets() -> int:
    """Copy labeled local folders into raw_pool (dedupe by filename)."""
    if not LOCAL_ASSETS.exists():
        return 0
    count = 0
    for folder in LOCAL_ASSETS.iterdir():
        if not folder.is_dir():
            continue
        cls = parse_label(folder.name)
        if not cls:
            continue
        dest_dir = RAW_POOL / cls
        dest_dir.mkdir(parents=True, exist_ok=True)
        for path in folder.rglob("*"):
            if path.is_file() and path.suffix in IMAGE_EXTS:
                dest = dest_dir / f"local_{path.parent.name}_{path.name}"
                if not dest.exists():
                    import shutil

                    shutil.copy2(path, dest)
                    count += 1
    print(f"Merged {count} local asset images into raw_pool")
    return count


def main() -> None:
    cfg = load_config()
    n = 0
    if cfg.get("export_from_firestore", True):
        n += export_firestore()
    if cfg.get("merge_local_assets", True):
        n += merge_local_assets()
    print(f"Total new/merged: {n}")


if __name__ == "__main__":
    main()
