"""Build balanced train/val/test folders with dedupe and QA."""
from __future__ import annotations

import hashlib
import json
import random
import re
import shutil
from collections import defaultdict
from pathlib import Path

from image_quality import validate_image_path

TRAINING_ROOT = Path(__file__).resolve().parent
DATASET_ROOT = TRAINING_ROOT / "datasets"
RAW_POOL = TRAINING_ROOT / "data" / "raw_pool"
EXPORT_MANIFEST = TRAINING_ROOT / "data" / "export_manifest.json"
CONFIG_PATH = TRAINING_ROOT / "config" / "retrain_config.json"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG"}


def load_config() -> dict:
    if CONFIG_PATH.exists():
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    return {}


def file_content_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_label(name: str) -> str | None:
    m = re.search(r"(\d+)\s*lit", name.lower())
    return f"{m.group(1)}_lit" if m else None


def ingest_raw_pool() -> list[tuple[Path, str, str]]:
    """Return (path, class, content_hash) from raw_pool/{class}/."""
    items: list[tuple[Path, str, str]] = []
    if not RAW_POOL.exists():
        return items
    for cls_dir in RAW_POOL.iterdir():
        if not cls_dir.is_dir():
            continue
        cls = cls_dir.name
        for path in cls_dir.rglob("*"):
            if path.is_file() and path.suffix in IMAGE_EXTS:
                items.append((path, cls, file_content_hash(path)))
    return items


def build_datasets(
    items: list[tuple[Path, str, str]],
    *,
    train_ratio: float = 0.70,
    val_ratio: float = 0.15,
    max_per_class: int = 800,
    min_per_class: int = 15,
) -> dict:
    """Filter QA, dedupe, balance, split into train/val/test."""
    cfg = load_config()
    train_ratio = cfg.get("train_ratio", train_ratio)
    val_ratio = cfg.get("val_ratio", val_ratio)
    test_ratio = 1.0 - train_ratio - val_ratio
    max_per_class = cfg.get("max_samples_per_class", max_per_class)
    min_per_class = cfg.get("min_images_per_class", min_per_class)

    seen_hashes: set[str] = set()
    by_class: dict[str, list[Path]] = defaultdict(list)
    rejected = 0
    duplicates = 0
    corrupt = 0

    for path, cls, h in items:
        if h in seen_hashes:
            duplicates += 1
            continue
        if not path.exists() or path.stat().st_size < 500:
            corrupt += 1
            continue
        ok, _score, _issues = validate_image_path(path)
        if not ok:
            rejected += 1
            continue
        seen_hashes.add(h)
        by_class[cls].append(path)

    for cls in list(by_class.keys()):
        paths = by_class[cls]
        if len(paths) < min_per_class:
            print(f"  Skip class {cls}: only {len(paths)} images (min {min_per_class})")
            del by_class[cls]
            continue
        random.shuffle(paths)
        by_class[cls] = paths[:max_per_class]

    for split in ("train", "val", "test"):
        split_dir = DATASET_ROOT / split
        if split_dir.exists():
            shutil.rmtree(split_dir)

    stats = {"train": 0, "val": 0, "test": 0, "classes": sorted(by_class.keys())}

    for cls, paths in sorted(by_class.items(), key=lambda x: int(x[0].split("_")[0])):
        random.shuffle(paths)
        n = len(paths)
        n_test = max(1, int(n * test_ratio)) if n >= 4 else 0
        n_val = max(1, int(n * val_ratio)) if n >= 3 else 0
        n_train = n - n_val - n_test
        if n_train < 1:
            n_train = max(1, n - 1)
            n_val = min(n_val, n - n_train)
            n_test = n - n_train - n_val

        train_paths = paths[:n_train]
        val_paths = paths[n_train : n_train + n_val]
        test_paths = paths[n_train + n_val :]

        for subset, split_name in (
            (train_paths, "train"),
            (val_paths, "val"),
            (test_paths, "test"),
        ):
            for i, src in enumerate(subset):
                dest_dir = DATASET_ROOT / split_name / cls
                dest_dir.mkdir(parents=True, exist_ok=True)
                dest = dest_dir / f"{src.stem}_{i}{src.suffix.lower()}"
                shutil.copy2(src, dest)
                stats[split_name] += 1

    labels_path = DATASET_ROOT / "labels.txt"
    with open(labels_path, "w", encoding="utf-8") as f:
        for cls in stats["classes"]:
            f.write(f"{cls}\n")

    stats.update(
        {
            "rejected_quality": rejected,
            "duplicates": duplicates,
            "corrupt": corrupt,
        }
    )
    print(
        f"Dataset built: train={stats['train']} val={stats['val']} test={stats['test']} "
        f"| rejected={rejected} dup={duplicates} corrupt={corrupt}"
    )
    return stats


def main() -> None:
    random.seed(42)
    RAW_POOL.mkdir(parents=True, exist_ok=True)
    try:
        from pipeline_validation import filter_directory

        filter_directory(RAW_POOL)
    except ImportError:
        pass
    items = ingest_raw_pool()
    if not items:
        raise SystemExit(f"No images in {RAW_POOL}. Run export_firestore_dataset.py first.")
    build_datasets(items)


if __name__ == "__main__":
    main()
