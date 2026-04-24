class TrainingSample {
  TrainingSample({
    required this.id,
    required this.imagePath,
    required this.primaryLabel,
    required this.hashtags,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final String primaryLabel;
  final List<String> hashtags;
  final String description;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'primaryLabel': primaryLabel,
      'hashtags': hashtags,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TrainingSample.fromJson(Map<String, dynamic> json) {
    return TrainingSample(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      primaryLabel: json['primaryLabel'] as String,
      hashtags: (json['hashtags'] as List<dynamic>).map((e) => '$e').toList(),
      description: (json['description'] ?? '') as String,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }
}
