"""Export a TFLite model matching train_model.py architecture for app integration.

Use after real training with train_model.py when you have labeled photos.
This script is for bootstrapping only (untrained weights) so the Flutter app
can load and run inference before the first training run.
"""

from pathlib import Path

import tensorflow as tf

IMG_SIZE = 224
LABELS = ["6_lit", "7_lit", "8_lit", "9_lit", "10_lit"]
PROJECT_ROOT = Path(__file__).resolve().parents[1]
ASSETS_MODEL = PROJECT_ROOT / "assets" / "model" / "model.tflite"
ASSETS_LABELS = PROJECT_ROOT / "assets" / "labels" / "labels.txt"


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
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    return tf.keras.Model(inputs, outputs)


def main():
    num_classes = len(LABELS)
    model = build_model(num_classes)

    saved_dir = Path("output") / "bootstrap_saved_model"
    saved_dir.mkdir(parents=True, exist_ok=True)
    model.save(saved_dir)

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_dir))
    tflite_bytes = converter.convert()

    ASSETS_MODEL.parent.mkdir(parents=True, exist_ok=True)
    ASSETS_MODEL.write_bytes(tflite_bytes)

    ASSETS_LABELS.parent.mkdir(parents=True, exist_ok=True)
    ASSETS_LABELS.write_text("\n".join(LABELS) + "\n", encoding="utf-8")

    print("Bootstrap export complete (ImageNet backbone, untrained head).")
    print(f"- {ASSETS_MODEL} ({len(tflite_bytes) / 1024 / 1024:.1f} MB)")
    print(f"- {ASSETS_LABELS}")
    print("Retrain with train_model.py when you have labeled buffalo photos.")


if __name__ == "__main__":
    main()
