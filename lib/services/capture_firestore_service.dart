import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/capture_record.dart';
import 'classifier_service_new.dart';
import 'device_session_service.dart';
import 'firestore_image_codec.dart';

/// Saves every capture to Firestore for future auth + model training export.
class CaptureFirestoreService {
  CaptureFirestoreService({
    FirebaseFirestore? firestore,
    DeviceSessionService? session,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _session = session ?? DeviceSessionService();

  final FirebaseFirestore _firestore;
  final DeviceSessionService _session;

  static const _capturesCollection = 'captures';
  static const _trainingAssets = 'training_assets';
  static const _samplesSub = 'samples';

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
    final imageData = await FirestoreImageCodec.encodeFile(imagePath);

    final record = CaptureRecord(
      captureId: captureId,
      deviceId: deviceId,
      userId: userId,
      imageData: imageData,
      imageName: imageName,
      source: source,
      status: 'captured',
      capturedAt: DateTime.now(),
      breed: breed,
    );

    await _firestore
        .collection(_capturesCollection)
        .doc(captureId)
        .set(record.toFirestore());

    debugPrint('[CAPTURE] Saved draft $captureId → captures/$captureId');
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

    String? trainingDocPath;
    if (rulesPassed && trainingLabel != null && trainingLabel != 'rejected') {
      trainingDocPath = await _mirrorToTrainingCollection(
        captureId: captureId,
        trainingLabel: trainingLabel,
        result: result,
      );
    }

    await _firestore.collection(_capturesCollection).doc(captureId).update({
      'status': rulesPassed ? 'analyzed' : 'rejected',
      'predictionLabel': result.label,
      'estimatedLiters': result.estimatedLiters,
      'confidence': result.confidence,
      'predictionSource': result.predictionSource,
      'rulesGatePassed': rulesPassed,
      if (trainingLabel != null) 'trainingLabel': trainingLabel,
      if (trainingDocPath != null) 'trainingDocPath': trainingDocPath,
      'analyzedAt': FieldValue.serverTimestamp(),
      if (result.hashtags.isNotEmpty) 'hashtags': result.hashtags,
    });

    debugPrint(
      '[CAPTURE] Completed $captureId status=${rulesPassed ? 'analyzed' : 'rejected'} '
      'training=$trainingDocPath',
    );
  }

  Future<String?> _mirrorToTrainingCollection({
    required String captureId,
    required String trainingLabel,
    required PredictionResult result,
  }) async {
    final snap =
        await _firestore.collection(_capturesCollection).doc(captureId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    final folder = _sanitize(trainingLabel);
    final docRef = _firestore
        .collection(_trainingAssets)
        .doc(folder)
        .collection(_samplesSub)
        .doc(captureId);

    await docRef.set({
      'id': captureId,
      'captureId': captureId,
      'imagePath': data['imageData'],
      'imageName': data['imageName'],
      'primaryLabel': folder,
      'hashtags': result.hashtags,
      'description':
          'Auto from Milk Mirror app · ${result.estimatedLiters.toStringAsFixed(1)} L/day',
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 3,
      'trainingSplit': 'train',
      'buffaloType': 'local',
      'deviceId': data['deviceId'],
      if (data['userId'] != null) 'userId': data['userId'],
      'source': data['source'],
      'estimatedLiters': result.estimatedLiters,
      'confidence': result.confidence,
      'predictionSource': result.predictionSource,
      'animalHealthy': data['animalHealthy'],
      'age': data['age'],
      'lactation': data['lactation'],
      'daysInMilk': data['daysInMilk'],
      'feed': data['feed'],
    });

    return docRef.path;
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
