"""Train MobileNetV2 milk-yield classifier → TFLite for Flutter app."""
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

import tensorflow as tf

IMG_SIZE = 224
BATCH_SIZE = 16
EPOCHS_HEAD = 40
EPOCHS_FINETUNE = 20
DATASET_DIR = Path(__file__).resolve().parent / "datasets"
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
PROJECT_ROOT = Path(__file__).resolve().parents[1]


def augment_layers():
    return tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.12),
            tf.keras.layers.RandomZoom(0.18),
            tf.keras.layers.RandomContrast(0.22),
            tf.keras.layers.RandomBrightness(0.18),
            tf.keras.layers.RandomTranslation(0.08, 0.08),
        ],
        name="augment",
    )


def create_datasets(class_names: list[str]):
    train_ds = tf.keras.utils.image_dataset_from_directory(
        DATASET_DIR / "train",
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="int",
        shuffle=True,
        seed=42,
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        DATASET_DIR / "val",
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="int",
        shuffle=False,
    )

    # Ensure consistent class order
    train_ds.class_names = class_names
    val_ds.class_names = class_names

    augment = augment_layers()
    autotune = tf.data.AUTOTUNE

    def train_map(images, labels):
        images = tf.cast(images, tf.float32)
        images = augment(images, training=True)
        images = tf.keras.applications.mobilenet_v2.preprocess_input(images)
        return images, labels

    def val_map(images, labels):
        images = tf.cast(images, tf.float32)
        images = tf.keras.applications.mobilenet_v2.preprocess_input(images)
        return images, labels

    train_ds = train_ds.map(train_map, num_parallel_calls=autotune)
    val_ds = val_ds.map(val_map, num_parallel_calls=autotune)
    train_ds = train_ds.prefetch(autotune)
    val_ds = val_ds.prefetch(autotune)
    return train_ds, val_ds


def class_weights_from_dir(train_dir: Path, num_classes: int) -> dict[int, float]:
    counts = []
    for i in range(num_classes):
        cls_dir = sorted([d for d in train_dir.iterdir() if d.is_dir()])[i]
        counts.append(len(list(cls_dir.glob("*"))))
    total = sum(counts)
    weights = {}
    for i, c in enumerate(counts):
        weights[i] = total / (num_classes * max(c, 1))
    return weights


def build_model(num_classes: int):
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base_model.trainable = False

    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = tf.keras.applications.mobilenet_v2.preprocess_input(inputs)
    x = base_model(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.35)(x)
    x = tf.keras.layers.Dense(128, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.25)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)
    return model, base_model


def evaluate(model, val_ds) -> tuple[float, float]:
    results = model.evaluate(val_ds, verbose=0)
    loss = float(results[0])
    acc = float(results[1]) if len(results) > 1 else 0.0
    return loss, acc


def train():
    train_dir = DATASET_DIR / "train"
    if not train_dir.exists():
        raise FileNotFoundError(
            f"No {train_dir}. Run: python prepare_dataset.py"
        )

    class_names = sorted(
        [d.name for d in train_dir.iterdir() if d.is_dir()],
        key=lambda x: int(x.split("_")[0]),
    )
    num_classes = len(class_names)
    if num_classes < 2:
        raise RuntimeError("Need at least 2 classes to train.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    train_ds, val_ds = create_datasets(class_names)
    class_weight = class_weights_from_dir(train_dir, num_classes)

    print(f"Classes ({num_classes}): {class_names}")
    print(f"Class weights: {class_weight}")

    model, base_model = build_model(num_classes)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=6,
            restore_best_weights=True,
            mode="max",
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=3, min_lr=1e-6
        ),
    ]

    print("\n=== Phase 1: train head ===")
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS_HEAD,
        class_weight=class_weight,
        callbacks=callbacks,
    )

    base_model.trainable = True
    for layer in base_model.layers[:-40]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    print("\n=== Phase 2: fine-tune ===")
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS_FINETUNE,
        class_weight=class_weight,
        callbacks=callbacks,
    )

    val_loss, val_acc = evaluate(model, val_ds)
    print(f"\nFinal validation accuracy: {val_acc * 100:.1f}%")

    saved_model_dir = OUTPUT_DIR / "saved_model"
    if saved_model_dir.exists():
        shutil.rmtree(saved_model_dir)
    model.save(saved_model_dir)

    labels_path = OUTPUT_DIR / "labels.txt"
    with open(labels_path, "w", encoding="utf-8") as f:
        for name in class_names:
            f.write(f"{name}\n")

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    tflite_path = OUTPUT_DIR / "model.tflite"
    tflite_path.write_bytes(tflite_model)

    meta = {
        "trained": True,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "val_accuracy": round(val_acc, 4),
        "val_loss": round(val_loss, 4),
        "classes": class_names,
        "train_images": sum(
            len(list((train_dir / c).glob("*"))) for c in class_names
        ),
        "val_images": sum(
            len(list((DATASET_DIR / "val" / c).glob("*"))) for c in class_names
        ),
    }
    meta_path = OUTPUT_DIR / "training_metadata.json"
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    app_model = PROJECT_ROOT / "assets" / "model" / "model.tflite"
    app_labels = PROJECT_ROOT / "assets" / "labels" / "labels.txt"
    app_meta = PROJECT_ROOT / "assets" / "model" / "training_metadata.json"
    app_model.parent.mkdir(parents=True, exist_ok=True)
    app_labels.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(tflite_path, app_model)
    shutil.copy2(labels_path, app_labels)
    shutil.copy2(meta_path, app_meta)

    print("\nTraining complete.")
    print(f"  TFLite: {tflite_path}")
    print(f"  App model: {app_model}")
    print(f"  Val accuracy: {val_acc * 100:.1f}%")
    print("  Run the app and hot-restart to load the new model.")


if __name__ == "__main__":
    train()
