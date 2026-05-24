import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;

import '../config/continuous_learning_config.dart';
import '../models/ai_pipeline_report.dart' as pipeline;
import '../models/capture_record.dart';
import 'classifier_service_new.dart';
import 'ai_pipeline_orchestrator.dart';
import 'content_hash_service.dart';
import 'device_session_service.dart';
import 'firestore_image_codec.dart';

/// Saves every capture to Firestore + Storage for continuous learning export.
class CaptureFirestoreService {
  CaptureFirestoreService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    DeviceSessionService? session,
    AiPipelineOrchestrator? pipeline,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _session = session ?? DeviceSessionService(),
        _pipeline = pipeline ?? AiPipelineOrchestrator();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final DeviceSessionService _session;
  final AiPipelineOrchestrator _pipeline;

  static const _capturesCollection = 'captures';
  static const _trainingAssets = 'training_assets';
  static const _samplesSub = 'samples';
  static const _pipelinePendingField = 'pendingTrainingCount';

  /// Called when user picks camera/gallery — returns unique [captureId].
  Future<String> saveCaptureDraft({
    required String imagePath,
    required String source,
    String breed = 'Local/Desi',
  }) async {
    final deviceId = await _session.deviceId();
    final userId = await _session.linkedUserId();
    final captureId = _newCaptureId();
    final imageName = imagePath.split(Platform.pathSeparator).last;
    final contentHash = await ContentHashService.hashFile(imagePath);
    final pipelineReport = await _pipeline.validateForTraining(
      imagePath: imagePath,
      breed: breed,
    );
    final qualityStage =
        pipelineReport.stageResult(pipeline.PipelineStage.quality);

    final storageUrl = await _uploadOriginal(
      captureId: captureId,
      imagePath: imagePath,
    );

    final imageData = await FirestoreImageCodec.encodeFile(imagePath);

    final record = CaptureRecord(
      captureId: captureId,
      deviceId: deviceId,
      userId: userId,
      imageData: imageData,
      imageName: imageName,
      imageStorageUrl: storageUrl,
      source: source,
      status: 'captured',
      capturedAt: DateTime.now(),
      breed: breed,
      contentHash: contentHash,
      imageQualityScore: qualityStage?.score ?? pipelineReport.overallScore,
      imageQualityPassed: qualityStage?.passed ?? false,
      imageQualityIssues: qualityStage?.issues,
      platform: defaultTargetPlatform.name,
      pipelinePassed: pipelineReport.overallPassed,
      pipelineScore: pipelineReport.overallScore,
      pipelineFailedStage: pipelineReport.failedStage?.name,
      pipelineRejectReason: pipelineReport.rejectReason,
    );

    final firestoreData = record.toFirestore()
      ..addAll(pipelineReport.toFirestore());

    await _firestore
        .collection(_capturesCollection)
        .doc(captureId)
        .set(firestoreData);

    debugPrint(
      '[CAPTURE] Saved draft $captureId pipeline=${pipelineReport.overallPassed} '
      'score=${pipelineReport.overallScore.toStringAsFixed(2)}',
    );
    return captureId;
  }

  /// Review step — health + farm params before AI.
  Future<void> markReviewed({
    required String captureId,
    required bool animalHealthy,
    required int age,
    required int lactation,
    required int daysInMilk,
    required String feed,
    String breed = 'Local/Desi',
  }) async {
    await _firestore.collection(_capturesCollection).doc(captureId).update({
      'status': 'reviewed',
      'animalHealthy': animalHealthy,
      'age': age,
      'lactation': lactation,
      'daysInMilk': daysInMilk,
      'feed': feed,
      'breed': breed,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// After AI — update capture + copy into training dataset when applicable.
  Future<void> completeAnalysis({
    required String captureId,
    required PredictionResult result,
  }) async {
    final rulesPassed = result.predictionSource != 'rules_gate' &&
        result.predictionSource != 'not_loaded' &&
        result.predictionSource != 'error';
    final trainingLabel = CaptureTrainingLabel.fromPrediction(result);

    final captureSnap =
        await _firestore.collection(_capturesCollection).doc(captureId).get();
    final captureData = captureSnap.data() ?? {};
    final pipelinePassed = captureData['pipelinePassed'] == true;
    final qualityPassed = captureData['imageQualityPassed'] == true;
    final qualityScore =
        (captureData['imageQualityScore'] as num?)?.toDouble() ?? 0.0;
    final confidence = result.confidence;

    final eligibleForTraining = rulesPassed &&
        pipelinePassed &&
        trainingLabel != null &&
        trainingLabel != 'rejected' &&
        qualityPassed &&
        qualityScore >= ContinuousLearningConfig.minTrainingQualityScore &&
        confidence >= ContinuousLearningConfig.minConfidenceForTrainingMirror;

    String? trainingDocPath;
    if (eligibleForTraining) {
      trainingDocPath = await _mirrorToTrainingCollection(
        captureId: captureId,
        trainingLabel: trainingLabel,
        result: result,
        captureData: captureData,
      );
      await _incrementPendingTrainingCount();
    }

    await _firestore.collection(_capturesCollection).doc(captureId).update({
      'status': rulesPassed ? 'analyzed' : 'rejected',
      'predictionLabel': result.label,
      'estimatedLiters': result.estimatedLiters,
      'confidence': confidence,
      'predictionSource': result.predictionSource,
      'rulesGatePassed': rulesPassed,
      'eligibleForTraining': eligibleForTraining,
      if (trainingLabel != null) 'trainingLabel': trainingLabel,
      if (trainingDocPath != null) 'trainingDocPath': trainingDocPath,
      'analyzedAt': FieldValue.serverTimestamp(),
      if (result.hashtags.isNotEmpty) 'hashtags': result.hashtags,
    });

    debugPrint(
      '[CAPTURE] Completed $captureId status=${rulesPassed ? 'analyzed' : 'rejected'} '
      'training=$trainingDocPath eligible=$eligibleForTraining',
    );
  }

  Future<String> _uploadOriginal({
    required String captureId,
    required String imagePath,
  }) async {
    final ref = _storage.ref(
      '${ContinuousLearningConfig.capturesStoragePrefix}/$captureId/original.jpg',
    );
    await ref.putFile(File(imagePath));
    return await ref.getDownloadURL();
  }

  Future<String?> _mirrorToTrainingCollection({
    required String captureId,
    required String trainingLabel,
    required PredictionResult result,
    required Map<String, dynamic> captureData,
  }) async {
    final folder = _sanitize(trainingLabel);
    final storagePath =
        '${ContinuousLearningConfig.trainingQueuePrefix}/$folder/$captureId.jpg';

    String? trainingStorageUrl;
    final imageStorageUrl = captureData['imageStorageUrl'] as String?;
    if (imageStorageUrl != null && imageStorageUrl.isNotEmpty) {
      trainingStorageUrl = imageStorageUrl;
    } else {
      final imageData = captureData['imageData'] as String?;
      if (imageData != null && imageData.startsWith('data:image')) {
        final ref = _storage.ref(storagePath);
        final bytes = FirestoreImageCodec.decodeDataUrl(imageData);
        if (bytes != null) {
          await ref.putData(
            Uint8List.fromList(bytes),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          trainingStorageUrl = await ref.getDownloadURL();
        }
      }
    }

    final docRef = _firestore
        .collection(_trainingAssets)
        .doc(folder)
        .collection(_samplesSub)
        .doc(captureId);

    await docRef.set({
      'id': captureId,
      'captureId': captureId,
      'imagePath': captureData['imageData'],
      if (trainingStorageUrl != null) 'imageStorageUrl': trainingStorageUrl,
      'imageStoragePath': storagePath,
      'imageName': captureData['imageName'],
      'primaryLabel': folder,
      'hashtags': result.hashtags,
      'description':
          'Auto from Milk Mirror · ${result.estimatedLiters.toStringAsFixed(1)} L/day',
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 4,
      'trainingSplit': 'pending',
      'buffaloType': 'local',
      'deviceId': captureData['deviceId'],
      if (captureData['userId'] != null) 'userId': captureData['userId'],
      'source': captureData['source'],
      'platform': captureData['platform'],
      'estimatedLiters': result.estimatedLiters,
      'confidence': result.confidence,
      'predictionSource': result.predictionSource,
      'animalHealthy': captureData['animalHealthy'],
      'age': captureData['age'],
      'lactation': captureData['lactation'],
      'daysInMilk': captureData['daysInMilk'],
      'feed': captureData['feed'],
      'imageQualityScore': captureData['imageQualityScore'],
      'imageQualityPassed': captureData['imageQualityPassed'],
      'contentHash': captureData['contentHash'],
      'exportedForTraining': false,
    });

    return docRef.path;
  }

  Future<void> _incrementPendingTrainingCount() async {
    final ref = _firestore.doc(ContinuousLearningConfig.pipelineStateDoc);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current =
          (snap.data()?[_pipelinePendingField] as num?)?.toInt() ?? 0;
      tx.set(
        ref,
        {
          _pipelinePendingField: current + 1,
          'lastSampleAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  String _newCaptureId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return 'cap_$t';
  }

  String _sanitize(String input) {
    final cleaned = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'uncategorized' : cleaned;
  }
}

/// Maps AI output to Firestore training folder name.
abstract final class CaptureTrainingLabel {
  static String? fromPrediction(PredictionResult result) {
    if (result.predictionSource == 'rules_gate') return 'rejected';
    final raw = result.diagnostics?.rawTfliteLabel;
    if (raw != null && raw.isNotEmpty) return raw.trim();
    final liters = result.estimatedLiters;
    if (liters <= 0) return null;
    final bucket = liters.round().clamp(1, 30);
    return '${bucket}_lit';
  }
}

class CaptureFirestoreException implements Exception {
  CaptureFirestoreException(this.message);
  final String message;

  @override
  String toString() => message;
}
