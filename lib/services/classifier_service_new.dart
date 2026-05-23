import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'inference_logger.dart';
import '../models/dairy_pipeline_report.dart';
import 'dairy_pipeline_builder.dart';
import 'milk_mirror_measurement_service.dart';
import 'rear_anatomy_detector.dart';
import 'sex_classifier_service.dart';
import 'crop_species_gate_service.dart';
import 'tflite_classifier_service.dart';
import 'udder_escutcheon_crop_service.dart';
import 'yield_fusion_service.dart';

class PredictionResult {
  final String label;
  final double confidence;
  final List<String> hashtags;
  final double estimatedLiters;
  final List<Offset> keypoints;
  /// What produced the shown label: `tflite`, `rules_gate`, `error`, `not_loaded`.
  final String predictionSource;
  final InferenceDiagnostics? diagnostics;
  final MilkMirrorUiMetrics? milkMirror;
  final DairyPipelineReport? pipeline;

  PredictionResult({
    required this.label,
    required this.confidence,
    this.hashtags = const [],
    this.estimatedLiters = 0.0,
    this.keypoints = const [],
    this.predictionSource = 'unknown',
    this.diagnostics,
    this.milkMirror,
    this.pipeline,
  });
}

class BuffaloAnalysisResult {
  final String status;
  final String? reason;
  final double confidence;
  final String animal;
  final Map<String, dynamic>? features;
  final Map<String, dynamic>? prediction;
  final List<Offset> keypoints;

  BuffaloAnalysisResult({
    required this.status,
    this.reason,
    required this.confidence,
    required this.animal,
    this.features,
    this.prediction,
    this.keypoints = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (reason != null) 'reason': reason,
      'confidence': confidence,
      'animal': animal,
      if (features != null) 'features': features,
      if (prediction != null) 'prediction': prediction,
    };
  }
}

class ClassifierService {
  /// Phase A: set true to block non-buffalo on escutcheon crop.
  static const bool enforceCropSpeciesGate = false;

  final VeterinaryBuffaloDetector _detector = VeterinaryBuffaloDetector();
  final TfliteClassifierService _tflite = TfliteClassifierService();
  final MilkMirrorMeasurementService _milkMirror = MilkMirrorMeasurementService();
  final DairyPipelineBuilder _pipelineBuilder = DairyPipelineBuilder();
  final UdderEscutcheonCropService _cropService = UdderEscutcheonCropService();
  final YieldFusionService _yieldFusion = YieldFusionService();
  final CropSpeciesGateService _cropSpecies = CropSpeciesGateService();

  String? _modelLoadError;
  InferenceDiagnostics? _lastDiagnostics;

  bool get isTfliteReady => _tflite.isLoaded;
  String? get modelLoadError => _modelLoadError;
  InferenceDiagnostics? get lastDiagnostics => _lastDiagnostics;

  bool _tfliteTrained = false;
  double _tfliteValAccuracy = 0.0;

  bool get isTfliteTrained => _tfliteTrained;

  Future<bool> loadModel() async {
    InferenceLogger.banner('APP START — MODEL INIT');
    InferenceLogger.log('Classifier', 'loadModel() called');

    await _milkMirror.ensureCalibrationLoaded();
    final loaded = await _tflite.load();
    _modelLoadError = loaded ? null : _tflite.loadError;
    await _loadTrainingMetadata();

    InferenceLogger.proof('TFLite model loaded', loaded, detail: _modelLoadError);
    InferenceLogger.proof('Interpreter allocated', _tflite.interpreterAllocated);
    if (loaded) {
      InferenceLogger.log(
        'Classifier',
        'Classes (${_tflite.labels.length}): ${_tflite.labels.join(", ")}',
      );
      InferenceLogger.log(
        'Classifier',
        'Tensors in=${_tflite.inputTensorShape} out=${_tflite.outputTensorShape}',
      );
    }
    InferenceLogger.banner(loaded ? 'MODEL INIT OK' : 'MODEL INIT FAILED');

    return loaded;
  }

  Future<void> _loadTrainingMetadata() async {
    try {
      final raw = await rootBundle.loadString('assets/model/training_metadata.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _tfliteTrained = map['trained'] == true;
      _tfliteValAccuracy = (map['val_accuracy'] as num?)?.toDouble() ?? 0.0;
      if (_tfliteTrained) {
        InferenceLogger.log(
          'Classifier',
          'Trained TFLite loaded (val accuracy ${(_tfliteValAccuracy * 100).toStringAsFixed(1)}%)',
        );
      }
    } catch (_) {
      _tfliteTrained = false;
      _tfliteValAccuracy = 0.0;
    }
  }

  Future<PredictionResult> classifyImage(
    String imagePath, {
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) async {
    final sessionId = InferenceLogger.startSession('classifyImage');
    InferenceLogger.log('Classifier', 'image=$imagePath breed=$breed age=$age');

    if (!_tflite.isLoaded) {
      InferenceLogger.log('Classifier', 'BLOCKED — TFLite not loaded');
      InferenceLogger.endSession('model_not_loaded');
      _lastDiagnostics = null;
      return PredictionResult(
        label: 'AI Model Not Loaded',
        confidence: 0.0,
        hashtags: [
          _modelLoadError ??
              'Add assets/model/model.tflite and restart the app.',
        ],
        keypoints: [],
        predictionSource: 'not_loaded',
      );
    }

    var rulesGatePassed = false;
    String? rulesRejectReason;
    String predictionSource = 'unknown';
    final gateSw = Stopwatch()..start();

    try {
      InferenceLogger.banner('STEP 1 — RULES GATE (not TFLite)');
      InferenceLogger.log(
        'RULES',
        'VeterinaryBuffaloDetector.identifyBuffalo() — species & scene validation',
      );

      final gate = _detector.identifyBuffalo(
        imagePath,
        breed: breed,
        age: age,
        lactation: lactation,
        daysInMilk: daysInMilk,
        feed: feed,
      );
      final rulesGateMs = gateSw.elapsedMilliseconds;
      rulesGatePassed = gate.status == 'valid';
      rulesRejectReason = gate.reason;

      InferenceLogger.proof('Rules gate passed', rulesGatePassed, detail: gate.reason);
      InferenceLogger.log(
        'RULES',
        'status=${gate.status} confidence=${gate.confidence} animal=${gate.animal}',
      );
      if (gate.prediction != null) {
        InferenceLogger.log('RULES', 'Heuristic milk hint: ${gate.prediction}');
      }

      if (rulesGatePassed && gate.features != null) {
        final sexRefined = SexClassifierService().classifyFile(
          imagePath,
          udderKeypointDetected: gate.keypoints.length >= 3,
          udderSizeHint: gate.features!['udder_size'] as String?,
        );
        gate.features!['sex'] = sexRefined.label;
        gate.features!['sex_confidence'] = sexRefined.confidence;
        gate.features!['sex_female_prob'] = sexRefined.femaleProbability;
        gate.features!['sex_detail'] = sexRefined.detail;
        gate.features!['sex_is_bull'] = sexRefined.isBull;
        InferenceLogger.log(
          'SEX',
          'Full-res refine → ${sexRefined.label} ${(sexRefined.confidence * 100).toStringAsFixed(1)}%',
        );
      }

      if (!rulesGatePassed) {
        predictionSource = 'rules_gate';
        final diag = _buildDiagnostics(
          sessionId: sessionId,
          rulesGatePassed: false,
          rulesRejectReason: rulesRejectReason,
          tfliteRan: false,
          predictionSource: predictionSource,
          rawLabel: '',
          confidence: 0,
          allScores: const {},
          rulesGateMs: rulesGateMs,
          tfliteInferenceMs: 0,
        );
        _lastDiagnostics = diag;
        diag.printFullReport();
        InferenceLogger.endSession('rejected_by_rules');
        return PredictionResult(
          label: 'No Buffalo Detected',
          confidence: 1.0,
          hashtags: [
            'Rejected by RULES gate (TFLite did not run)',
            gate.reason ?? 'Image did not pass buffalo checks',
          ],
          keypoints: [],
          predictionSource: predictionSource,
          diagnostics: diag,
        );
      }

      InferenceLogger.banner('STEP 1b — Escutcheon crop (mandatory)');
      final escutcheonCrop = _cropService.buildCrop(imagePath);
      final inferencePath = escutcheonCrop != null && escutcheonCrop.isValid
          ? escutcheonCrop.cropPath
          : imagePath;

      if (escutcheonCrop != null && escutcheonCrop.isValid) {
        final species = _cropSpecies.analyze(
          cropPath: escutcheonCrop.cropPath,
          anatomy: escutcheonCrop.anatomy,
        );
        if (enforceCropSpeciesGate && !species.isBuffalo) {
          predictionSource = 'rules_gate';
          final diag = _buildDiagnostics(
            sessionId: sessionId,
            rulesGatePassed: false,
            rulesRejectReason: species.reason,
            tfliteRan: false,
            predictionSource: predictionSource,
            rawLabel: '',
            confidence: 0,
            allScores: const {},
            rulesGateMs: rulesGateMs,
            tfliteInferenceMs: 0,
          );
          _lastDiagnostics = diag;
          InferenceLogger.endSession('rejected_crop_species');
          return PredictionResult(
            label: 'No Buffalo Detected',
            confidence: 1.0,
            hashtags: [
              'Rejected — not a buffalo rear (crop species check)',
              species.reason,
            ],
            keypoints: [],
            predictionSource: predictionSource,
            diagnostics: diag,
          );
        }
        if (!species.isBuffalo) {
          InferenceLogger.log(
            'SPECIES_CROP',
            'Phase A preview: would reject (${(species.confidence * 100).toStringAsFixed(0)}%)',
          );
        }
      }

      InferenceLogger.banner('STEP 2 — Milk Mirror measurement (pin bones / escutcheon)');
      final mirror = _milkMirror.measureFromImage(
        imagePath,
        leftHip: _gateKeypoint(gate.keypoints, 0),
        rightHip: _gateKeypoint(gate.keypoints, 1),
        udder: _gateKeypoint(gate.keypoints, 2),
        spine: _gateKeypoint(gate.keypoints, 3),
      );

      InferenceLogger.banner('STEP 3 — TFLite on escutcheon crop');
      InferenceLogger.log(
        'Classifier',
        'TFLite input=$inferencePath (crop=${escutcheonCrop?.isValid == true})',
      );
      final ml = await _tflite.classify(inferencePath);

      InferenceLogger.banner('STEP 4 — Yield fusion (mirror + TFLite + farmer)');
      final fusion = _yieldFusion.fuse(
        YieldFusionInput(
          mirrorLiters: mirror.litersPerDay,
          mirrorConfidence: mirror.confidence,
          mirrorSuccess: mirror.success,
          tflite: ml,
          tfliteTrained: _tfliteTrained,
          tfliteValAccuracy: _tfliteValAccuracy,
          age: age,
          lactation: lactation,
          daysInMilk: daysInMilk,
          feed: feed,
          symmetryIndex: mirror.symmetryIndex,
          areaNorm: mirror.areaNorm,
        ),
      );

      final liters = fusion.litersPerDay;
      final confidence = fusion.confidence;
      final display = fusion.displayLabel;
      predictionSource = fusion.source;
      final overlayKeypoints =
          mirror.success ? mirror.keypoints : gate.keypoints;

      final rangeLabel =
          '${fusion.yieldMin.toStringAsFixed(1)} – ${fusion.yieldMax.toStringAsFixed(1)} L/day';

      final tags = <String>[
        if (escutcheonCrop?.isValid == true) '✅ Escutcheon crop used for AI',
        if (mirror.success) '✅ Measured: escutcheon A–B × C–D',
        if (mirror.success)
          'Area ${(mirror.areaNorm * 100).toStringAsFixed(0)}% · Symmetry ${((1 - mirror.symmetryIndex) * 100).toStringAsFixed(0)}%',
        'Yield range: $rangeLabel',
        'AI band: ${ml.label} (${(ml.confidence * 100).toStringAsFixed(0)}%)',
        if (fusion.status == YieldPredictionStatus.caution)
          '⚠️ CAUTION — ${fusion.detail}',
        'Session: $sessionId',
        if (!mirror.success) '⚠️ ${mirror.error}',
        if (ml.lowConfidence) '⚠️ Retake photo for a clearer rear udder view',
      ];

      final diag = _buildDiagnostics(
        sessionId: sessionId,
        rulesGatePassed: true,
        rulesRejectReason: null,
        tfliteRan: true,
        predictionSource: predictionSource,
        rawLabel: ml.label,
        confidence: confidence,
        allScores: ml.allScores,
        rulesGateMs: rulesGateMs,
        tfliteInferenceMs: ml.inferenceMs,
        inputShape: ml.inputTensorShape,
        outputShape: ml.outputTensorShape,
      );
      _lastDiagnostics = diag;
      diag.printFullReport();
      InferenceLogger.log(
        'Classifier',
        'FINAL $display liters=$liters source=$predictionSource',
      );
      InferenceLogger.endSession('success');

      final pipeline = _pipelineBuilder.build(
        gate: gate,
        mirror: mirror,
        predictionSource: predictionSource,
        displayConfidence: confidence,
        displayLabel: display,
        estimatedLiters: liters,
        tfliteBand: ml.label,
        daysInMilk: daysInMilk,
        yieldMin: fusion.yieldMin,
        yieldMax: fusion.yieldMax,
        fusionStatus: fusion.status,
      );

      return PredictionResult(
        label: display,
        confidence: confidence,
        estimatedLiters: liters,
        keypoints: overlayKeypoints,
        hashtags: tags,
        predictionSource: predictionSource,
        diagnostics: diag,
        milkMirror: mirror.success
            ? mirror.toUiMetrics(
                tfliteBand: ml.label,
                tfliteConfidence: ml.confidence,
              )
            : null,
        pipeline: pipeline,
      );
    } catch (e, st) {
      InferenceLogger.log('Classifier', 'EXCEPTION: $e');
      InferenceLogger.log('Classifier', '$st');
      InferenceLogger.endSession('error');
      return PredictionResult(
        label: 'Detection Error',
        confidence: 0.0,
        hashtags: ['Error: $e'],
        keypoints: [],
        predictionSource: 'error',
      );
    }
  }

  InferenceDiagnostics _buildDiagnostics({
    required String sessionId,
    required bool rulesGatePassed,
    required String? rulesRejectReason,
    required bool tfliteRan,
    required String predictionSource,
    required String rawLabel,
    required double confidence,
    required Map<String, double> allScores,
    required int rulesGateMs,
    required int tfliteInferenceMs,
    List<int>? inputShape,
    List<int>? outputShape,
  }) {
    return InferenceDiagnostics(
      sessionId: sessionId,
      tfliteModelLoaded: _tflite.isLoaded,
      tfliteInterpreterAllocated: _tflite.interpreterAllocated,
      rulesGateRan: true,
      rulesGatePassed: rulesGatePassed,
      tfliteInferenceExecuted: tfliteRan,
      predictionSource: predictionSource,
      rulesRejectReason: rulesRejectReason,
      tfliteModelAsset: TfliteClassifierService.modelAsset,
      labelClasses: _tflite.labels,
      inputTensorShape: inputShape ?? _tflite.inputTensorShape,
      outputTensorShape: outputShape ?? _tflite.outputTensorShape,
      rawTfliteLabel: rawLabel,
      tfliteConfidence: confidence,
      tfliteAllScores: allScores,
      tfliteLoadMs: _tflite.lastLoadMs,
      tfliteInferenceMs: tfliteInferenceMs,
      rulesGateMs: rulesGateMs,
      logLines: InferenceLogger.sessionLogSnapshot(),
    );
  }

  static Offset? _gateKeypoint(List<Offset> keypoints, int index) {
    if (index >= keypoints.length) return null;
    return keypoints[index];
  }
}

class VeterinaryBuffaloDetector {
  // 🐃 Clean Buffalo Identification Algorithm Implementation
  static const int _sampleStep = 2;
  
  BuffaloAnalysisResult identifyBuffalo(
    String imagePath, {
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) {
    InferenceLogger.log('RULES', 'identifyBuffalo() START path=$imagePath');
    debugPrint('[STEP 0] Input: $imagePath');
    
    try {
      debugPrint('[STEP 1] Preprocessing image...');
      final processedImage = _preprocessImage(imagePath);
      if (processedImage == null) {
        return _createRejectResult('Cannot process image');
      }

      final fullImage = _loadOrientedImage(imagePath);
      final anatomy = RearAnatomyDetector().detectFromPath(imagePath);
      final strongRearBuffalo = fullImage != null &&
          anatomy != null &&
          _isStrongRearBuffaloEvidence(fullImage, anatomy);

      if (strongRearBuffalo && anatomy != null && fullImage != null) {
        InferenceLogger.log(
          'RULES',
          'Strong rear buffalo evidence conf=${(anatomy.confidence * 100).toStringAsFixed(0)}% '
          'livestock=${(_torsoLivestockRatio(fullImage) * 100).toStringAsFixed(1)}%',
        );
      }

      if (fullImage != null) {
        final blockReason = _nonBuffaloPhotoReason(
          fullImage,
          trustRearAnatomy: strongRearBuffalo,
        );
        if (blockReason != null) {
          InferenceLogger.log('RULES', 'REJECT: $blockReason');
          return _createRejectResult(blockReason);
        }
        if (!strongRearBuffalo &&
            anatomy != null &&
            _landmarksOnDeviceSurface(fullImage, anatomy)) {
          const reason =
              'Not a buffalo — laptop or screen detected (not an animal rear)';
          InferenceLogger.log('RULES', 'REJECT: $reason');
          return _createRejectResult(reason);
        }
      }

      final hasAnimalRear = strongRearBuffalo ||
          (anatomy != null &&
              !anatomy.isTemplateFallback &&
              _isPlausibleRearBuffalo(anatomy) &&
              fullImage != null &&
              _hasLivestockSceneSignature(fullImage) &&
              _hasRearAnimalMass(fullImage, anatomy) &&
              !_hasHumanPhotoSignals(
                fullImage,
                trustRearAnatomy: strongRearBuffalo,
              ));

      if (!strongRearBuffalo) {
        final objectOnPreview = _detectObjects(processedImage);
        if (objectOnPreview['rejected'] == true) {
          final reason = objectOnPreview['reason'] as String? ?? '';
          final isHuman = reason.toLowerCase().contains('human');
          if (isHuman || !hasAnimalRear) {
            InferenceLogger.log('RULES', 'REJECT: $reason');
            return _createRejectResult(reason);
          }
        }
      }

      final rearBuffalo = hasAnimalRear;

      late final Map<String, dynamic> keypoints;
      late final double buffaloProb;
      late final Map<String, dynamic> visualValidation;

      if (rearBuffalo && anatomy != null) {
        InferenceLogger.log(
          'RULES',
          'Rear anatomy OK conf=${(anatomy.confidence * 100).toStringAsFixed(0)}% '
          'L=${anatomy.leftPin} U=${anatomy.udder}',
        );
        keypoints = {
          'rejected': false,
          'confidence': anatomy.confidence,
          'spine': anatomy.pointA,
          'leftHip': anatomy.leftPin,
          'rightHip': anatomy.rightPin,
          'udder': anatomy.udder,
        };
        buffaloProb = math.max(0.80, _calculateBuffaloProbability(processedImage));
        visualValidation = _validateVisualQuality(processedImage);
        if (visualValidation['rejected'] == true) {
          InferenceLogger.log('RULES', 'REJECT step 4: ${visualValidation['reason']}');
          return _createRejectResult(visualValidation['reason']);
        }
      } else {
        debugPrint('[STEP 2] Fallback rules (no rear anatomy)...');
        final objectDetection = _detectObjects(processedImage);
        if (objectDetection['rejected'] == true) {
          InferenceLogger.log('RULES', 'REJECT step 2: ${objectDetection['reason']}');
          return _createRejectResult(objectDetection['reason']);
        }

        final classification = _classifySpecies(processedImage);
        if (classification['rejected'] == true) {
          InferenceLogger.log('RULES', 'REJECT step 3: ${classification['reason']}');
          return _createRejectResult(classification['reason']);
        }
        buffaloProb = classification['buffalo_prob'] as double;

        visualValidation = _validateVisualQuality(processedImage);
        if (visualValidation['rejected'] == true) {
          InferenceLogger.log('RULES', 'REJECT step 4: ${visualValidation['reason']}');
          return _createRejectResult(visualValidation['reason']);
        }

        keypoints = _detectKeypointsFullImage(imagePath, processedImage);
        if (keypoints['rejected'] == true) {
          InferenceLogger.log('RULES', 'REJECT step 5: ${keypoints['reason']}');
          return _createRejectResult(keypoints['reason']);
        }
      }

      debugPrint('[STEP 6] Structural validation...');
      final structuralValidation = _validateStructure(keypoints);
      if (structuralValidation['rejected'] == true) {
        InferenceLogger.log('RULES', 'REJECT step 6: ${structuralValidation['reason']}');
        return _createRejectResult(structuralValidation['reason']);
      }

      debugPrint('[STEP 7] Confidence scoring...');
      final confidence = _calculateFinalConfidence(
        buffaloProb,
        keypoints['confidence'] as double,
        visualValidation['quality_score'] as double,
      );

      final minConfidence = rearBuffalo ? 0.48 : 0.58;
      if (confidence < minConfidence) {
        InferenceLogger.log('RULES', 'REJECT step 7: low confidence ${(confidence * 100).toStringAsFixed(1)}%');
        return _createRejectResult('Low confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      }
      
      // 🔹 Step 7b: Sex classification (rear udder vs bull)
      debugPrint('[STEP 7b] Sex classification...');
      final preFeatures = _extractFeatures(processedImage);
      final sex = SexClassifierService().classifyImage(
        processedImage,
        udderKeypointDetected: keypoints['udder'] != null,
        udderSizeHint: preFeatures['udder_size'] as String?,
      );
      debugPrint(
        '[SEX] ${sex.label} ${(sex.confidence * 100).toStringAsFixed(1)}% — ${sex.detail}',
      );

      // 🔹 Step 8: Final Output
      debugPrint('[STEP 8] Final output...');
      final features = preFeatures;
      features['buffalo_prob'] = buffaloProb;
      features['sex'] = sex.label;
      features['sex_confidence'] = sex.confidence;
      features['sex_female_prob'] = sex.femaleProbability;
      features['sex_detail'] = sex.detail;
      features['sex_is_bull'] = sex.isBull;
      final prediction = _predictMilkProduction(features, breed, age, lactation, daysInMilk, feed);
      
      InferenceLogger.log('RULES', 'PASS — all 8 steps OK, handing off to Milk Mirror + TFLite');
      final kp = <Offset>[
        if (keypoints['leftHip'] != null) keypoints['leftHip'] as Offset,
        if (keypoints['rightHip'] != null) keypoints['rightHip'] as Offset,
        if (keypoints['udder'] != null) keypoints['udder'] as Offset,
        if (keypoints['spine'] != null) keypoints['spine'] as Offset,
      ];
      return BuffaloAnalysisResult(
        status: 'valid',
        confidence: confidence,
        animal: 'buffalo',
        features: features,
        prediction: prediction,
        keypoints: kp,
      );
      
    } catch (e) {
      InferenceLogger.log('RULES', 'EXCEPTION: $e');
      debugPrint('[BUFFALO DETECTION] Error: $e');
      return _createRejectResult('Analysis failed: ${e.toString()}');
    }
  }
  
  img.Image? _loadOrientedImage(String imagePath) {
    try {
      final bytes = File(imagePath).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return img.bakeOrientation(decoded);
    } catch (_) {
      return null;
    }
  }

  /// High-confidence rear buffalo: anatomy + hide mass + farm scene (not a screen).
  bool _isStrongRearBuffaloEvidence(
    img.Image image,
    RearAnatomyLandmarks anatomy,
  ) {
    if (anatomy.isTemplateFallback) return false;
    if (!_isPlausibleRearBuffalo(anatomy)) return false;
    if (anatomy.confidence < 0.55) return false;
    if (_torsoLivestockRatio(image) < 0.15) return false;
    if (!_hasRearAnimalMass(image, anatomy)) return false;
    if (_isObviousNonLivestock(image)) return false;
    if (_isStrongElectronicDeviceScene(image)) return false;
    if (_isElectronicDeviceScene(image) && _torsoLivestockRatio(image) < 0.22) {
      return false;
    }
    return true;
  }

  /// Human, phone, laptop, screen, or other non-buffalo scenes (always enforced).
  String? _nonBuffaloPhotoReason(
    img.Image image, {
    bool trustRearAnatomy = false,
  }) {
    if (_isHandOrPhoneScene(image)) {
      return 'Not a buffalo — phone or hand photo detected';
    }
    if (!trustRearAnatomy && _hasHumanPhotoSignals(image)) {
      return 'Human detected — photograph the buffalo rear only, not people';
    }
    if (_isStrongElectronicDeviceScene(image)) {
      return 'Not a buffalo — laptop, phone screen, or device detected';
    }
    if (!trustRearAnatomy &&
        _isElectronicDeviceScene(image) &&
        !_hasLivestockSceneSignature(image)) {
      return 'Not a buffalo — laptop, phone screen, or device detected';
    }
    if (!trustRearAnatomy && _isObviousNonLivestock(image)) {
      return 'Not a buffalo — use a rear photo of the animal, not a screen or object';
    }
    if (!trustRearAnatomy && !_hasLivestockSceneSignature(image)) {
      return 'Not a buffalo — no farm animal detected in this photo';
    }
    return null;
  }

  double _torsoLivestockRatio(img.Image image) {
    final w = image.width;
    final h = image.height;
    var organic = 0;
    var grass = 0;
    var samples = 0;
    final yStart = (h * 0.20).round();
    final yEnd = (h * 0.72).round();
    final xStart = (w * 0.14).round();
    final xEnd = (w * 0.86).round();

    for (var y = yStart; y < yEnd; y += _sampleStep) {
      for (var x = xStart; x < xEnd; x += _sampleStep) {
        samples++;
        final p = image.getPixel(x, y);
        if (_isOrganicLivestockPixel(p)) organic++;
        if (_isGrassOrMudPixel(p)) grass++;
      }
    }
    if (samples == 0) return 0;
    return (organic + grass) / samples;
  }

  /// Farm animal rear scene: organic hide in central torso band (not floor/wall).
  bool _hasLivestockSceneSignature(img.Image image) {
    if (_isElectronicDeviceScene(image) && _torsoLivestockRatio(image) < 0.14) {
      return false;
    }

    final signature = _torsoLivestockRatio(image);
    InferenceLogger.log(
      'RULES',
      'Livestock torso signature=${(signature * 100).toStringAsFixed(1)}%',
    );
    return signature >= 0.16;
  }

  bool _landmarksOnDeviceSurface(img.Image image, RearAnatomyLandmarks anatomy) {
    if (_isStrongRearBuffaloEvidence(image, anatomy)) return false;
    if (_torsoLivestockRatio(image) >= 0.18) return false;

    final w = image.width;
    final h = image.height;
    final points = [anatomy.pointA, anatomy.leftPin, anatomy.rightPin, anatomy.udder];
    var onStrictDevice = 0;
    for (final pt in points) {
      final x = (pt.dx * w).round().clamp(0, w - 1);
      final y = (pt.dy * h).round().clamp(0, h - 1);
      final p = image.getPixel(x, y);
      if (_isLandmarkOnStrictDeviceSurface(p)) onStrictDevice++;
    }
    if (onStrictDevice >= 4) return true;
    if (onStrictDevice >= 3 &&
        (_isElectronicDeviceScene(image) ||
            _isStrongElectronicDeviceScene(image))) {
      return true;
    }
    return false;
  }

  /// Landmarks on LCD/bezel/syntax only — not dark buffalo hide (IDE black).
  bool _isLandmarkOnStrictDeviceSurface(img.Pixel p) {
    if (_isOrganicLivestockPixel(p) || _isAnimalHidePixel(p)) return false;
    if (_isDarkUiPixel(p)) return false;
    return _isScreenUiPixel(p) ||
        _isSyntaxHighlightPixel(p) ||
        _isSilverMetalPixel(p) ||
        _isBezelPixel(p);
  }

  /// High-confidence laptop/monitor (silver + dark IDE, or bezel + LCD).
  bool _isStrongElectronicDeviceScene(img.Image image) {
    if (_torsoLivestockRatio(image) >= 0.14) return false;

    final w = image.width;
    final h = image.height;
    var screen = 0;
    var bezel = 0;
    var silver = 0;
    var dark = 0;
    var samples = 0;

    final cx0 = (w * 0.18).round();
    final cx1 = (w * 0.82).round();
    final cy0 = (h * 0.12).round();
    final cy1 = (h * 0.78).round();

    for (var y = cy0; y < cy1; y += _sampleStep) {
      for (var x = cx0; x < cx1; x += _sampleStep) {
        samples++;
        final p = image.getPixel(x, y);
        if (_isScreenUiPixel(p)) screen++;
        if (_isBezelPixel(p)) bezel++;
        if (_isSilverMetalPixel(p)) silver++;
        if (_isDarkUiPixel(p)) dark++;
      }
    }
    if (samples == 0) return false;

    final screenR = screen / samples;
    final bezelR = bezel / samples;
    final silverR = silver / samples;
    final darkR = dark / samples;

    if (bezelR > 0.06 && screenR > 0.10) return true;
    if (silverR > 0.08 && darkR > 0.12) return true;
    return false;
  }

  /// Laptop, monitor, phone LCD, keyboard — rectangular electronics in frame.
  bool _isElectronicDeviceScene(img.Image image) {
    final w = image.width;
    final h = image.height;
    var screen = 0;
    var bezel = 0;
    var keyboard = 0;
    var centerSamples = 0;

    final cx0 = (w * 0.18).round();
    final cx1 = (w * 0.82).round();
    final cy0 = (h * 0.12).round();
    final cy1 = (h * 0.78).round();

    for (var y = cy0; y < cy1; y += _sampleStep) {
      for (var x = cx0; x < cx1; x += _sampleStep) {
        centerSamples++;
        final p = image.getPixel(x, y);
        if (_isScreenUiPixel(p)) screen++;
        if (_isBezelPixel(p)) bezel++;
        if (y > h * 0.62 && _isKeyboardPixel(p)) keyboard++;
      }
    }
    if (centerSamples == 0) return false;

    final screenR = screen / centerSamples;
    final bezelR = bezel / centerSamples;
    final keyboardR = keyboard / centerSamples;

    // Laptop signature: neutral black bezel + colorful LCD (both required).
    if (bezelR > 0.06 && screenR > 0.10) return true;
    if (bezelR > 0.05 && screenR > 0.12 && keyboardR > 0.04) return true;

    var upperWhite = 0;
    var upperSamples = 0;
    final upperEnd = (h * 0.38).round();
    for (var y = 0; y < upperEnd; y += _sampleStep) {
      for (var x = 0; x < w; x += _sampleStep) {
        upperSamples++;
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final br = (r + g + b) / 3;
        final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
        if (br > 215 && sat < 22 && (r - g).abs() < 12 && (r - b).abs() < 12) {
          upperWhite++;
        }
      }
    }
    final whiteWallR = upperSamples == 0 ? 0.0 : upperWhite / upperSamples;
    if (whiteWallR > 0.28 && bezelR > 0.05 && screenR > 0.10) return true;

    if (_isSilverLaptopWithDarkScreen(image)) return true;

    return false;
  }

  /// Silver/gray laptop body + dark monitor (common desk photo).
  bool _isSilverLaptopWithDarkScreen(img.Image image) {
    if (_torsoLivestockRatio(image) >= 0.18) return false;

    final w = image.width;
    final h = image.height;
    var silver = 0;
    var darkUi = 0;
    var syntax = 0;
    var samples = 0;

    final cx0 = (w * 0.16).round();
    final cx1 = (w * 0.84).round();
    final cy0 = (h * 0.14).round();
    final cy1 = (h * 0.80).round();

    for (var y = cy0; y < cy1; y += _sampleStep) {
      for (var x = cx0; x < cx1; x += _sampleStep) {
        samples++;
        final p = image.getPixel(x, y);
        if (_isSilverMetalPixel(p)) silver++;
        if (_isDarkUiPixel(p)) darkUi++;
        if (_isSyntaxHighlightPixel(p)) syntax++;
      }
    }
    if (samples == 0) return false;

    final silverR = silver / samples;
    final darkR = darkUi / samples;
    final syntaxR = syntax / samples;

    if (silverR > 0.06 && darkR > 0.10) return true;
    if (silverR > 0.04 && darkR > 0.14 && syntaxR > 0.010) return true;
    if (silverR > 0.08 && syntaxR > 0.008) return true;
    return false;
  }

  bool _isSilverMetalPixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    if (br < 88 || br > 210 || sat > 28) return false;
    return (r - g).abs() < 16 && (r - b).abs() < 16 && (g - b).abs() < 16;
  }

  bool _isDarkUiPixel(img.Pixel p) {
    if (_isAnimalHidePixel(p)) return false;
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    // IDE/editor black — tighter than dark buffalo hide in shade.
    return br < 42 && sat < 28;
  }

  bool _isSyntaxHighlightPixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    if (br < 45 || sat < 32) return false;
    if (g > r + 16 && g > b + 8) return true;
    if (b > r + 14 && b > g - 4) return true;
    if (r > g + 18 && r > b + 10) return true;
    if (r > 115 && b > 115 && g < r - 18) return true;
    return false;
  }

  bool _isScreenUiPixel(img.Pixel p) {
    if (_isSkinTone(p)) return false;
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    if (br > 210 && sat < 30) return true;
    if (b > r + 18 && b > g + 6 && br > 105 && sat > 28) return true;
    if (r > 115 && b > 115 && g < r - 18 && br > 95 && sat > 30) return true;
    return false;
  }

  bool _isBezelPixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    if (br > 42 || br < 6 || sat > 26) return false;
    if (r > g + 14 || r > b + 10) return false;
    return (r - g).abs() < 14 && (r - b).abs() < 14;
  }

  bool _isKeyboardPixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    return sat < 22 && br > 70 && br < 175;
  }

  bool _isOrganicLivestockPixel(img.Pixel p) {
    if (_isScreenUiPixel(p) || _isBezelPixel(p)) return false;
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    // Very dark water-buffalo hide — not flat monitor/IDE black.
    if (br >= 18 &&
        br < 58 &&
        sat >= 10 &&
        sat < 48 &&
        r >= g - 10 &&
        r >= b - 10) {
      return true;
    }
    if (br < 12 || br > 168) return false;
    if (b > r + 28 && br > 85) return false;
    if (g > r + 38 && br > 95) return false;
    if (sat < 8 && br > 45 && br < 200) return false;
    return r >= 50 && r >= g - 18 && r >= b - 12 && sat >= 9;
  }

  bool _isGrassOrMudPixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    if (g > r + 14 && g > b + 10 && br > 45 && br < 185 && sat > 12) {
      return true;
    }
    if (br > 35 && br < 120 && r > 70 && g > 50 && b < 70 && sat > 10) {
      return true;
    }
    return false;
  }

  /// Portrait, selfie, face, or skin-heavy scenes.
  bool _hasHumanPhotoSignals(
    img.Image image, {
    bool trustRearAnatomy = false,
  }) {
    if (trustRearAnatomy) return false;
    if (_isHumanDominantScene(image)) return true;

    final livestock = _torsoLivestockRatio(image);
    final upperSkin = _skinRatioInRegion(image, y0: 0, y1: 0.58);
    final faceLike = _countFaceLikeInRegion(image, y0: 0, y1: 0.45);

    // Outdoor buffalo: trees/mud create face-like noise — require more skin.
    final skinGate = livestock >= 0.14 ? 0.10 : 0.075;
    final faceSkinGate = livestock >= 0.14 ? 0.06 : 0.038;
    final faceCountGate = livestock >= 0.14 ? 28 : 12;

    if (upperSkin > skinGate) return true;
    if (faceLike > faceCountGate && upperSkin > faceSkinGate) return true;

    final centerSkin = _skinRatioInRegion(
      image,
      y0: 0.08,
      y1: 0.78,
      x0: 0.18,
      x1: 0.82,
    );
    if (centerSkin > (livestock >= 0.14 ? 0.12 : 0.09)) return true;

    final portrait = image.height > image.width * 1.05;
    if (portrait && upperSkin > 0.055) return true;

    final work = image.width > 512
        ? img.copyResize(image, width: 512)
        : image;
    return _detectHumanPresenceSimple(
      work,
      work.width,
      work.height,
      livestockRatio: livestock,
    );
  }

  double _skinRatioInRegion(
    img.Image image, {
    required double y0,
    required double y1,
    double x0 = 0,
    double x1 = 1,
  }) {
    final w = image.width;
    final h = image.height;
    var skin = 0;
    var samples = 0;
    final yStart = (h * y0).round();
    final yEnd = (h * y1).round();
    final xStart = (w * x0).round();
    final xEnd = (w * x1).round();

    for (var y = yStart; y < yEnd; y += _sampleStep) {
      for (var x = xStart; x < xEnd; x += _sampleStep) {
        samples++;
        if (_isSkinTone(image.getPixel(x, y))) skin++;
      }
    }
    if (samples == 0) return 0;
    return skin / samples;
  }

  int _countFaceLikeInRegion(
    img.Image image, {
    required double y0,
    required double y1,
  }) {
    final w = image.width;
    final h = image.height;
    var count = 0;
    final yStart = (h * y0).round();
    final yEnd = (h * y1).round();

    for (var y = yStart; y < yEnd; y += _sampleStep) {
      for (var x = 0; x < w; x += _sampleStep) {
        if (_isFaceLikePixel(image, x, y, w, h)) count++;
      }
    }
    return count;
  }

  bool _isHumanDominantScene(img.Image image) {
    final h = image.height;
    final w = image.width;
    var skinUpper = 0;
    var faceLike = 0;
    var upperSamples = 0;
    final upperEnd = (h * 0.62).round();

    for (var y = 0; y < upperEnd; y += _sampleStep) {
      for (var x = 0; x < w; x += _sampleStep) {
        upperSamples++;
        final p = image.getPixel(x, y);
        if (_isSkinTone(p)) skinUpper++;
        if (y < h * 0.45 && _isFaceLikePixel(image, x, y, w, h)) faceLike++;
      }
    }
    if (upperSamples == 0) return false;

    final skinRatio = skinUpper / upperSamples;
    if (skinRatio > 0.08) return true;
    if (faceLike > 14 && skinRatio > 0.045) return true;
    return false;
  }

  bool _isHandOrPhoneScene(img.Image image) {
    final w = image.width;
    final h = image.height;
    final cx0 = (w * 0.22).round();
    final cx1 = (w * 0.78).round();
    final cy0 = (h * 0.18).round();
    final cy1 = (h * 0.72).round();

    var skin = 0;
    var screenLike = 0;
    var neutral = 0;
    var samples = 0;

    for (var y = cy0; y < cy1; y += _sampleStep) {
      for (var x = cx0; x < cx1; x += _sampleStep) {
        samples++;
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final br = (r + g + b) / 3;
        final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));

        if (_isSkinTone(p)) skin++;
        if (b > r + 15 && b > g + 8 && br > 95) screenLike++;
        if (sat < 20 && br > 50 && br < 210) neutral++;
        if (br > 215) screenLike++;
      }
    }
    if (samples == 0) return false;

    final skinR = skin / samples;
    final screenR = screenLike / samples;
    final neutralR = neutral / samples;

    // Selfie / person holding phone: skin + bright LCD/bezel region.
    if (skinR > 0.06 && (screenR > 0.12 || neutralR > 0.38)) return true;
    if (screenR > 0.22 && skinR > 0.03) return true;
    return false;
  }

  bool _isSkinTone(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    if (br < 70 || br > 235) return false;
    // Peach/tan human skin — not dark brown buffalo hide.
    return r > 105 &&
        r - g > 26 &&
        r - b > 32 &&
        g > b - 15 &&
        g - b < 55;
  }

  bool _hasRearAnimalMass(img.Image image, RearAnatomyLandmarks anatomy) {
    final w = image.width;
    final h = image.height;
    final x0 = (math.min(anatomy.leftPin.dx, anatomy.rightPin.dx) * w).round();
    final x1 = (math.max(anatomy.leftPin.dx, anatomy.rightPin.dx) * w).round();
    final uy = (anatomy.udder.dy * h).round();
    final y0 = (uy - h * 0.18).clamp(0, h - 1).round();
    final y1 = (uy + h * 0.06).clamp(0, h - 1).round();

    var animal = 0;
    var skin = 0;
    var samples = 0;

    for (var y = y0; y <= y1; y += _sampleStep) {
      for (var x = x0; x <= x1; x += _sampleStep) {
        samples++;
        final p = image.getPixel(x, y);
        if (_isSkinTone(p)) {
          skin++;
          continue;
        }
        if (_isAnimalHidePixel(p)) animal++;
      }
    }
    if (samples == 0) return false;
    if (skin / samples > 0.18) return false;

    final upperSkin = _skinRatioInRegion(image, y0: 0, y1: 0.52);
    if (upperSkin > 0.06) return false;

    return animal / samples >= 0.14;
  }

  bool _isAnimalHidePixel(img.Pixel p) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final br = (r + g + b) / 3;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    if (br < 10 || br > 175) return false;
    if (sat < 6 && br > 55 && br < 200) return false;
    if (g > r + 32 && g > b + 26) return false;
    if (b > r + 38) return false;
    return true;
  }

  /// Laptop / monitor / uniform wall — not a farm animal photo.
  bool _isObviousNonLivestock(img.Image image) {
    final w = image.width;
    final h = image.height;
    var neutral = 0;
    var organic = 0;
    var samples = 0;
    final y0 = (h * 0.15).round();

    for (var y = y0; y < h; y += _sampleStep) {
      for (var x = 0; x < w; x += _sampleStep) {
        samples++;
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final br = (r + g + b) / 3;
        final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
        if (sat < 18 && br > 45 && br < 200) neutral++;
        if (_isOrganicLivestockPixel(p) || _isGrassOrMudPixel(p)) organic++;
        if (b > r + 20 && b > g + 10 && br > 100) neutral++;
      }
    }
    if (samples == 0) return false;
    final neutralRatio = neutral / samples;
    final organicRatio = organic / samples;
    return neutralRatio > 0.68 && organicRatio < 0.10;
  }

  bool _isPlausibleRearBuffalo(RearAnatomyLandmarks anatomy) {
    if (anatomy.confidence < 0.48) return false;
    final spread = (anatomy.rightPin.dx - anatomy.leftPin.dx).abs();
    if (spread < 0.10 || spread > 0.88) return false;
    if (anatomy.leftPin.dy >= anatomy.udder.dy) return false;
    if (anatomy.udder.dy < 0.30) return false;
    if (anatomy.pointA.dy >= anatomy.udder.dy) return false;
    return true;
  }

  // 🔹 Step 1: Preprocessing
  img.Image? _preprocessImage(String imagePath) {
    try {
      final file = File(imagePath);
      final bytes = file.readAsBytesSync();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Resize to 224x224
      final resized = img.copyResize(image, width: 224, height: 224);
      
      // KEEP RGB COLORS - DO NOT CONVERT TO GRAYSCALE
      debugPrint('[PREPROCESS] Image resized to 224x224, RGB colors preserved');
      return resized;
    } catch (e) {
      debugPrint('[PREPROCESS] Error: $e');
      return null;
    }
  }
  
  // 🔹 Step 2: Object Detection (Primary Filter)
  Map<String, dynamic> _detectObjects(img.Image image) {
    // Simplified object detection using heuristics
    final width = image.width;
    final height = image.height;
    
    // Detect humans (simplified)
    final humanDetected = _detectHumanPresenceSimple(image, width, height);
    if (humanDetected) {
      return {'rejected': true, 'reason': 'Human detected'};
    }
    
    // Check if any animal-like object is present
    final animalPresent = _detectAnimalPresence(image, width, height);
    if (!animalPresent) {
      return {'rejected': true, 'reason': 'No animal found'};
    }
    
    debugPrint('[OBJECT DETECTION] Animal detected, no humans');
    return {'rejected': false};
  }
  
  bool _detectHumanPresenceSimple(
    img.Image image,
    int width,
    int height, {
    double livestockRatio = 0,
  }) {
    // Simple human detection based on face-like patterns and body proportions
    int faceLikeRegions = 0;
    int upperBodyPixels = 0;
    int lowerBodyPixels = 0;
    
    final midY = height ~/ 2;
    
    for (int y = 0; y < height; y += _sampleStep) {
      for (int x = 0; x < width; x += _sampleStep) {
        final brightness = image.getPixel(x, y).r;
        
        // Face detection (upper region, circular patterns)
        if (y < height * 0.3 && _isFaceLikePixel(image, x, y, width, height)) {
          faceLikeRegions++;
        }
        
        // Body proportions
        if (y < midY && brightness > 80 && brightness < 180) {
          upperBodyPixels++;
        } else if (y >= midY && brightness > 60 && brightness < 160) {
          lowerBodyPixels++;
        }
      }
    }
    
    var skinPixels = 0;
    var upperSamples = 0;
    final upperEnd = (height * 0.55).round();
    for (var y = 0; y < upperEnd; y += _sampleStep) {
      for (var x = 0; x < width; x += _sampleStep) {
        upperSamples++;
        if (_isSkinTone(image.getPixel(x, y))) skinPixels++;
      }
    }
    final skinRatio = upperSamples == 0 ? 0.0 : skinPixels / upperSamples;

    final hasFace = faceLikeRegions > 8;
    final hasHumanProportions = lowerBodyPixels > 0 &&
        upperBodyPixels > lowerBodyPixels * 1.2;

    debugPrint(
      '[HUMAN DETECTION] Face=$faceLikeRegions skin=${skinRatio.toStringAsFixed(2)} '
      'body=${upperBodyPixels / math.max(1, lowerBodyPixels)}',
    );
    if (livestockRatio >= 0.14) {
      return skinRatio > 0.11 ||
          (hasFace && skinRatio > 0.06 && hasHumanProportions) ||
          (faceLikeRegions > 40 && skinRatio > 0.05);
    }
    return skinRatio > 0.07 ||
        (hasFace && skinRatio > 0.035 && hasHumanProportions) ||
        (faceLikeRegions > 20 && skinRatio > 0.03);
  }
  
  bool _isFaceLikePixel(img.Image image, int x, int y, int width, int height) {
    if (x < 2 || y < 2 || x >= width - 2 || y >= height - 2) return false;
    
    final center = image.getPixel(x, y).r;
    final neighbors = [
      image.getPixel(x-1, y-1).r,
      image.getPixel(x+1, y-1).r,
      image.getPixel(x-1, y+1).r,
      image.getPixel(x+1, y+1).r,
    ];
    
    final avgNeighbor = neighbors.reduce((a, b) => a + b) / neighbors.length;
    return (center < avgNeighbor - 20) && center > 60 && center < 140;
  }
  
  bool _detectAnimalPresence(img.Image image, int width, int height) {
    if (_isElectronicDeviceScene(image)) return false;

    var organic = 0;
    var sampledPixels = 0;
    final yStart = (height * 0.10).round();

    for (var y = yStart; y < height; y += _sampleStep) {
      for (var x = 0; x < width; x += _sampleStep) {
        sampledPixels++;
        final p = image.getPixel(x, y);
        if (_isOrganicLivestockPixel(p) || _isGrassOrMudPixel(p)) organic++;
      }
    }

    final ratio = sampledPixels == 0 ? 0.0 : organic / sampledPixels;
    debugPrint('[ANIMAL DETECTION] Livestock organic ratio: $ratio');
    return ratio > 0.12;
  }
  
  // 🔹 Step 3: Species Classification
  Map<String, dynamic> _classifySpecies(img.Image image) {
    // Simplified species classification using heuristics
    final buffaloProb = _calculateBuffaloProbability(image);
    final cowProb = _calculateCowProbability(image);
    final otherProb = 1.0 - buffaloProb - cowProb;
    
    debugPrint('[SPECIES] Buffalo: ${buffaloProb.toStringAsFixed(3)}, Cow: ${cowProb.toStringAsFixed(3)}, Other: ${otherProb.toStringAsFixed(3)}');
    
    if (buffaloProb < 0.50) {
      return {'rejected': true, 'reason': 'Not a buffalo (confidence: ${(buffaloProb * 100).toStringAsFixed(1)}%)'};
    }

    if (cowProb > buffaloProb + 0.12 && cowProb > 0.55) {
      return {'rejected': true, 'reason': 'Looks like cattle, not buffalo — use a buffalo rear photo'};
    }
    
    return {'rejected': false, 'buffalo_prob': buffaloProb};
  }
  
  double _calculateBuffaloProbability(img.Image image) {
    // Enhanced buffalo characteristics detection using RGB colors with breed identification
    int darkPixels = 0;
    int blackPixels = 0;
    int brownPixels = 0;
    int bodyMassPixels = 0;
    int grayPixels = 0;
    int sampledPixels = 0;
    
    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final brightness = (r + g + b) / 3;
        
        // Buffalo color patterns - more sophisticated
        if (brightness < 90) darkPixels++; // Dark buffalo
        if (brightness < 60) blackPixels++; // Very dark/black buffalo
        if (brightness < 120 && r > 80 && g > 70 && b > 60) brownPixels++; // Dark brown buffalo
        
        // Gray/dull colors (common in desi buffalo)
        if (r > 50 && r < 100 && g > 50 && g < 100 && b > 50 && b < 100) grayPixels++;
        
        // Buffalo body mass detection
        if (brightness > 20 && brightness < 150) bodyMassPixels++;
      }
    }
    
    final darkRatio = sampledPixels == 0 ? 0.0 : darkPixels / sampledPixels;
    final blackRatio = sampledPixels == 0 ? 0.0 : blackPixels / sampledPixels;
    final brownRatio = sampledPixels == 0 ? 0.0 : brownPixels / sampledPixels;
    final grayRatio = sampledPixels == 0 ? 0.0 : grayPixels / sampledPixels;
    final bodyRatio = sampledPixels == 0 ? 0.0 : bodyMassPixels / sampledPixels;
    
    debugPrint('[BUFFALO PROB] Dark: $darkRatio, Black: $blackRatio, Brown: $brownRatio, Gray: $grayRatio, Body: $bodyRatio');
    
    double buffaloScore = 0.0;

    if (brownRatio > 0.10) buffaloScore += 0.28;
    else if (brownRatio > 0.05) buffaloScore += 0.16;

    if (blackRatio > 0.08 && blackRatio < 0.50) buffaloScore += 0.24;
    else if (blackRatio > 0.04) buffaloScore += 0.12;

    if (darkRatio > 0.18 && darkRatio < 0.60) buffaloScore += 0.18;

    if (bodyRatio > 0.25 && bodyRatio < 0.80) buffaloScore += 0.14;

    if (grayRatio > 0.40 && brownRatio < 0.05 && blackRatio < 0.06) {
      buffaloScore -= 0.40;
    }

    debugPrint('[BUFFALO PROB] Final score: $buffaloScore');
    return math.max(0.0, math.min(1.0, buffaloScore));
  }
  
  double _calculateCowProbability(img.Image image) {
    // Cows are typically lighter colored with different body shape
    int lightPixels = 0;
    int brownPixels = 0;
    int sampledPixels = 0;
    
    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final brightness = (r + g + b) / 3;
        
        // Cows are typically lighter
        if (brightness > 120) lightPixels++;
        
        // Cows often have brown/white patterns
        if (r > 100 && g > 80 && b > 60) brownPixels++;
      }
    }
    
    final lightRatio = sampledPixels == 0 ? 0.0 : lightPixels / sampledPixels;
    final brownRatio = sampledPixels == 0 ? 0.0 : brownPixels / sampledPixels;
    
    debugPrint('[COW PROB] Light: $lightRatio, Brown: $brownRatio');
    
    // Cow scoring based on light and brown colors - less aggressive
    double cowScore = 0.0;
    if (lightRatio > 0.5) cowScore += 0.6;
    else if (lightRatio > 0.4) cowScore += 0.4;
    else if (lightRatio > 0.3) cowScore += 0.2;
    
    if (brownRatio > 0.6) cowScore += 0.4;
    else if (brownRatio > 0.4) cowScore += 0.2;
    
    return math.max(0.0, math.min(1.0, cowScore));
  }
  
  // 🔹 Step 4: Visual Validation Rules
  Map<String, dynamic> _validateVisualQuality(img.Image image) {
    // Check for cartoon/illustration
    if (_isCartoonImage(image)) {
      return {'rejected': true, 'reason': 'Not real animal (cartoon/illustration)'};
    }
    
    // Check for blur and brightness
    final qualityScore = _calculateImageQuality(image);
    if (qualityScore < 0.3) {
      return {'rejected': true, 'reason': 'Low quality image (blurry/too dark/too bright)'};
    }
    
    debugPrint('[VISUAL VALIDATION] Quality score: ${qualityScore.toStringAsFixed(3)}');
    return {'rejected': false, 'quality_score': qualityScore};
  }
  
  bool _isCartoonImage(img.Image image) {
    int smoothRegions = 0;
    int uniformColors = 0;
    int totalSamples = 0;
    
    for (int y = 2; y < image.height - 2; y += 4) {
      for (int x = 2; x < image.width - 2; x += 4) {
        totalSamples++;
        
        final center = image.getPixel(x, y).r;
        final neighbors = [
          image.getPixel(x-1, y).r,
          image.getPixel(x+1, y).r,
          image.getPixel(x, y-1).r,
          image.getPixel(x, y+1).r,
        ];
        
        final maxDiff = neighbors.map((n) => (n - center).abs()).reduce(math.max);
        if (maxDiff < 3) smoothRegions++;
        
        if (center > 230 || center < 25) uniformColors++;
      }
    }
    
    final smoothRatio = smoothRegions / totalSamples;
    final uniformRatio = uniformColors / totalSamples;
    
    debugPrint('[CARTOON DETECTION] Smooth: $smoothRatio, Uniform: $uniformRatio');
    
    // Only reject if extremely smooth and uniform
    return smoothRatio > 0.95 && uniformRatio > 0.8;
  }
  
  double _calculateImageQuality(img.Image image) {
    double totalBrightness = 0;
    int edgePixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final brightness = image.getPixel(x, y).r;
        totalBrightness += brightness;
        
        // Simple edge detection
        final neighbors = [
          image.getPixel(x-1, y).r,
          image.getPixel(x+1, y).r,
          image.getPixel(x, y-1).r,
          image.getPixel(x, y+1).r,
        ];
        
        for (final neighbor in neighbors) {
          if ((brightness - neighbor).abs() > 30) {
            edgePixels++;
            break;
          }
        }
      }
    }
    
    final avgBrightness = totalBrightness / totalPixels;
    final edgeRatio = edgePixels / totalPixels;
    
    // Quality factors
    double brightnessScore = 0.0;
    if (avgBrightness >= 40 && avgBrightness <= 200) {
      brightnessScore = 1.0;
    } else if (avgBrightness >= 30 && avgBrightness <= 220) {
      brightnessScore = 0.7;
    } else {
      brightnessScore = 0.3;
    }
    
    double edgeScore = math.min(1.0, edgeRatio * 10); // More edges = better quality
    
    final qualityScore = (brightnessScore * 0.6) + (edgeScore * 0.4);
    return math.max(0.0, math.min(1.0, qualityScore));
  }
  
  Map<String, dynamic> _detectKeypointsFullImage(
    String imagePath,
    img.Image fallback224,
  ) {
    final anatomy = RearAnatomyDetector().detectFromPath(imagePath);
    if (anatomy != null && _isPlausibleRearBuffalo(anatomy)) {
      debugPrint(
        '[KEYPOINTS] Rear anatomy: L=${anatomy.leftPin} R=${anatomy.rightPin} U=${anatomy.udder}',
      );
      return {
        'rejected': false,
        'confidence': anatomy.confidence,
        'spine': anatomy.pointA,
        'leftHip': anatomy.leftPin,
        'rightHip': anatomy.rightPin,
        'udder': anatomy.udder,
      };
    }
    return _detectKeypoints(fallback224);
  }

  // 🔹 Step 5 fallback: 224px heuristic keypoints
  Map<String, dynamic> _detectKeypoints(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Detect key buffalo body points
    final spine = _detectSpine(image, width, height);
    final leftHip = _detectLeftHip(image, width, height);
    final rightHip = _detectRightHip(image, width, height);
    final udder = _detectUdder(image, width, height);
    
    final keypoints = [spine, leftHip, rightHip, udder];
    final missingKeypoints = keypoints.where((k) => k == null).length;
    
    if (missingKeypoints > 1) {
      return {'rejected': true, 'reason': 'Body parts not visible (missing $missingKeypoints key points)'};
    }
    
    debugPrint('[KEYPOINTS] Detected ${4 - missingKeypoints}/4 keypoints');
    debugPrint('[KEYPOINTS] Spine: ${spine != null}, LeftHip: ${leftHip != null}, RightHip: ${rightHip != null}, Udder: ${udder != null}');
    
    // Pass the actual keypoints to structural validation
    return {
      'rejected': false, 
      'confidence': (4 - missingKeypoints) / 4.0,
      'spine': spine,
      'leftHip': leftHip,
      'rightHip': rightHip,
      'udder': udder,
    };
  }
  
  Offset? _detectSpine(img.Image image, int width, int height) {
    // Spine is typically in the upper center region
    final centerX = width ~/ 2;
    final upperRegion = height ~/ 3;
    
    int spinePixels = 0;
    for (int y = 0; y < upperRegion; y++) {
      if (centerX > 0 && centerX < width) {
        final pixel = image.getPixel(centerX, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        if (brightness > 40 && brightness < 160) {
          spinePixels++;
        }
      }
    }
    
    return spinePixels > 5 ? Offset(centerX / width, 0.2) : null;
  }
  
  Offset? _detectLeftHip(img.Image image, int width, int height) {
    final centerX = width ~/ 2;
    final hipY = height ~/ 2;
    final hipRegion = width ~/ 3;
    
    int hipPixels = 0;
    for (int y = hipY - 10; y <= hipY + 10; y++) {
      for (int x = centerX - hipRegion; x < centerX; x++) {
        if (x >= 0 && y >= 0 && x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          if (brightness > 50 && brightness < 150) {
            hipPixels++;
          }
        }
      }
    }
    
    return hipPixels > 3 ? Offset((centerX - hipRegion/2) / width, hipY / height) : null;
  }
  
  Offset? _detectRightHip(img.Image image, int width, int height) {
    final centerX = width ~/ 2;
    final hipY = height ~/ 2;
    final hipRegion = width ~/ 3;
    
    int hipPixels = 0;
    for (int y = hipY - 10; y <= hipY + 10; y++) {
      for (int x = centerX; x < centerX + hipRegion; x++) {
        if (x >= 0 && y >= 0 && x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          if (brightness > 50 && brightness < 150) {
            hipPixels++;
          }
        }
      }
    }
    
    return hipPixels > 3 ? Offset((centerX + hipRegion/2) / width, hipY / height) : null;
  }
  
  Offset? _detectUdder(img.Image image, int width, int height) {
    final centerX = width ~/ 2;
    final lowerRegion = height * 2 ~/ 3;
    final udderWidth = width ~/ 3; // Wider search area
    
    int udderPixels = 0;
    int pinkishPixels = 0; // Udder tissue detection
    
    for (int y = lowerRegion; y < height; y++) {
      for (int x = centerX - udderWidth; x < centerX + udderWidth; x++) {
        if (x >= 0 && y >= 0 && x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          final brightness = (r + g + b) / 3;
          
          // Enhanced udder detection
          if (brightness > 20 && brightness < 130) {
            udderPixels++;
          }
          
          // Pinkish/reddish tissue detection (udder characteristic)
          if (r > 100 && g > 80 && b > 90 && r < 180 && g < 150 && b < 160) {
            pinkishPixels++;
          }
        }
      }
    }
    
    final udderScore = (udderPixels + pinkishPixels) / 2;
    debugPrint('[UDDER DETECTION] Udder pixels: $udderPixels, Pinkish: $pinkishPixels, Score: $udderScore');
    
    return udderScore > 8 ? Offset(centerX / width, (lowerRegion + height) / 2 / height) : null;
  }
  
  // 🔹 Step 6: Structural Validation
  Map<String, dynamic> _validateStructure(Map<String, dynamic> keypoints) {
    debugPrint('[STRUCTURAL] Starting structural validation...');
    
    // Check udder visibility
    debugPrint('[STRUCTURAL] Checking udder visibility...');
    if (keypoints['udder'] == null) {
      debugPrint('[STRUCTURAL] REJECTED: Udder not visible');
      return {'rejected': true, 'reason': 'Udder not visible'};
    }
    debugPrint('[STRUCTURAL] Udder visible: ${(keypoints['udder'] as Offset).dy.toStringAsFixed(3)}');
    
    // Check rear angle (simplified - check if lower body is visible)
    debugPrint('[STRUCTURAL] Checking rear angle...');
    final rearAngleValid = _checkRearAngle(keypoints);
    debugPrint('[STRUCTURAL] Rear angle valid: $rearAngleValid');
    if (!rearAngleValid) {
      debugPrint('[STRUCTURAL] REJECTED: Wrong angle (rear view required)');
      return {'rejected': true, 'reason': 'Wrong angle (rear view required)'};
    }
    
    // Check body proportions
    debugPrint('[STRUCTURAL] Checking body proportions...');
    final proportionsValid = _checkBodyProportions(keypoints);
    debugPrint('[STRUCTURAL] Body proportions valid: $proportionsValid');
    if (!proportionsValid) {
      debugPrint('[STRUCTURAL] REJECTED: Not buffalo structure');
      return {'rejected': true, 'reason': 'Not buffalo structure'};
    }
    
    debugPrint('[STRUCTURAL] All structural checks passed');
    return {'rejected': false};
  }
  
  bool _checkRearAngle(Map<String, dynamic> keypoints) {
    // Simplified rear angle check - udder should be in lower portion
    final udder = keypoints['udder'];
    if (udder == null) {
      debugPrint('[REAR ANGLE] No udder found');
      return false;
    }
    
    final udderY = (udder as Offset).dy;
    final isValid = udderY > 0.38 && udderY < 0.92;
    debugPrint('[REAR ANGLE] Udder Y: ${udderY.toStringAsFixed(3)}, Valid: $isValid');
    return isValid;
  }
  
  bool _checkBodyProportions(Map<String, dynamic> keypoints) {
    final spine = keypoints['spine'];
    final leftHip = keypoints['leftHip'];
    final rightHip = keypoints['rightHip'];
    
    if (spine == null || leftHip == null || rightHip == null) {
      debugPrint('[BODY PROPORTIONS] Missing keypoints - Spine: $spine != null, LeftHip: $leftHip != null, RightHip: $rightHip != null');
      return false;
    }
    
    // Check if hips are reasonably spaced
    final leftX = (leftHip as Offset).dx;
    final rightX = (rightHip as Offset).dx;
    final hipDistance = (rightX - leftX).abs();
    
    // Rear milk-mirror: pin bones span escutcheon (allow wide rear frame)
    final isValid = hipDistance > 0.08 && hipDistance < 0.88;
    debugPrint('[BODY PROPORTIONS] LeftX: ${leftX.toStringAsFixed(3)}, RightX: ${rightX.toStringAsFixed(3)}, Distance: ${hipDistance.toStringAsFixed(3)}, Valid: $isValid');
    return isValid;
  }
  
  // 🔹 Step 7: Confidence Scoring
  double _calculateFinalConfidence(double buffaloProb, double keypointConfidence, double qualityScore) {
    final finalConfidence = (buffaloProb * 0.5) + (keypointConfidence * 0.3) + (qualityScore * 0.2);
    debugPrint('[CONFIDENCE] Buffalo: ${buffaloProb.toStringAsFixed(3)}, Keypoints: ${keypointConfidence.toStringAsFixed(3)}, Quality: ${qualityScore.toStringAsFixed(3)}');
    debugPrint('[CONFIDENCE] Final: ${finalConfidence.toStringAsFixed(3)}');
    return finalConfidence;
  }
  
  // Helper methods for final steps
  Map<String, dynamic> _extractFeatures(img.Image image) {
    return {
      'body_condition': _assessBodyCondition(image),
      'udder_size': _assessUdderSize(image),
      'frame_size': _assessFrameSize(image),
      'build_quality': _assessLocalBuildQuality(image),
    };
  }
  
  String _assessBodyCondition(img.Image image) {
    int healthyPixels = 0;
    int sampledPixels = 0;
    
    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final brightness = image.getPixel(x, y).r;
        if (brightness > 60 && brightness < 160) {
          healthyPixels++;
        }
      }
    }
    
    final ratio = sampledPixels == 0 ? 0.0 : healthyPixels / sampledPixels;
    if (ratio > 0.6) return 'healthy';
    if (ratio > 0.4) return 'moderate';
    return 'thin';
  }
  
  String _assessUdderSize(img.Image image) {
    final centerX = image.width ~/ 2;
    final lowerRegion = image.height * 2 ~/ 3;
    final udderWidth = image.width ~/ 4;
    
    int udderPixels = 0;
    int totalLowerPixels = 0;
    
    for (int y = lowerRegion; y < image.height; y++) {
      for (int x = centerX - udderWidth; x < centerX + udderWidth; x++) {
        if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
          totalLowerPixels++;
          final brightness = image.getPixel(x, y).r;
          if (brightness > 30 && brightness < 120) {
            udderPixels++;
          }
        }
      }
    }
    
    final udderRatio = udderPixels / totalLowerPixels;
    if (udderRatio > 0.2) return 'large';
    if (udderRatio > 0.1) return 'medium';
    return 'small';
  }
  
  String _assessFrameSize(img.Image image) {
    int bodyPixels = 0;
    int sampledPixels = 0;
    
    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final brightness = image.getPixel(x, y).r;
        if (brightness > 50 && brightness < 180) {
          bodyPixels++;
        }
      }
    }
    
    final bodyRatio = sampledPixels == 0 ? 0.0 : bodyPixels / sampledPixels;
    if (bodyRatio > 0.5) return 'large';
    if (bodyRatio > 0.3) return 'medium';
    return 'small';
  }
  
  String _assessLocalBuildQuality(img.Image image) {
    int bodyPixels = 0;
    int sampledPixels = 0;

    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final brightness = image.getPixel(x, y).r;
        if (brightness > 30 && brightness < 150) bodyPixels++;
      }
    }

    final ratio = sampledPixels == 0 ? 0.0 : bodyPixels / sampledPixels;
    if (ratio > 0.5) return 'strong';
    if (ratio > 0.35) return 'average';
    return 'light';
  }
  
  Map<String, dynamic> _predictMilkProduction(
    Map<String, dynamic> features,
    String breed,
    int age,
    int lactation,
    int daysInMilk,
    String feed,
  ) {
    debugPrint('[MILK PREDICTION] Starting prediction (local buffalo)...');

    // Model trained for local (desi) buffalo — breed param kept for API compat only.
    const localBaseMilk = 10.0;
    double baseMilk = localBaseMilk;
    debugPrint('[MILK PREDICTION] Base milk (local): $baseMilk');
    
    // Adjust for age - more conservative
    if (age < 3) {
      baseMilk *= 0.5; // Reduced from 0.6
    } else if (age >= 3 && age <= 7) {
      baseMilk *= 1.05; // Reduced from 1.1
    } else if (age > 10) {
      baseMilk *= 0.8; // Reduced from 0.85
    }
    
    // Adjust for lactation - more conservative
    if (lactation == 1) {
      baseMilk *= 0.85; // Reduced from 0.9
    } else if (lactation >= 2 && lactation <= 4) {
      baseMilk *= 1.1; // Reduced from 1.2
    } else if (lactation >= 5) {
      baseMilk *= 0.75; // Reduced from 0.8
    }
    
    // Adjust for days in milk - more conservative
    if (daysInMilk < 30) {
      baseMilk *= 0.6; // Reduced from 0.7
    } else if (daysInMilk >= 30 && daysInMilk <= 120) {
      baseMilk *= 1.15; // Reduced from 1.3
    } else if (daysInMilk > 240) {
      baseMilk *= 0.85; // Reduced from 0.9
    }
    
    // Adjust for feed - more conservative
    final feedFactors = {
      'High Protein': 1.25,  // Reduced from 1.4
      'Standard': 1.0,
      'Low': 0.55,   // Reduced from 0.6
    };
    baseMilk *= feedFactors[feed] ?? 1.0;
    
    // Adjust for visual features - breed-specific analysis
    final bodyCondition = features['body_condition'] as String;
    final udderSize = features['udder_size'] as String;
    final frameSize = features['frame_size'] as String;
    final buildQuality = features['build_quality'] as String;

    debugPrint(
      '[MILK PREDICTION] Body: $bodyCondition, Udder: $udderSize, Frame: $frameSize, Build: $buildQuality',
    );

    if (bodyCondition == 'healthy') {
      baseMilk *= 1.2;
    } else if (bodyCondition == 'thin') {
      baseMilk *= 0.6;
    }

    if (udderSize == 'large') {
      baseMilk *= 1.3;
    } else if (udderSize == 'small') {
      baseMilk *= 0.6;
    }

    if (frameSize == 'large') {
      baseMilk *= 1.15;
    } else if (frameSize == 'small') {
      baseMilk *= 0.7;
    }

    if (buildQuality == 'strong') {
      baseMilk *= 1.05;
    } else if (buildQuality == 'light') {
      baseMilk *= 0.9;
    }
    
    // Apply cap for desi buffalo (high yielding varieties)
    final predictedLiters = math.max(4.0, math.min(25.0, baseMilk));  // Increased max to 25.0 for desi buffalo
    debugPrint('[MILK PREDICTION] Final prediction: $predictedLiters liters/day');
    
    return {
      'milk_per_day_liters': predictedLiters.roundToDouble(),
      'confidence': 0.85,
    };
  }
  
  BuffaloAnalysisResult _createRejectResult(String reason) {
    return BuffaloAnalysisResult(
      status: 'rejected',
      reason: reason,
      confidence: 0.0,
      animal: 'unknown',
    );
  }
}