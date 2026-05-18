"""Prepare train/val folders from assets/images/animal photos (6 lit … 10 lit)."""
import random
import re
import shutil
from pathlib import Path

DATASET_ROOT = Path(__file__).resolve().parent / "datasets"
RAW_IMAGES = Path(__file__).resolve().parents[1] / "assets" / "images" / "animal photos"
TRAIN_DIR = DATASET_ROOT / "train"
VAL_DIR = DATASET_ROOT / "val"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG"}

TRAIN_RATIO = 0.85
RANDOM_SEED = 42


def parse_milk_yield(folder_name: str) -> str | None:
    folder_lower = folder_name.lower().strip()
    if "lit" not in folder_lower:
        return None
    numbers = re.findall(r"\d+", folder_lower.split("lit")[0])
    if numbers:
        return f"{numbers[0]}_lit"
    return None


def collect_images() -> list[tuple[Path, str]]:
    items: list[tuple[Path, str]] = []
    if not RAW_IMAGES.exists():
        raise FileNotFoundError(f"Dataset not found: {RAW_IMAGES}")

    for folder in RAW_IMAGES.iterdir():
        if not folder.is_dir():
            continue
        cls = parse_milk_yield(folder.name)
        if not cls:
            continue
        for path in folder.rglob("*"):
            if path.is_file() and path.suffix in IMAGE_EXTS:
                items.append((path, cls))
    return items


def stratified_split(
    items: list[tuple[Path, str]], train_ratio: float
) -> tuple[list[tuple[Path, str]], list[tuple[Path, str]]]:
    by_class: dict[str, list[Path]] = {}
    for path, cls in items:
        by_class.setdefault(cls, []).append(path)

    train_items: list[tuple[Path, str]] = []
    val_items: list[tuple[Path, str]] = []

    for cls, paths in by_class.items():
        random.shuffle(paths)
        if len(paths) == 1:
            train_items.extend((p, cls) for p in paths)
            continue
        n_train = max(1, int(len(paths) * train_ratio))
        if n_train >= len(paths):
            n_train = len(paths) - 1
        train_paths = paths[:n_train]
        val_paths = paths[n_train:]
        train_items.extend((p, cls) for p in train_paths)
        val_items.extend((p, cls) for p in val_paths)

    random.shuffle(train_items)
    random.shuffle(val_items)
    return train_items, val_items


def prepare_dataset() -> None:
    random.seed(RANDOM_SEED)

    if TRAIN_DIR.exists():
        shutil.rmtree(TRAIN_DIR)
    if VAL_DIR.exists():
        shutil.rmtree(VAL_DIR)

    all_images = collect_images()
    if not all_images:
        raise RuntimeError(f"No images found under {RAW_IMAGES}")

    train_images, val_images = stratified_split(all_images, TRAIN_RATIO)

    for img_path, cls in train_images:
        dest_dir = TRAIN_DIR / cls
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{img_path.parent.name}_{img_path.name}"
        shutil.copy2(img_path, dest)

    for img_path, cls in val_images:
        dest_dir = VAL_DIR / cls
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{img_path.parent.name}_{img_path.name}"
        shutil.copy2(img_path, dest)

    unique_classes = sorted(
        {cls for _, cls in all_images}, key=lambda x: int(x.split("_")[0])
    )

    labels_path = DATASET_ROOT / "labels.txt"
    with open(labels_path, "w", encoding="utf-8") as f:
        for cls in unique_classes:
            f.write(f"{cls}\n")

    app_labels = Path(__file__).resolve().parents[1] / "assets" / "labels" / "labels.txt"
    app_labels.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(labels_path, app_labels)

    print(f"Found {len(all_images)} images in {len(unique_classes)} classes")
    print(f"Train: {len(train_images)} | Val: {len(val_images)}")
    for cls in unique_classes:
        tr = sum(1 for _, c in train_images if c == cls)
        va = sum(1 for _, c in val_images if c == cls)
        print(f"  {cls}: train={tr} val={va}")
    print(f"Labels: {labels_path}")
    print("Ready for train_model.py")


if __name__ == "__main__":
    prepare_dataset()
