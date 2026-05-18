# Milk Mirror — Product Spec & Code Reality Check

> **Vision:** Rear-udder photo → pin bones + escutcheon measure → dairy insights with attitude.  
> **Master reference:** Your `MILK MIRROR ANALYSIS` infographic (workflow + 6 feature blocks).

---

## The 7-step app workflow (infographic left column)

| Step | What the diagram says | What our app does today | Status |
|------|----------------------|-------------------------|--------|
| 1 | Capture milk mirror image | Gallery / Camera (`image_picker`) | ✅ Done |
| 2 | Animal detection + orientation | Rules: animal present, no human, rear/udder checks | 🟡 Partial |
| 3 | Sex classification (female vs bull) | Only “human detected” — **no bull/male filter** | ❌ Missing |
| 4 | Lactation state (lactating vs dry) | Udder visibility heuristic — **not labeled in UI** | 🟡 Partial |
| 5 | Health screening | Blur/cartoon/quality score — **no lesion/symmetry health UI** | 🟡 Partial |
| 6 | Lactation stage (early / mid / late DIM) | `daysInMilk` in debug form only — **not from image** | ❌ Missing |
| 7 | Milk yield + confidence | Milk Mirror measure + TFLite band | 🟡 Partial |

---

## Feature block 1 — Species detection

| Spec | Code | Status |
|------|------|--------|
| Buffalo vs cow | `_classifySpecies()` color heuristics | 🟡 Logic exists |
| Show both options in UI | Not shown — only rejects non-buffalo | ❌ UI missing |
| Train species model | Not started | ❌ |

**Action:** Add UI chips `Buffalo 87%` / `Cow 12%` from `_calculateBuffaloProbability` / `_calculateCowProbability`.

---

## Feature block 2 — Sex detection

| Spec | Code | Status |
|------|------|--------|
| Female ✅ / Male bull ❌ | No scrotum/male pattern detector | ❌ |
| Block males from yield | Not implemented | ❌ |

**Action:** Add `_classifySex()` (lower-body anatomy heuristics or small classifier). Block prediction if male.

---

## Feature block 3 — Lactation state

| Spec | Code | Status |
|------|------|--------|
| Lactating (full udder) | Udder keypoint + pink/dark lower region | 🟡 |
| Dry period (shrunk udder) | No explicit dry-state branch | ❌ |
| UI lactating / dry badges | Not shown | ❌ |

**Action:** `lactationState = udderScore > threshold ? lactating : dry` + red block if dry.

---

## Feature block 4 — Health screening (diagram block 4)

| Spec | Code | Status |
|------|------|--------|
| Udder asymmetry | Milk Mirror `symmetryIndex` | 🟡 |
| Swelling / texture / wounds | Not implemented | ❌ |
| Dirty tail / poor BCS | Body condition pixels only | 🟡 |
| Normal vs abnormal UI | Not shown | ❌ |

**Action:** Health panel from symmetry + quality + future lesion model.

---

## Feature block 5 — Milk yield prediction (hero screen)

| Spec | Code | Status |
|------|------|--------|
| Input summary (species, sex, state, health, stage) | Only in logs / partial hashtags | 🟡 |
| Range e.g. 8.5–10.2 L/day | `MilkMirrorResult.rangeLabel` | ✅ |
| Confidence ring 82% | Text % only — no ring gauge | 🟡 |
| Recommendation tip | Not implemented | ❌ |

**Action:** Pipeline dashboard card + circular confidence + tip text.

---

## Feature block 6 — Outputs & alerts

| Spec | Code | Status |
|------|------|--------|
| 🟢 Success (high confidence) | No color-coded alert system | ❌ |
| 🟡 Caution | Low confidence warning (orange box) | 🟡 |
| 🔴 Blocked | Rules reject → “No Buffalo” | 🟡 |
| 🔵 Recommendation | Not implemented | ❌ |

**Action:** `DairyAlert` enum → top banner on every result.

---

## Escutcheon / pin bones (center of diagram)

| Spec | Code | Status |
|------|------|--------|
| Points A B C D | `MilkMirrorMeasurementService` | ✅ |
| Height A–B, Width C–D | Logged + UI rows | ✅ |
| Area = H × W | `areaNorm` | ✅ |
| Symmetry index | `symmetryIndex` | ✅ |
| Overlay on photo | `AnatomicalPainter` A–D + pins | ✅ |

---

## Accuracy killers (why photos feel “wrong”)

1. **TFLite not trained** on your `6_lit`…`10_lit` folders → band guess only.  
2. **Heuristic pin bones** — not a trained pose model → drifts on random angles.  
3. **No sex / dry / health models** — pipeline incomplete vs infographic.  
4. **Measurement formula uncalibrated** — needs your master 10 L photo as anchor.

---

## Priority action list

### P0 — Must have (match infographic)

- [ ] Train `model.tflite` on labeled buffalo folders  
- [ ] Pipeline UI: all 6 blocks visible with live status  
- [ ] Alert banner: Success / Caution / Blocked / Info  
- [ ] Input summary row before yield (species, sex, lactation, health, stage)

### P1 — Accuracy

- [ ] Calibrate Milk Mirror liters using known 6–10 L reference photos  
- [ ] Sex classifier (block bulls)  
- [ ] Lactation dry vs lactating gate  
- [ ] Farmer inputs UI (DIM, parity) — optional fields on main screen

### P2 — Polish / “trending” UI

- [ ] Dark glass dashboard theme (not generic purple Material)  
- [ ] Animated step connector on workflow  
- [ ] Confidence ring + yield range hero typography  
- [ ] Good vs bad photo coach before capture

### P3 — ML upgrade

- [ ] Keypoint model (MediaPipe / custom TFLite pose) for A–D  
- [ ] Health lesion detector  
- [ ] Species + sex multi-class TFLite

---

## File map (where logic lives)

| Area | File |
|------|------|
| Rules gate + species heuristics | `lib/services/classifier_service_new.dart` |
| Escutcheon / pin bones | `lib/services/milk_mirror_measurement_service.dart` |
| TFLite bands | `lib/services/tflite_classifier_service.dart` |
| Visual milk heuristic | `lib/services/image_based_milk_calculator.dart` |
| UI + overlay | `lib/main.dart` |
| Training | `training/train_model.py` |
| Logs / proof | `lib/services/inference_logger.dart` |

---

## One-line truth

**The infographic is the product. The app today is ~40% there:** capture + escutcheon measure + partial rules + untrained TFLite. **Sex, dry state, health panel, alert system, and trained yield bands** are still the gap.
