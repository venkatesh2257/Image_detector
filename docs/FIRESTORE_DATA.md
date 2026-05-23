# Firestore data model (Milk Mirror)

## Collections

### 1. `captures/{captureId}` — every app photo

Written when the farmer picks **Camera** or **Gallery**. Updated on **Proceed** and after AI.

| Field | When set | Purpose |
|-------|----------|---------|
| `captureId` | Pick | Same as document id, e.g. `cap_1730123456789` |
| `deviceId` | Pick | Stable id until login (`DeviceSessionService`) |
| `userId` | Pick | `null` now; set after Firebase Auth login |
| `imageData` | Pick | JPEG base64 (`data:image/jpeg;base64,...`) |
| `source` | Pick | `camera` or `gallery` |
| `status` | Pick → update | `captured` → `reviewed` → `analyzed` / `rejected` |
| `animalHealthy` | Proceed | Review checkbox |
| `age`, `lactation`, `daysInMilk`, `feed` | Proceed | Farm context |
| `predictionLabel`, `estimatedLiters`, … | After AI | Model output |
| `trainingLabel` | After AI | e.g. `8_lit` or `rejected` |
| `trainingDocPath` | After AI | Link to training copy |

**Code:** `lib/services/capture_firestore_service.dart`

### 2. `training_assets/{label}/samples/{captureId}` — model training

Auto-copied when rules gate **passes** and a training label exists (same `captureId`).

Used by:

- Admin panel (`lib/admin/`)
- Future training scripts reading `collectionGroup('samples')`

## Future user login

1. Sign in with Firebase Auth.
2. Call `DeviceSessionService().setLinkedUserId(uid)`.
3. New captures store `userId`.
4. Optional: query `captures` where `userId == uid`.

## Firestore rules (development)

Use test mode or rules like:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /captures/{captureId} {
      allow read, write: if true; // tighten when Auth is added
    }
    match /training_assets/{label}/samples/{docId} {
      allow read, write: if true;
    }
  }
}
```

## Regenerate images for training

`collectionGroup('samples')` returns all training rows with `imagePath` (base64). Export script can decode to files under `training/data/` (planned).

## App flow

```
Pick image → save captures/{captureId} (status: captured)
Proceed    → update reviewed fields
AI done    → update analyzed + mirror to training_assets if valid buffalo
```
