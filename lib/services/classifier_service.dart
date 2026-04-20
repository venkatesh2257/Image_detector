import 'dart:math';

import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionResult {
  PredictionResult({
    required this.label,
    required this.confidence,
    required this.hashtags,
  });

  final String label;
  final double confidence;
  final List<String> hashtags;
}

class ClassifierService {
  Interpreter? _interpreter;

  final List<String> _fallbackLabels = [
    'Nature Object',
    'Urban Item',
    'Food Object',
    'Animal',
    'Fashion Item',
  ];

  final Map<String, List<String>> _tagMap = {
    'Nature Object': ['#nature', '#green', '#outdoor'],
    'Urban Item': ['#city', '#street', '#trend'],
    'Food Object': ['#food', '#fresh', '#yummy'],
    'Animal': ['#wildlife', '#cute', '#petlove'],
    'Fashion Item': ['#style', '#fashion', '#ootd'],
  };

  Future<bool> loadModel() async {
    try {
      _interpreter ??= await Interpreter.fromAsset('model/model.tflite');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PredictionResult> classifyImage(String imagePath) async {
    if (_interpreter == null) {
      return _demoPrediction(imagePath);
    }

    // Placeholder route while waiting for model-specific preprocessing.
    // The app still works in real-time; replace this with your tensor pipeline
    // once dataset classes and input shape are finalized.
    return _demoPrediction(imagePath);
  }

  PredictionResult _demoPrediction(String imagePath) {
    final seed = imagePath.codeUnits.fold<int>(0, (prev, e) => prev + e);
    final random = Random(seed);
    final label = _fallbackLabels[random.nextInt(_fallbackLabels.length)];
    final confidence = 0.72 + (random.nextDouble() * 0.27);

    return PredictionResult(
      label: label,
      confidence: confidence.clamp(0.0, 0.99),
      hashtags: _tagMap[label] ?? ['#ai', '#vision', '#trending'],
    );
  }
}
