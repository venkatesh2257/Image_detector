import os
import shutil
from pathlib import Path
import random

# Buffalo milk dataset preparation
DATASET_ROOT = Path('datasets')
RAW_IMAGES = Path('../assets/images/animal photos')
TRAIN_DIR = DATASET_ROOT / 'train'
VAL_DIR = DATASET_ROOT / 'val'

def parse_milk_yield(folder_name):
    """Normalize folder name to class name like '6_lit'"""
    folder_lower = folder_name.lower()
    if 'lit' not in folder_lower:
        return None
    
    import re
    numbers = re.findall(r'\d+', folder_lower.split('lit')[0])
    if numbers:
        return f"{numbers[0]}_lit"
    return None

def prepare_dataset():
    """Copy images to train/val by specific milk yield folders"""
    
    # Clear old data if exists
    if TRAIN_DIR.exists(): shutil.rmtree(TRAIN_DIR)
    if VAL_DIR.exists(): shutil.rmtree(VAL_DIR)
    
    all_images = []
    
    # Scan all lit folders in assets
    for folder in RAW_IMAGES.iterdir():
        if folder.is_dir():
            cls = parse_milk_yield(folder.name)
            if cls:
                (TRAIN_DIR / cls).mkdir(parents=True, exist_ok=True)
                (VAL_DIR / cls).mkdir(parents=True, exist_ok=True)

                # Support multiple extensions
                images = []
                for ext in ['*.jpg', '*.jpeg', '*.png', '*.JPG', '*.JPEG']:
                    images.extend(list(folder.glob(ext)))

                all_images.extend([(img, cls) for img in images])
    
    if not all_images:
        print(f"Error: No images found in {RAW_IMAGES}")
        return

    print(f'Found {len(all_images)} milk-labeled images across {len(set(c for i,c in all_images))} categories')
    
    # 85/15 split
    random.shuffle(all_images)
    split_idx = int(0.85 * len(all_images))
    train_images = all_images[:split_idx]
    val_images = all_images[split_idx:]
    
    # Copy to folders
    for img_path, cls in train_images:
        dest = TRAIN_DIR / cls / img_path.name
        shutil.copy2(img_path, dest)

    for img_path, cls in val_images:
        dest = VAL_DIR / cls / img_path.name
        shutil.copy2(img_path, dest)

    # Save labels sorted numerically
    unique_classes = sorted(list(set(c for i,c in all_images)), key=lambda x: int(x.split('_')[0]))
    with open(DATASET_ROOT / 'labels.txt', 'w') as f:
        for cls in unique_classes:
            f.write(f'{cls}\n')
    
    # Also update app assets labels
    app_labels_path = Path('../assets/labels/labels.txt')
    app_labels_path.parent.mkdir(parents=True, exist_ok=True)
    with open(app_labels_path, 'w') as f:
        for cls in unique_classes:
            f.write(f'{cls}\n')

    print('\n✅ Dataset prepared! Ready for train_model.py')
    print(f'Train: {len(train_images)} | Val: {len(val_images)}')
    print(f'Classes: {unique_classes}')

if __name__ == '__main__':
    random.seed(42)
    prepare_dataset()

