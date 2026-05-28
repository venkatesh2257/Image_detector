"""Server-side multi-stage validation (mirrors Flutter pipeline for export)."""
from __future__ import annotations

from pathlib import Path

from image_quality import validate_image_path
from PIL import Image

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def validate_angle_pil(im: Image.Image) -> tuple[bool, list[str]]:
    """Lightweight rear-angle checks."""
    issues: list[str] = []
    w, h = im.size
    aspect = w / h
    if aspect < 0.65:
        issues.append("portrait_not_rear")
    if aspect > 2.2:
        issues.append("panorama_not_rear")

    gray = im.convert("L").resize((320, max(1, int(320 * h / w))))
    import numpy as np

    arr = np.array(gray, dtype=np.float32)
    mid = arr.shape[1] // 2
    left = arr[:, :mid]
    right = arr[:, mid:]
    min_len = min(left.shape[1], right.shape[1])
    if min_len > 0:
        diff = np.abs(left[:, -min_len:] - right[:, :min_len]).mean()
        symmetry = 1.0 - min(1.0, diff / 128.0)
        if symmetry < 0.42:
            issues.append("side_view_asymmetric")

    h2 = arr.shape[0] // 2
    lower = (arr[h2:, :] > 35) & (arr[h2:, :] < 200)
    upper = (arr[:h2, :] > 35) & (arr[:h2, :] < 200)
    lower_r = lower.sum() / max(1, lower.size + upper.size)
    if lower_r < 0.38:
        issues.append("front_or_top_view")

    return len(issues) == 0, issues


def validate_for_training(path: Path) -> tuple[bool, dict]:
    """Run quality + angle; animal/udder validated on-device before upload."""
    ok_q, score_q, issues_q = validate_image_path(path)
    if not ok_q:
        return False, {"stage": "quality", "issues": issues_q, "score": score_q}

    try:
        with Image.open(path) as im:
            im = im.convert("RGB")
            ok_a, issues_a = validate_angle_pil(im)
    except OSError:
        return False, {"stage": "quality", "issues": ["corrupt"]}

    if not ok_a:
        return False, {"stage": "angle", "issues": issues_a}

    return True, {"stage": "ok", "score": score_q}


def filter_directory(raw_pool: Path) -> tuple[int, int]:
    """Remove files failing pipeline validation from raw_pool."""
    kept = rejected = 0
    for path in raw_pool.rglob("*"):
        if path.suffix.lower() not in {e.lower() for e in IMAGE_EXTS}:
            continue
        ok, _meta = validate_for_training(path)
        if ok:
            kept += 1
        else:
            path.unlink(missing_ok=True)
            rejected += 1
    print(f"Pipeline filter: kept={kept} rejected={rejected}")
    return kept, rejected
