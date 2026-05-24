#!/usr/bin/env python3
"""Automatic retraining orchestrator — run on schedule or when enough samples exist."""
from __future__ import annotations

import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

TRAINING_ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = TRAINING_ROOT / "output"
CONFIG_PATH = TRAINING_ROOT / "config" / "retrain_config.json"
PROJECT_ROOT = TRAINING_ROOT.parent
PRODUCTION_META = PROJECT_ROOT / "assets" / "model" / "training_metadata.json"
LOG_PATH = TRAINING_ROOT / "data" / "retrain_log.jsonl"


def load_config() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def log_event(event: str, **kwargs) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    row = {"ts": datetime.now(timezone.utc).isoformat(), "event": event, **kwargs}
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(row) + "\n")
    print(f"[RETRAIN] {event}: {kwargs}")


def count_raw_pool() -> int:
    raw = TRAINING_ROOT / "data" / "raw_pool"
    if not raw.exists():
        return 0
    exts = {".jpg", ".jpeg", ".png", ".webp"}
    return sum(1 for p in raw.rglob("*") if p.suffix.lower() in exts)


def get_pending_firestore_count() -> int:
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        return count_raw_pool()

    if not firebase_admin._apps:
        cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        if not cred_path:
            return count_raw_pool()
        firebase_admin.initialize_app(credentials.Certificate(cred_path))

    snap = firestore.client().document("ml_pipeline/state").get()
    if snap.exists:
        return int((snap.to_dict() or {}).get("pendingTrainingCount", 0))
    return 0


def load_current_val_accuracy() -> float:
    if PRODUCTION_META.exists():
        meta = json.loads(PRODUCTION_META.read_text(encoding="utf-8"))
        return float(meta.get("val_accuracy", 0))
    return 0.0


def should_retrain(cfg: dict) -> tuple[bool, str]:
    min_samples = cfg.get("min_new_samples_for_retrain", 300)
    pending = get_pending_firestore_count()
    pool = count_raw_pool()

    if cfg.get("schedule_daily"):
        return True, "daily_schedule"

    if pending >= min_samples:
        return True, f"pending_count={pending}>={min_samples}"

    if pool >= min_samples:
        return True, f"raw_pool={pool}>={min_samples}"

    return False, f"insufficient samples (pending={pending}, pool={pool}, need={min_samples})"


def run_pipeline(*, force: bool = False) -> int:
    cfg = load_config()
    reason = "forced"
    if not force:
        ok, reason = should_retrain(cfg)
        if not ok:
            log_event("skipped", reason=reason)
            return 0

    log_event("start", reason=reason)

    from export_firestore_dataset import export_firestore, merge_local_assets

    if cfg.get("export_from_firestore", True):
        try:
            export_firestore()
        except SystemExit as e:
            log_event("export_firestore_warning", message=str(e))
    if cfg.get("merge_local_assets", True):
        merge_local_assets()

    from dataset_manager import ingest_raw_pool, build_datasets

    items = ingest_raw_pool()
    if len(items) < cfg.get("min_images_per_class", 15) * 2:
        log_event("aborted", reason="not enough raw_pool images after QA")
        return 1

    build_datasets(items)

    old_acc = load_current_val_accuracy()
    min_deploy = cfg.get("min_val_accuracy_to_deploy", 0.45)
    min_improve = cfg.get("min_val_accuracy_improvement", 0.02)

    from train_model import train

    candidate_meta = train(deploy_to_app=False, output_prefix="model_candidate")
    cand_acc = float(candidate_meta["val_accuracy"])

    log_event(
        "trained",
        old_val_accuracy=old_acc,
        candidate_val_accuracy=cand_acc,
        test_accuracy=candidate_meta.get("test_accuracy"),
    )

    replace = cand_acc >= min_deploy and (
        cand_acc >= old_acc + min_improve or old_acc < min_deploy
    )

    if not replace:
        log_event(
            "keep_previous",
            reason=f"candidate {cand_acc:.2%} did not beat {old_acc:.2%}+{min_improve:.0%}",
        )
        return 0

    cand_tflite = OUTPUT_DIR / "model_candidate.tflite"
    prod_tflite = OUTPUT_DIR / "model.tflite"
    shutil.copy2(cand_tflite, prod_tflite)

    meta_src = OUTPUT_DIR / "model_candidate_metadata.json"
    meta_dst = OUTPUT_DIR / "model_metadata.json"
    shutil.copy2(meta_src, meta_dst)

    app_model = PROJECT_ROOT / "assets" / "model" / "model.tflite"
    app_labels = PROJECT_ROOT / "assets" / "labels" / "labels.txt"
    app_meta = PROJECT_ROOT / "assets" / "model" / "training_metadata.json"
    shutil.copy2(prod_tflite, app_model)
    shutil.copy2(OUTPUT_DIR / "labels.txt", app_labels)
    shutil.copy2(meta_dst, app_meta)

    log_event("deployed_local", val_accuracy=cand_acc)

    try:
        from upload_model import upload_production_model

        upload_production_model(metadata_path=meta_dst)
        log_event("uploaded_firebase")
    except SystemExit as e:
        log_event("upload_skipped", message=str(e))

    return 0


def main() -> None:
    force = "--force" in sys.argv
    raise SystemExit(run_pipeline(force=force))


if __name__ == "__main__":
    main()
