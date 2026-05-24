import 'package:cloud_firestore/cloud_firestore.dart';

/// One farmer capture session (camera/gallery → review → AI).
class CaptureRecord {
  final String captureId;
  final String deviceId;
  final String? userId;
  final String imageData;
  final String imageName;
  final String? imageStorageUrl;
  final String source;
  final String status;
  final DateTime capturedAt;
  final bool? animalHealthy;
  final String breed;
  final int age;
  final int lactation;
  final int daysInMilk;
  final String feed;
  final String? predictionLabel;
  final double? estimatedLiters;
  final double? confidence;
  final String? predictionSource;
  final bool? rulesGatePassed;
  final String? trainingLabel;
  final String? trainingDocPath;
  final String? contentHash;
  final double? imageQualityScore;
  final bool? imageQualityPassed;
  final List<String>? imageQualityIssues;
  final String? platform;
  final bool? pipelinePassed;
  final double? pipelineScore;
  final String? pipelineFailedStage;
  final String? pipelineRejectReason;

  const CaptureRecord({
    required this.captureId,
    required this.deviceId,
    this.userId,
    required this.imageData,
    required this.imageName,
    this.imageStorageUrl,
    required this.source,
    required this.status,
    required this.capturedAt,
    this.animalHealthy,
    this.breed = 'Local/Desi',
    this.age = 5,
    this.lactation = 1,
    this.daysInMilk = 30,
    this.feed = 'Standard',
    this.predictionLabel,
    this.estimatedLiters,
    this.confidence,
    this.predictionSource,
    this.rulesGatePassed,
    this.trainingLabel,
    this.trainingDocPath,
    this.contentHash,
    this.imageQualityScore,
    this.imageQualityPassed,
    this.imageQualityIssues,
    this.platform,
    this.pipelinePassed,
    this.pipelineScore,
    this.pipelineFailedStage,
    this.pipelineRejectReason,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'captureId': captureId,
      'deviceId': deviceId,
      if (userId != null) 'userId': userId,
      'imageData': imageData,
      'imageName': imageName,
      if (imageStorageUrl != null) 'imageStorageUrl': imageStorageUrl,
      'source': source,
      'status': status,
      'capturedAt': Timestamp.fromDate(capturedAt),
      if (animalHealthy != null) 'animalHealthy': animalHealthy,
      'breed': breed,
      'age': age,
      'lactation': lactation,
      'daysInMilk': daysInMilk,
      'feed': feed,
      if (predictionLabel != null) 'predictionLabel': predictionLabel,
      if (estimatedLiters != null) 'estimatedLiters': estimatedLiters,
      if (confidence != null) 'confidence': confidence,
      if (predictionSource != null) 'predictionSource': predictionSource,
      if (rulesGatePassed != null) 'rulesGatePassed': rulesGatePassed,
      if (trainingLabel != null) 'trainingLabel': trainingLabel,
      if (trainingDocPath != null) 'trainingDocPath': trainingDocPath,
      if (contentHash != null) 'contentHash': contentHash,
      if (imageQualityScore != null) 'imageQualityScore': imageQualityScore,
      if (imageQualityPassed != null) 'imageQualityPassed': imageQualityPassed,
      if (imageQualityIssues != null && imageQualityIssues!.isNotEmpty)
        'imageQualityIssues': imageQualityIssues,
      if (platform != null) 'platform': platform,
      if (pipelinePassed != null) 'pipelinePassed': pipelinePassed,
      if (pipelineScore != null) 'pipelineScore': pipelineScore,
      if (pipelineFailedStage != null) 'pipelineFailedStage': pipelineFailedStage,
      if (pipelineRejectReason != null)
        'pipelineRejectReason': pipelineRejectReason,
      'schemaVersion': 5,
      'app': 'milk_mirror',
    };
  }

  static String collectionPath() => 'captures/{captureId}';

  static String trainingPath(String label, String docId) =>
      'training_assets/$label/samples/$docId';
}
