"""Fit Milk Mirror escutcheon formula from labeled folders (6–10 L)."""
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

RAW_IMAGES = Path(__file__).resolve().parents[1] / "assets" / "images" / "animal photos"
OUTPUT = Path(__file__).resolve().parent / "output" / "milk_mirror_calibration.json"
APP_OUTPUT = (
    Path(__file__).resolve().parents[1] / "assets" / "model" / "milk_mirror_calibration.json"
)
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".JPG", ".JPEG", ".PNG"}


def parse_liters(folder_name: str) -> float | None:
    m = re.search(r"(\d+)\s*lit", folder_name.lower())
    return float(m.group(1)) if m else None


def escutcheon_features(img: Image.Image) -> tuple[float, float, float, float]:
    """Proxy features aligned with Dart Milk Mirror (normalized 0–1)."""
    w, h = img.size
    lower_y = int(h * 0.55)
    cx = w // 2
    band = int(w * 0.38)

    pink = udder_soft = total = 0
    left_mass = right_mass = 0

    for y in range(lower_y, h, 3):
        for x in range(max(0, cx - band), min(w, cx + band), 3):
            total += 1
            r, g, b = img.getpixel((x, y))[:3]
            br = (r + g + b) / 3
            if r > 95 and g > 70 and b > 80 and r < 195:
                pink += 1
            if 25 < br < 125:
                udder_soft += 1
            if x < cx and 30 < br < 140:
                left_mass += 1
            elif x >= cx and 30 < br < 140:
                right_mass += 1

    if total == 0:
        return 0.1, 0.1, 0.5, 0.0

    pink_r = pink / total
    udder_r = udder_soft / total
    sym = 1.0 - abs(left_mass - right_mass) / max(left_mass + right_mass, 1)
    area = (0.55 * 0.35) + udder_r * 0.4 + pink_r * 0.25
    fullness = min(1.0, udder_r * 2.5)
    return area, fullness, sym, pink_r


def main():
    rows = []
    for folder in RAW_IMAGES.iterdir():
        if not folder.is_dir():
            continue
        liters = parse_liters(folder.name)
        if liters is None:
            continue
        for path in folder.rglob("*"):
            if path.suffix not in IMAGE_EXTS:
                continue
            try:
                img = Image.open(path).convert("RGB")
                area, fullness, sym, pink = escutcheon_features(img)
                rows.append((liters, area, fullness, sym, pink))
            except OSError:
                continue

    if len(rows) < 8:
        print(f"Need more images for calibration (have {len(rows)})")
        return

    y = np.array([r[0] for r in rows])
    # Match Dart: areaNorm, fullness, symmetryIndex (symmetry penalty)
    X = np.array([[1.0, r[1], r[2], -r[3]] for r in rows])
    coeffs, _, _, _ = np.linalg.lstsq(X, y, rcond=None)
    intercept, c_area, c_full, c_sym = coeffs.tolist()

    preds = X @ coeffs
    mae = float(np.mean(np.abs(preds - y)))
    print(f"Calibrated on {len(rows)} images, MAE={mae:.2f} L")

    payload = {
        "version": 1,
        "formula": "liters = intercept + c_area*areaNorm + c_full*fullness + c_sym*symmetryIndex",
        "intercept": round(intercept, 4),
        "c_area": round(c_area, 4),
        "c_full": round(c_full, 4),
        "c_sym": round(c_sym, 4),
        "min_liters": 1.0,
        "max_liters": 30.0,
        "mae_liters": round(mae, 3),
        "samples": len(rows),
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    APP_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    APP_OUTPUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Wrote {APP_OUTPUT}")


if __name__ == "__main__":
    main()
