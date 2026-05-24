"""Train MobileNetV2 milk-yield classifier → TFLite (incremental + evaluation)."""
from __future__ import annotations

import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import tensorflow as tf

IMG_SIZE = 224
BATCH_SIZE = 16
EPOCHS_HEAD = 40
EPOCHS_FINETUNE = 20
DATASET_DIR = Path(__file__).resolve().parent / "datasets"
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = Path(__file__).resolve().parent / "config" / "retrain_config.json"


def load_config() -> dict:
    if CONFIG_PATH.exists():
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    return {}


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


def create_datasets(class_names: list[str], split: str):
    dir_path = DATASET_DIR / split
    return tf.keras.utils.image_dataset_from_directory(
        dir_path,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="int",
        shuffle=(split == "train"),
        seed=42 if split == "train" else None,
    )


def map_dataset(ds, training: bool):
    augment = augment_layers()
    autotune = tf.data.AUTOTUNE

    def _map(images, labels):
        images = tf.cast(images, tf.float32)
        if training:
            images = augment(images, training=True)
        images = tf.keras.applications.mobilenet_v2.preprocess_input(images)
        return images, labels

    return ds.map(_map, num_parallel_calls=autotune).prefetch(autotune)


def class_weights_from_dir(train_dir: Path, num_classes: int) -> dict[int, float]:
    counts = []
    for cls_dir in sorted([d for d in train_dir.iterdir() if d.is_dir()]):
        counts.append(len(list(cls_dir.glob("*"))))
    total = sum(counts)
    return {i: total / (num_classes * max(c, 1)) for i, c in enumerate(counts)}


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
    return tf.keras.Model(inputs, outputs), base_model


def load_incremental_model(num_classes: int, class_names: list[str]) -> tf.keras.Model | None:
    saved = OUTPUT_DIR / "saved_model"
    if not saved.exists():
        return None
    try:
        model = tf.keras.models.load_model(saved)
        out_dim = model.output_shape[-1]
        if out_dim != num_classes:
            print(
                f"  Incremental skip: saved model has {out_dim} classes, "
                f"dataset has {num_classes}"
            )
            return None
        print(f"  Loaded incremental model from {saved}")
        return model
    except (OSError, ValueError) as e:
        print(f"  Could not load incremental model: {e}")
        return None


def evaluate(model, ds) -> tuple[float, float]:
    results = model.evaluate(ds, verbose=0)
    loss = float(results[0])
    acc = float(results[1]) if len(results) > 1 else 0.0
    return loss, acc


def confusion_matrix_and_report(
    model, ds, class_names: list[str]
) -> tuple[np.ndarray, dict]:
    y_true: list[int] = []
    y_pred: list[int] = []
    for images, labels in ds:
        probs = model.predict(images, verbose=0)
        preds = np.argmax(probs, axis=1)
        y_true.extend(labels.numpy().tolist())
        y_pred.extend(preds.tolist())

    n = len(class_names)
    cm = np.zeros((n, n), dtype=int)
    for t, p in zip(y_true, y_pred):
        if 0 <= t < n and 0 <= p < n:
            cm[t, p] += 1

    per_class = {}
    for i, name in enumerate(class_names):
        total = cm[i].sum()
        correct = cm[i, i] if total else 0
        per_class[name] = {
            "recall": round(correct / total, 4) if total else 0.0,
            "support": int(total),
        }

    return cm, {"per_class_recall": per_class, "total": len(y_true)}


def save_confusion_matrix_png(cm: np.ndarray, class_names: list[str], path: Path) -> None:
    try:
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(8, 6))
        im = ax.imshow(cm, cmap="Blues")
        ax.set_xticks(range(len(class_names)))
        ax.set_yticks(range(len(class_names)))
        ax.set_xticklabels(class_names, rotation=45, ha="right")
        ax.set_yticklabels(class_names)
        ax.set_xlabel("Predicted")
        ax.set_ylabel("True")
        plt.colorbar(im, ax=ax)
        for i in range(cm.shape[0]):
            for j in range(cm.shape[1]):
                ax.text(j, i, int(cm[i, j]), ha="center", va="center", color="black")
        fig.tight_layout()
        path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(path, dpi=120)
        plt.close(fig)
    except ImportError:
        print("  matplotlib not installed — skipping confusion matrix PNG")


def train(*, deploy_to_app: bool = True, output_prefix: str = "model") -> dict:
    cfg = load_config()
    train_dir = DATASET_DIR / "train"
    if not train_dir.exists():
        raise FileNotFoundError(f"No {train_dir}. Run dataset_manager.py first.")

    class_names = sorted(
        [d.name for d in train_dir.iterdir() if d.is_dir()],
        key=lambda x: int(x.split("_")[0]),
    )
    num_classes = len(class_names)
    if num_classes < 2:
        raise RuntimeError("Need at least 2 classes to train.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    train_ds = map_dataset(create_datasets(class_names, "train"), training=True)
    val_ds = map_dataset(create_datasets(class_names, "val"), training=False)
    test_dir = DATASET_DIR / "test"
    test_ds = None
    if test_dir.exists() and any(test_dir.iterdir()):
        test_ds = map_dataset(create_datasets(class_names, "test"), training=False)

    class_weight = class_weights_from_dir(train_dir, num_classes)
    print(f"Classes ({num_classes}): {class_names}")

    incremental = cfg.get("incremental_learning", True)
    model = load_incremental_model(num_classes, class_names) if incremental else None
    base_model = None
    if model is None:
        model, base_model = build_model(num_classes)
        lr_head = 1e-3
    else:
        lr_head = 5e-4

    model.compile(
        optimizer=tf.keras.optimizers.Adam(lr_head),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=8,
            restore_best_weights=True,
            mode="max",
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=4, min_lr=1e-6
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

    if base_model is not None:
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
    test_acc = None
    test_loss = None
    if test_ds is not None:
        test_loss, test_acc = evaluate(model, test_ds)

    cm, report = confusion_matrix_and_report(model, val_ds, class_names)
    cm_path = OUTPUT_DIR / "confusion_matrix.png"
    save_confusion_matrix_png(cm, class_names, cm_path)

    saved_model_dir = OUTPUT_DIR / "saved_model"
    if saved_model_dir.exists():
        shutil.rmtree(saved_model_dir)
    model.save(saved_model_dir)

    labels_path = OUTPUT_DIR / "labels.txt"
    labels_path.write_text("\n".join(class_names) + "\n", encoding="utf-8")

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_bytes = converter.convert()
    tflite_path = OUTPUT_DIR / f"{output_prefix}.tflite"
    tflite_path.write_bytes(tflite_bytes)

    meta = {
        "trained": True,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "val_accuracy": round(val_acc, 4),
        "val_loss": round(val_loss, 4),
        "test_accuracy": round(test_acc, 4) if test_acc is not None else None,
        "test_loss": round(test_loss, 4) if test_loss is not None else None,
        "classes": class_names,
        "train_images": sum(len(list((train_dir / c).glob("*"))) for c in class_names),
        "val_images": sum(
            len(list((DATASET_DIR / "val" / c).glob("*"))) for c in class_names
        ),
        "confusion_matrix": cm.tolist(),
        "classification_report": report,
        "incremental": incremental and (OUTPUT_DIR / "saved_model").exists(),
    }
    meta_path = OUTPUT_DIR / f"{output_prefix}_metadata.json"
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    if deploy_to_app and output_prefix == "model":
        app_model = PROJECT_ROOT / "assets" / "model" / "model.tflite"
        app_labels = PROJECT_ROOT / "assets" / "labels" / "labels.txt"
        app_meta = PROJECT_ROOT / "assets" / "model" / "training_metadata.json"
        shutil.copy2(tflite_path, app_model)
        shutil.copy2(labels_path, app_labels)
        shutil.copy2(meta_path, app_meta)

    print(f"\nVal accuracy: {val_acc * 100:.1f}%")
    if test_acc is not None:
        print(f"Test accuracy: {test_acc * 100:.1f}%")
    print(f"TFLite: {tflite_path}")
    return meta


if __name__ == "__main__":
    train()
