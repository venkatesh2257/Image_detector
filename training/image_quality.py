"""Lightweight image QA (mirrors Flutter ImageQualityValidator)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG"}

MIN_BLUR_VARIANCE = 45.0
MIN_BRIGHTNESS = 38.0
MAX_BRIGHTNESS = 245.0
MIN_REAR_ASPECT = 0.72
MAX_REAR_ASPECT = 1.85
MIN_ORGANIC = 0.08
MIN_UDDER_BAND = 0.04
MAX_NOISE_SCORE = 0.72


def validate_image_path(path: Path) -> tuple[bool, float, list[str]]:
    try:
        with Image.open(path) as im:
            im = im.convert("RGB")
            return validate_pil(im)
    except OSError:
        return False, 0.0, ["corrupt_or_unreadable"]


def validate_pil(im: Image.Image) -> tuple[bool, float, list[str]]:
    w, h = im.size
    issues: list[str] = []
    if w < 120 or h < 120:
        return False, 0.0, ["resolution_too_low"]

    aspect = w / h
    if aspect < MIN_REAR_ASPECT or aspect > MAX_REAR_ASPECT:
        issues.append("wrong_aspect_ratio")

    small = im.resize((320, max(1, int(320 * h / w))), Image.Resampling.BILINEAR)
    gray = np.array(small.convert("L"), dtype=np.float32)

    blur_var = _laplacian_variance(gray)
    if blur_var < MIN_BLUR_VARIANCE:
        issues.append("too_blurry")

    brightness = float(gray.mean())
    if brightness < MIN_BRIGHTNESS:
        issues.append("too_dark")
    elif brightness > MAX_BRIGHTNESS:
        issues.append("overexposed")

    organic = _torso_organic(gray)
    if organic < MIN_ORGANIC:
        issues.append("low_livestock_signature")

    udder = _lower_band(gray)
    if udder < MIN_UDDER_BAND:
        issues.append("rear_udder_not_visible")

    noise = _noise_score(gray)
    if noise > MAX_NOISE_SCORE:
        issues.append("noisy_image")

    score = _score(blur_var, brightness, organic, udder, aspect, len(issues), noise)
    return len(issues) == 0, score, issues


def _laplacian_variance(gray: np.ndarray) -> float:
    if gray.shape[0] < 3 or gray.shape[1] < 3:
        return 0.0
    lap = (
        -4 * gray[1:-1, 1:-1]
        + gray[1:-1, :-2]
        + gray[1:-1, 2:]
        + gray[:-2, 1:-1]
        + gray[2:, 1:-1]
    )
    return float(lap.var())


def _torso_organic(gray: np.ndarray) -> float:
    h, w = gray.shape
    y0, y1 = int(h * 0.25), int(h * 0.72)
    x0, x1 = int(w * 0.22), int(w * 0.78)
    band = gray[y0:y1:2, x0:x1:2]
    if band.size == 0:
        return 0.0
    organic = ((band > 35) & (band < 175)).sum()
    return organic / band.size


def _lower_band(gray: np.ndarray) -> float:
    h, w = gray.shape
    y0 = int(h * 0.55)
    band = gray[y0::2, int(w * 0.2) : int(w * 0.8) : 2]
    if band.size == 0:
        return 0.0
    mass = ((band > 40) & (band < 200)).sum()
    return mass / band.size


def _noise_score(gray: np.ndarray) -> float:
    if gray.shape[0] < 2 or gray.shape[1] < 2:
        return 0.0
    diff = np.abs(gray[:, :-1].astype(np.float32) - gray[:, 1:].astype(np.float32))
    var_d = float(diff.var())
    return min(1.0, var_d / 400.0)


def _score(
    blur_var: float,
    brightness: float,
    organic: float,
    udder: float,
    aspect: float,
    issue_count: int,
    noise: float = 0.0,
) -> float:
    s = 1.0
    s *= min(1.0, blur_var / 120.0)
    s *= 1.0 - min(0.5, abs(brightness - 128) / 128.0)
    s *= min(1.0, organic / 0.25)
    s *= min(1.0, udder / 0.15)
    s *= 1.0 - min(0.5, noise)
    if 0.9 <= aspect <= 1.4:
        s *= 1.05
    s -= issue_count * 0.18
    return max(0.0, min(1.0, s))
