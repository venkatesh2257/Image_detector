import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'inference_logger.dart';
import 'milk_production_scale.dart';

/// On-device milk-yield classification using `assets/model/model.tflite`.
class TfliteClassifierService {
  static const String modelAsset = 'assets/model/model.tflite';
  static const String labelsAsset = 'assets/labels/labels.txt';
  static const int defaultInputSize = 224;
  static const double minConfidence = 0.25;

  Interpreter? _interpreter;
  List<String> _labels = [];
  String? _loadError;
  int _loadMs = 0;
  List<int> _inputShape = [];
  List<int> _outputShape = [];

  bool get isLoaded => _interpreter != null && _labels.isNotEmpty;
  String? get loadError => _loadError;
  List<String> get labels => List.unmodifiable(_labels);
  List<int> get inputTensorShape => List.unmodifiable(_inputShape);
  List<int> get outputTensorShape => List.unmodifiable(_outputShape);
  int get lastLoadMs => _loadMs;
  bool get interpreterAllocated => _interpreter != null;

  Future<bool> load({String? modelFilePath, String? labelsFilePath}) async {
    await close();
    final sw = Stopwatch()..start();
    final modelSource = modelFilePath ?? modelAsset;
    InferenceLogger.log('TFLite', 'load() started → $modelSource');

    try {
      _labels = await _loadLabels(labelsFilePath: labelsFilePath);
      InferenceLogger.proof(
        'labels.txt readable',
        _labels.isNotEmpty,
        detail: '${_labels.length} classes: ${_labels.join(", ")}',
      );
      if (_labels.isEmpty) {
        _loadError = 'No labels found';
        InferenceLogger.log('TFLite', 'ABORT: empty labels');
        return false;
      }

      if (modelFilePath != null) {
        InferenceLogger.log('TFLite', 'Interpreter.fromFile($modelFilePath)');
        _interpreter = Interpreter.fromFile(File(modelFilePath));
      } else {
        InferenceLogger.log('TFLite', 'Interpreter.fromAsset($modelAsset)');
        _interpreter = await Interpreter.fromAsset(modelAsset);
      }
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      final inputType = _interpreter!.getInputTensor(0).type;
      final outputType = _interpreter!.getOutputTensor(0).type;

      _loadMs = sw.elapsedMilliseconds;
      _loadError = null;

      InferenceLogger.proof('Interpreter.fromAsset', true);
      InferenceLogger.proof('interpreter != null', _interpreter != null);
      InferenceLogger.log('TFLite', 'Input  shape=$_inputShape type=$inputType');
      InferenceLogger.log('TFLite', 'Output shape=$_outputShape type=$outputType');
      InferenceLogger.log('TFLite', 'Load completed in ${_loadMs}ms');
      InferenceLogger.banner('TFLite READY', '${_labels.length} classes');

      return true;
    } catch (e, st) {
      _loadMs = sw.elapsedMilliseconds;
      _loadError =
          'Could not load $modelAsset. Run training/export_bootstrap_model.py. ($e)';
      InferenceLogger.proof('Interpreter.fromAsset', false, detail: '$e');
      InferenceLogger.log('TFLite', 'Stack: $st');
      await close();
      return false;
    }
  }

  Future<void> close() async {
    if (_interpreter != null) {
      InferenceLogger.log('TFLite', 'Closing interpreter');
    }
    _interpreter?.close();
    _interpreter = null;
    _labels = [];
    _inputShape = [];
    _outputShape = [];
  }

  Future<TflitePrediction> classify(String imagePath) async {
    final interpreter = _interpreter;
    if (interpreter == null || _labels.isEmpty) {
      InferenceLogger.log('TFLite', 'classify() blocked — interpreter not loaded');
      throw StateError('TFLite model is not loaded');
    }

    final sw = Stopwatch()..start();
    InferenceLogger.log('TFLite', 'classify() image=$imagePath');
    InferenceLogger.proof('interpreter allocated before run', true);

    final file = File(imagePath);
    InferenceLogger.proof('image file exists', file.existsSync(), detail: imagePath);

    final image = _loadAndResize(imagePath);
    InferenceLogger.log(
      'TFLite',
      'Preprocessed ${image.width}x${image.height} (MobileNetV2 -1..1)',
    );

    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    final input = _buildInput(image, inputShape);
    // Batch output [1, numClasses] — flat List<double> reshape can miss copyTo.
    final classCount = outputShape.length >= 2
        ? outputShape.last
        : outputShape.reduce((a, b) => a * b);
    final output = [List<double>.filled(classCount, 0.0)];

    InferenceLogger.log(
      'TFLite',
      '>>> interpreter.run() START (proof: real tensor inference)',
    );
    interpreter.run(input, output);
    InferenceLogger.log('TFLite', '<<< interpreter.run() DONE');

    final inferenceMs = sw.elapsedMilliseconds;
    final raw = output.first;
    InferenceLogger.log(
      'TFLite',
      'Raw logits: ${raw.map((v) => v.toStringAsFixed(6)).join(", ")}',
    );
    final probabilities = _toProbabilities(raw);
    final bestIndex = _argMax(probabilities);
    final confidence = probabilities[bestIndex].clamp(0.0, 1.0);
    final label = _labels[bestIndex.clamp(0, _labels.length - 1)];
    final allScores = _scoresMap(probabilities);
    final expectedLiters = expectedLitersFromScores(allScores);

    InferenceLogger.proof('interpreter.run() executed', true, detail: '${inferenceMs}ms');
    InferenceLogger.log(
      'TFLite',
      'Argmax index=$bestIndex label=$label confidence=${(confidence * 100).toStringAsFixed(2)}%',
    );
    InferenceLogger.scores('TFLite softmax output', allScores);

    final lowConfidence = confidence < minConfidence;
    if (lowConfidence) {
      InferenceLogger.log(
        'TFLite',
        'Low confidence (< ${(minConfidence * 100).toStringAsFixed(0)}%) — retrain recommended',
      );
    }

    return TflitePrediction(
      label: label,
      confidence: confidence,
      litersPerDay: expectedLiters ?? litersFromLabel(label),
      expectedLiters: expectedLiters,
      lowConfidence: lowConfidence,
      allScores: allScores,
      inferenceMs: inferenceMs,
      inputTensorShape: List.from(inputShape),
      outputTensorShape: List.from(outputShape),
    );
  }

  static double? litersFromLabel(String label) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(label);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// Softmax-weighted liters (smoother than argmax class).
  static double? expectedLitersFromScores(Map<String, double> scores) {
    if (scores.isEmpty) return null;
    var weighted = 0.0;
    var mass = 0.0;
    for (final e in scores.entries) {
      final liters = litersFromLabel(e.key);
      if (liters == null) continue;
      weighted += e.value * liters;
      mass += e.value;
    }
    if (mass <= 0) return null;
    return MilkProductionScale.clamp(weighted / mass);
  }

  static String displayLabel(String label) {
    final liters = litersFromLabel(label);
    if (liters == null) return label;
    return MilkProductionScale.formatExact(liters);
  }

  Future<List<String>> _loadLabels({String? labelsFilePath}) async {
    final String raw;
    if (labelsFilePath != null) {
      raw = await File(labelsFilePath).readAsString();
    } else {
      raw = await rootBundle.loadString(labelsAsset);
    }
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  img.Image _loadAndResize(String imagePath) {
    final bytes = File(imagePath).readAsBytesSync();
    InferenceLogger.log('TFLite', 'Read ${bytes.length} bytes from disk');
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw FormatException('Could not decode image: $imagePath');
    }
    InferenceLogger.log(
      'TFLite',
      'Decoded ${decoded.width}x${decoded.height} → resize to ${_inputEdgeSize()}',
    );

    final inputSize = _inputEdgeSize();
    return img.copyResize(
      decoded,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
  }

  int _inputEdgeSize() {
    final shape = _interpreter?.getInputTensor(0).shape;
    if (shape == null || shape.length < 3) return defaultInputSize;
    if (shape.length == 4) return shape[1];
    return shape[0];
  }

  Object _buildInput(img.Image image, List<int> inputShape) {
    final height = image.height;
    final width = image.width;
    final isNhwc = inputShape.length == 4;

    if (isNhwc) {
      return List.generate(
        1,
        (_) => List.generate(
          height,
          (y) => List.generate(
            width,
            (x) {
              final pixel = image.getPixel(x, y);
              return [
                _preprocessChannel(pixel.r),
                _preprocessChannel(pixel.g),
                _preprocessChannel(pixel.b),
              ];
            },
          ),
        ),
      );
    }

    final flat = List<double>.filled(height * width * 3, 0);
    var i = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        flat[i++] = _preprocessChannel(pixel.r);
        flat[i++] = _preprocessChannel(pixel.g);
        flat[i++] = _preprocessChannel(pixel.b);
      }
    }
    return flat.reshape(inputShape);
  }

  double _preprocessChannel(num channel) => (channel.toDouble() / 127.5) - 1.0;

  /// Softmax if outputs are logits; pass through if already probabilities.
  List<double> _toProbabilities(List<double> values) {
    if (values.isEmpty) return values;
    final sum = values.fold<double>(0, (a, b) => a + b);
    if (sum > 0.99 && sum < 1.01 && values.every((v) => v >= 0)) {
      return values;
    }
    final maxLogit = values.reduce((a, b) => a > b ? a : b);
    final exps = values.map((v) => math.exp(v - maxLogit)).toList();
    final expSum = exps.fold<double>(0, (a, b) => a + b);
    if (expSum == 0) return List.filled(values.length, 1.0 / values.length);
    return exps.map((e) => e / expSum).toList();
  }

  int _argMax(List<double> values) {
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }

  Map<String, double> _scoresMap(List<double> probabilities) {
    final map = <String, double>{};
    for (var i = 0; i < probabilities.length && i < _labels.length; i++) {
      map[_labels[i]] = probabilities[i];
    }
    return map;
  }
}

class TflitePrediction {
  final String label;
  final double confidence;
  final double? litersPerDay;
  /// Probability-weighted liters (preferred over argmax class).
  final double? expectedLiters;
  final bool lowConfidence;
  final Map<String, double> allScores;
  final int inferenceMs;
  final List<int> inputTensorShape;
  final List<int> outputTensorShape;

  const TflitePrediction({
    required this.label,
    required this.confidence,
    required this.litersPerDay,
    this.expectedLiters,
    required this.lowConfidence,
    required this.allScores,
    required this.inferenceMs,
    required this.inputTensorShape,
    required this.outputTensorShape,
  });
}
