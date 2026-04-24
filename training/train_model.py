from pathlib import Path

import tensorflow as tf

IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS_HEAD = 10
EPOCHS_FINETUNE = 5
DATASET_DIR = Path("datasets")
OUTPUT_DIR = Path("output")


def create_datasets():
  train_ds = tf.keras.utils.image_dataset_from_directory(
      DATASET_DIR / "train",
      image_size=(IMG_SIZE, IMG_SIZE),
      batch_size=BATCH_SIZE,
  )
  val_ds = tf.keras.utils.image_dataset_from_directory(
      DATASET_DIR / "val",
      image_size=(IMG_SIZE, IMG_SIZE),
      batch_size=BATCH_SIZE,
  )

  autotune = tf.data.AUTOTUNE
  train_ds = train_ds.prefetch(autotune)
  val_ds = val_ds.prefetch(autotune)
  return train_ds, val_ds


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
  model = tf.keras.Model(inputs, outputs)
  return model, base_model


def train():
  train_ds, val_ds = create_datasets()
  class_names = sorted([d.name for d in (DATASET_DIR / 'train').iterdir() if d.is_dir()])
  num_classes = len(class_names)
  OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

  model, base_model = build_model(num_classes)
  model.compile(
      optimizer="adam",
      loss="sparse_categorical_crossentropy",
      metrics=["accuracy"],
  )
  model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD)

  base_model.trainable = True
  for layer in base_model.layers[:-30]:
    layer.trainable = False

  model.compile(
      optimizer=tf.keras.optimizers.Adam(1e-5),
      loss="sparse_categorical_crossentropy",
      metrics=["accuracy"],
  )
  model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINETUNE)

  saved_model_dir = OUTPUT_DIR / "saved_model"
  model.save(saved_model_dir)

  with open(OUTPUT_DIR / "labels.txt", "w", encoding="utf-8") as labels_file:
    for name in class_names:
      labels_file.write(f"{name}\n")

  converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
  tflite_model = converter.convert()
  with open(OUTPUT_DIR / "model.tflite", "wb") as model_file:
    model_file.write(tflite_model)

  print("Training complete.")
  print("Generated:")
  print(f"- {OUTPUT_DIR / 'model.tflite'}")
  print(f"- {OUTPUT_DIR / 'labels.txt'}")


if __name__ == "__main__":
  train()
