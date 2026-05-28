/// Thresholds for continuous learning (Firestore + local retrain pipeline).
abstract final class ContinuousLearningConfig {
  /// Minimum 0–1 quality score to mirror into training collection.
  static const double minTrainingQualityScore = 0.55;

  /// Skip training mirror when prediction confidence is below this.
  static const double minConfidenceForTrainingMirror = 0.35;

  /// Firebase Storage paths (must match Python upload_model.py).
  static const String capturesStoragePrefix = 'captures';
  static const String trainingQueuePrefix = 'training_queue';
  static const String productionModelPath = 'models/production/model.tflite';
  static const String productionLabelsPath = 'models/production/labels.txt';
  static const String productionMetadataPath =
      'models/production/training_metadata.json';

  /// Firestore doc tracking server-side retrain state.
  static const String pipelineStateDoc = 'ml_pipeline/state';
}
