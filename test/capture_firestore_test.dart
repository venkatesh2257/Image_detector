import 'package:flutter_test/flutter_test.dart';
import 'package:image_detector/models/capture_record.dart';
import 'package:image_detector/services/capture_firestore_service.dart';
import 'package:image_detector/services/classifier_service_new.dart';
import 'package:image_detector/services/inference_logger.dart';

InferenceDiagnostics _minimalDiagnostics({String rawTfliteLabel = ''}) {
  return InferenceDiagnostics(
    sessionId: 'test',
    tfliteModelLoaded: true,
    tfliteInterpreterAllocated: true,
    rulesGateRan: true,
    rulesGatePassed: true,
    tfliteInferenceExecuted: true,
    predictionSource: 'tflite',
    tfliteModelAsset: 'assets/model/model.tflite',
    labelClasses: const ['6_lit', '8_lit'],
    inputTensorShape: const [1, 224, 224, 3],
    outputTensorShape: const [1, 5],
    rawTfliteLabel: rawTfliteLabel,
    tfliteConfidence: 0.8,
    tfliteAllScores: const {'8_lit': 0.8},
    tfliteLoadMs: 1,
    tfliteInferenceMs: 2,
    rulesGateMs: 3,
    logLines: const [],
  );
}

void main() {
  group('CaptureTrainingLabel', () {
    test('rules gate rejection maps to rejected', () {
      final label = CaptureTrainingLabel.fromPrediction(
        PredictionResult(
          label: 'No Buffalo Detected',
          confidence: 1,
          predictionSource: 'rules_gate',
        ),
      );
      expect(label, 'rejected');
    });

    test('uses TFLite raw class when present', () {
      final label = CaptureTrainingLabel.fromPrediction(
        PredictionResult(
          label: '8 L/day',
          confidence: 0.8,
          estimatedLiters: 8.2,
          predictionSource: 'milk_mirror+tflite',
          diagnostics: _minimalDiagnostics(rawTfliteLabel: '8_lit'),
        ),
      );
      expect(label, '8_lit');
    });

    test('falls back to liter bucket from estimatedLiters', () {
      final label = CaptureTrainingLabel.fromPrediction(
        PredictionResult(
          label: '9.4 L/day',
          confidence: 0.7,
          estimatedLiters: 9.4,
          predictionSource: 'milk_mirror',
        ),
      );
      expect(label, '9_lit');
    });
  });

  group('CaptureRecord paths', () {
    test('documents Firestore collection layout', () {
      expect(
        CaptureRecord.collectionPath(),
        'captures/{captureId}',
      );
      expect(
        CaptureRecord.trainingPath('8_lit', 'cap_123'),
        'training_assets/8_lit/samples/cap_123',
      );
    });
  });
}
