import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/continuous_learning_config.dart';

/// Downloads improved TFLite bundles from Firebase Storage (on-device inference).
class ModelUpdateService {
  ModelUpdateService({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  static const _localModelName = 'model.tflite';
  static const _localLabelsName = 'labels.txt';
  static const _localMetaName = 'training_metadata.json';

  /// Prefer downloaded production model over bundled asset.
  Future<String?> resolveModelPath() async {
    final dir = await _modelsDirectory();
    final file = File('${dir.path}/$_localModelName');
    if (await file.exists() && await file.length() > 1000) {
      return file.path;
    }
    return null;
  }

  Future<String?> resolveLabelsPath() async {
    final dir = await _modelsDirectory();
    final file = File('${dir.path}/$_localLabelsName');
    if (await file.exists()) return file.path;
    return null;
  }

  Future<Map<String, dynamic>?> resolveMetadata() async {
    final dir = await _modelsDirectory();
    final file = File('${dir.path}/$_localMetaName');
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Check Firestore pipeline state and download if remote version is newer.
  Future<ModelUpdateResult> checkAndDownload() async {
    try {
      final snap = await _firestore
          .doc(ContinuousLearningConfig.pipelineStateDoc)
          .get();
      if (!snap.exists) {
        return ModelUpdateResult.skipped('No pipeline state in Firestore');
      }

      final data = snap.data()!;
      final remoteVersion = data['modelVersion'] as String? ?? '';
      final valAcc = (data['valAccuracy'] as num?)?.toDouble();
      if (remoteVersion.isEmpty) {
        return ModelUpdateResult.skipped('Remote model version missing');
      }

      final dir = await _modelsDirectory();
      final versionFile = File('${dir.path}/.model_version');
      final localVersion =
          await versionFile.exists() ? await versionFile.readAsString() : '';

      if (localVersion.trim() == remoteVersion.trim()) {
        return ModelUpdateResult.skipped('Model already up to date');
      }

      await _downloadFile(
        ContinuousLearningConfig.productionModelPath,
        File('${dir.path}/$_localModelName'),
      );
      await _downloadFile(
        ContinuousLearningConfig.productionLabelsPath,
        File('${dir.path}/$_localLabelsName'),
      );
      await _downloadFile(
        ContinuousLearningConfig.productionMetadataPath,
        File('${dir.path}/$_localMetaName'),
      );

      await versionFile.writeAsString(remoteVersion);
      debugPrint(
        '[MODEL] Updated to $remoteVersion '
        '(val_acc=${valAcc != null ? (valAcc * 100).toStringAsFixed(1) : "?"}%)',
      );
      return ModelUpdateResult.updated(
        version: remoteVersion,
        valAccuracy: valAcc,
      );
    } catch (e, st) {
      debugPrint('[MODEL] Update check failed: $e\n$st');
      return ModelUpdateResult.failed('$e');
    }
  }

  Future<void> _downloadFile(String storagePath, File dest) async {
    dest.parent.createSync(recursive: true);
    final ref = _storage.ref(storagePath);
    await ref.writeToFile(dest);
  }

  Future<Directory> _modelsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/milk_mirror_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

class ModelUpdateResult {
  const ModelUpdateResult._({
    required this.status,
    this.version,
    this.valAccuracy,
    this.message,
  });

  factory ModelUpdateResult.updated({
    required String version,
    double? valAccuracy,
  }) =>
      ModelUpdateResult._(
        status: ModelUpdateStatus.updated,
        version: version,
        valAccuracy: valAccuracy,
      );

  factory ModelUpdateResult.skipped(String message) => ModelUpdateResult._(
        status: ModelUpdateStatus.skipped,
        message: message,
      );

  factory ModelUpdateResult.failed(String message) => ModelUpdateResult._(
        status: ModelUpdateStatus.failed,
        message: message,
      );

  final ModelUpdateStatus status;
  final String? version;
  final double? valAccuracy;
  final String? message;

  bool get didUpdate => status == ModelUpdateStatus.updated;
}

enum ModelUpdateStatus { updated, skipped, failed }
