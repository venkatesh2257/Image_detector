import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/training_sample.dart';
import '../../services/firestore_image_codec.dart';

/// Firestore is the only training data store (no local DB / manifest files).
class FirebaseTrainingService {
  FirebaseTrainingService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _assetsCollection = 'training_assets';
  static const _samplesSubcollection = 'samples';

  static String firestoreDatasetPath() =>
      '$_assetsCollection/{label}/$_samplesSubcollection/{docId}';

  Future<List<TrainingSample>> getSamples() async {
    try {
      final snapshot = await _firestore
          .collectionGroup(_samplesSubcollection)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TrainingSample.fromJson(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw FirebaseTrainingException(
        'Firestore read failed (code: ${e.code}). '
        'Check rules and Firebase project.',
      );
    } catch (e) {
      throw FirebaseTrainingException(
        'Firestore read failed: $e',
      );
    }
  }

  Future<TrainingSample> addSample({
    required String sourceImagePath,
    required String primaryLabel,
    required List<String> hashtags,
    required String description,
  }) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final imageName = sourceImagePath.split(Platform.pathSeparator).last;
    final imageStem = imageName.contains('.')
        ? imageName.substring(0, imageName.lastIndexOf('.'))
        : imageName;
    final assetFolder = _sanitizeForPath(primaryLabel);
    final docId = '${_sanitizeForPath(imageStem)}_$timestamp';
    final docRef = _firestore
        .collection(_assetsCollection)
        .doc(assetFolder)
        .collection(_samplesSubcollection)
        .doc(docId);

    debugPrint('[FIREBASE TRAINING] Upload label=$assetFolder doc=$docId');

    final imageData = await FirestoreImageCodec.encodeFile(sourceImagePath);

    final normalizedTags = hashtags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('#') ? e : '#$e')
        .toSet()
        .toList();

    final sample = TrainingSample(
      id: docId,
      imagePath: imageData,
      primaryLabel: primaryLabel.trim().toLowerCase(),
      hashtags: normalizedTags,
      description: description.trim(),
      createdAt: DateTime.now(),
      imageName: imageName,
      imageStem: imageStem,
      assetFolder: assetFolder,
      firestorePath: docRef.path,
    );

    try {
      await docRef.set({
        ...sample.toJson(),
        'createdAt': Timestamp.fromDate(sample.createdAt),
        'schemaVersion': 2,
        'trainingSplit': 'train',
        'buffaloType': 'local',
      });
    } on FirebaseException catch (e) {
      throw FirebaseTrainingException(
        'Firestore write failed (${e.code}): ${e.message ?? 'unknown'}',
      );
    }

    return sample;
  }

  Future<Map<String, int>> labelStats() async {
    final samples = await getSamples();
    final stats = <String, int>{};
    for (final sample in samples) {
      stats[sample.primaryLabel] = (stats[sample.primaryLabel] ?? 0) + 1;
    }
    return stats;
  }

  String _sanitizeForPath(String input) {
    final cleaned = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'uncategorized' : cleaned;
  }
}

class FirebaseTrainingException implements Exception {
  FirebaseTrainingException(this.message);
  final String message;

  @override
  String toString() => message;
}
