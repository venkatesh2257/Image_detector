import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingSample {
  TrainingSample({
    required this.id,
    required this.imagePath,
    required this.primaryLabel,
    required this.hashtags,
    required this.description,
    required this.createdAt,
    this.imageName,
    this.imageStem,
    this.assetFolder,
    this.firestorePath,
  });

  final String id;
  final String imagePath;
  final String primaryLabel;
  final List<String> hashtags;
  final String description;
  final DateTime createdAt;
  final String? imageName;
  final String? imageStem;
  final String? assetFolder;
  final String? firestorePath;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'primaryLabel': primaryLabel,
      'hashtags': hashtags,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      if (imageName != null) 'imageName': imageName,
      if (imageStem != null) 'imageStem': imageStem,
      if (assetFolder != null) 'assetFolder': assetFolder,
      if (firestorePath != null) 'firestorePath': firestorePath,
    };
  }

  factory TrainingSample.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.tryParse((createdAtRaw ?? '') as String) ??
          DateTime.now();
    }

    return TrainingSample(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      primaryLabel: json['primaryLabel'] as String,
      hashtags: (json['hashtags'] as List<dynamic>).map((e) => '$e').toList(),
      description: (json['description'] ?? '') as String,
      createdAt: createdAt,
      imageName: json['imageName'] as String?,
      imageStem: json['imageStem'] as String?,
      assetFolder: json['assetFolder'] as String?,
      firestorePath: json['firestorePath'] as String?,
    );
  }
}
