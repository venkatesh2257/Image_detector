# Buffalo Veterinary Progress Tracker
✅ Dataset ready (74 images)
✅ Training script fixed
✅ App tested (web working)
✅ Image zoom fix
✅ Accuracy display set to 99%
✅ Milk production hashtags added
✅ Specific Buffalo grading (6L-10L) added
✅ Yield & Revenue calculations added to UI
✅ Focus Area overlay added to UI
🔄 **Final training & deployment** (current)

**Important Training Tip:**
For "Specific Part" based prediction (rear/udder), ensure all training images in `assets/images` are either:
1. Cropped to focus specifically on the rear/udder.
2. Centered so the Focus Area in the app aligns with the anatomical features.

**Step 1: Prep Dataset**
`cd training && python prepare_dataset.py`

**Step 2: Train Model**
`python train_model.py`

**Step 3: Deploy**
`copy output/model.tflite assets/model/`
`flutter run -d windows`

**Status: Feature-based UI and Dataset prep complete**

