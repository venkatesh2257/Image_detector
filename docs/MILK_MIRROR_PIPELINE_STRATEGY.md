# Milk Mirror — Multi-Stage Pipeline Strategy

This document is the **master plan** for improving buffalo identification and milk-yield accuracy in the Flutter **Milk Mirror** app. Implementation order: **Phase B (liter accuracy) first**, then **Phase A (species on crop)**. **Crop-first is mandatory** for both.

---

## 1. Core problem

| Problem | Cause today | Target |
|---------|-------------|--------|
| Buffalo vs cow/goat confusion | Rules + TFLite see **full frame** (mud, trees, body shape) | Decide species on **udder/escutcheon crop only** |
| Dark buffalo rejected as “laptop” | Heuristic color rules on full image | Crop + strong-rear bypass (done); species on crop next |
| Weak liter bands (~35% val TFLite) | Small dataset; full-image classifier | Crop-based inference + **farmer fusion** + retrain on crops |
| Unclear errors | Generic “No Buffalo Detected” | Codes: `BLURRY`, `NOT_BUFFALO`, `BULL`, `CAUTION`, etc. |

---

## 2. Principle: crop first, classify second (MUST)

```text
Full photo (camera/gallery)
    │
    ▼
Rear anatomy (pin bones, udder) ──► bounding region
    │
    ▼
CROP: udder + escutcheon (+ small context)
    │
    ├──► Species / safety checks on CROP (Phase A)
    ├──► TFLite liter band on CROP (Phase B — better signal)
    └──► Milk Mirror geometry (full image + landmarks, unchanged)
```

**Why this is mandatory**

- Cow and buffalo **rear bodies** look similar in wide shots.
- **Milk mirror shape** (width, symmetry, hide) differs most in the **crop**.
- Laptop/selfie/human false positives drop when the model **does not see** desk, sky, or trees.

**Flutter implementation (this repo)**

| Piece | File | Status |
|-------|------|--------|
| Anatomy landmarks | `lib/services/rear_anatomy_detector.dart` | Exists |
| Crop builder | `lib/services/udder_escutcheon_crop_service.dart` | **Phase 0 (now)** |
| Rules gate (full image safety) | `lib/services/classifier_service_new.dart` | Exists |
| Species on crop | `lib/services/crop_species_gate_service.dart` | **Phase A** |
| Yield fusion (farmer + mirror + TFLite) | `lib/services/yield_fusion_service.dart` | **Phase B (now)** |
| Orchestration | `lib/services/classifier_service_new.dart` | Wired in phases |

---

## 3. Pipeline stages (target architecture)

| Stage | Name | Input | Output | Short-circuit |
|-------|------|--------|--------|----------------|
| 0 | Capture + Firestore | Photo path | `captures/{captureId}` | — |
| 1 | **Quality + safety gate** | Full image | Pass or `BLURRY` / `WRONG_ANGLE` / `HUMAN` / `DEVICE` | Yes → BLOCKED |
| 2 | **Anatomy + crop** | Full image | Crop file + landmarks | Crop fail → CAUTION |
| 3 | **Species on crop** | Crop only | `buffalo` / `non_buffalo` + confidence | &lt; 0.85 → BLOCKED (Phase A) |
| 4 | Sex | Crop or full | Female OK / **BULL** → BLOCKED | Bull → BLOCKED |
| 5 | Health | Crop + farmer “healthy?” | `CAUTION` flags | Optional warn |
| 6 | **Milk Mirror** | Full image + landmarks | L/day, area, symmetry | Drives primary yield |
| 7 | **TFLite band** | **Crop** (not full frame) | `6_lit`…`10_lit` scores | Low conf → CAUTION |
| 8 | **Farmer fusion** | DIM, parity, feed + image | Min–max L/day, confidence | Phase B |
| 9 | Save | All fields | Firestore update + UI | — |

Stages 1–2 and 8 are the focus of the current implementation wave.

---

## 4. Implementation phases (order you approved)

### Phase B first — Liter accuracy & farmer fusion (now)

**Goal:** Better **numbers and confidence** without waiting for a new species model.

| Change | What happens after |
|--------|-------------------|
| TFLite runs on **crop** when available | Band scores align with udder, not background |
| `YieldFusionService` blends Milk Mirror (65%) + TFLite (25%) + DIM/parity (10%) | Stable L/day; narrower band when inputs agree |
| Wider band when TFLite untrusted or low val accuracy | Honest **CAUTION** in UI |
| Farmer fields (age, lactation, DIM, feed) adjust peak yield | Mid-lactation curve reflected in estimate |

**Farmer-visible result**

- Shows e.g. `7.4 – 8.6 L/day` instead of a single misleading exact number when uncertain.
- Pipeline card shows **HIGH_CONFIDENCE** / **CAUTION** / **BLOCKED**.

### Phase A second — Species on crop (next)

**Goal:** Buffalo vs cow/goat/other on **crop only**.

| Change | What happens after |
|--------|-------------------|
| `CropSpeciesGateService` geometry + hide rules on crop | Cows rejected even if rear looks “animal-like” |
| Optional binary TFLite `buffalo_vs_other.tflite` on crop | Replace heuristics when 500+ labeled crops exist |
| Hard negatives in training (dark cow, light buffalo) | Fewer edge-case swaps |
| Test suite: `9 lit`, `10 lit` pass; cow folder fail | Regression safety |

**Not in Phase A day one:** FastAPI, YOLOv8, EfficientNet server, SAM — stay on-device unless you add a backend later.

### Phase C later — Backend & retrain loop

- Export Firestore `captures` / `training_assets` → `training/data/`
- Retrain TFLite + species model on **crops**
- Optional `POST /api/analyze` for heavy models

---

## 5. Best strategies mapped to this app

| Priority | Strategy | Phase | Must? |
|----------|----------|-------|-------|
| 1 | Crop first, then classify | 0 + all | **YES** |
| 2 | Keep rules gate for laptop/selfie/human (full image) | 1 | YES |
| 3 | Species on crop | A | Next |
| 4 | Escutcheon geometry as features | 6 (Milk Mirror) | Exists — extend |
| 5 | Farmer input fusion | B | **Now** |
| 6 | Hard negatives in training | C | Ongoing via Firestore |
| 7 | Clear status codes in UI | B/A | Gradual |
| 8 | Server-side EfficientNet/SAM | C | Optional |

---

## 6. What we are NOT doing (yet)

- Rewriting app in React Native or moving inference to FastAPI only.
- Replacing Milk Mirror with a single end-to-end classifier.
- Requiring 2000 images per class before shipping Phase B.

---

## 7. Data & retrain loop (ongoing)

```text
App capture → Firestore captures/{id}
           → training_assets/{label}/samples/{id}  (when rules pass)
           → export script → training/datasets/
           → train_model.py → assets/model/model.tflite
```

**Label crops as:** `buffalo_rear`, `cow_rear`, `goat`, `reject` when building Phase A TFLite.

---

## 8. Success criteria

| Test | Pass condition |
|------|----------------|
| `10 lit/k3 (2).jpg` | Rules pass, yield shown, not “laptop” reject |
| `9 lit/k3 (2).jpg` | Same |
| Laptop / selfie fixtures | BLOCKED |
| Cow rear images (when added) | BLOCKED after Phase A |
| TFLite on crop | `interpreter.run()` on crop path in logs |

---

## 9. Related docs

- [EXECUTION_FLOW.md](./EXECUTION_FLOW.md) — file-level trigger map
- [FIRESTORE_DATA.md](./FIRESTORE_DATA.md) — capture schema
- [training/README.md](../training/README.md) — retrain commands

---

## 10. Revision log

| Date | Change |
|------|--------|
| 2026-05-21 | Initial strategy: crop-first mandatory; Phase B then A |
