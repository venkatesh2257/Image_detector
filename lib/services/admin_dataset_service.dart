import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/training_sample.dart';

class AdminDatasetService {
  Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(p.join(dir.path, 'admin_dataset'));
  }

  Future<File> _manifestFile() async {
    final base = await _baseDir();
    await base.create(recursive: true);
    return File(p.join(base.path, 'samples.json'));
  }

  Future<Directory> _imagesDir() async {
    final base = await _baseDir();
    final images = Directory(p.join(base.path, 'images'));
    await images.create(recursive: true);
    return images;
  }

  Future<List<TrainingSample>> getSamples() async {
    final file = await _manifestFile();
    if (!await file.exists()) {
      return [];
    }

    final data = await file.readAsString();
    if (data.trim().isEmpty) {
      return [];
    }

    final raw = jsonDecode(data) as List<dynamic>;
    return raw
        .map((entry) => TrainingSample.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<TrainingSample> addSample({
    required String sourceImagePath,
    required String primaryLabel,
    required List<String> hashtags,
    required String description,
  }) async {
    final imagesDir = await _imagesDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ext = p.extension(sourceImagePath).toLowerCase();
    final savedImagePath = p.join(imagesDir.path, 'sample_$id$ext');

    await File(sourceImagePath).copy(savedImagePath);

    final normalizedTags = hashtags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('#') ? e : '#$e')
        .toSet()
        .toList();

    final sample = TrainingSample(
      id: id,
      imagePath: savedImagePath,
      primaryLabel: primaryLabel.trim().toLowerCase(),
      hashtags: normalizedTags,
      description: description.trim(),
      createdAt: DateTime.now(),
    );

    final samples = await getSamples();
    samples.insert(0, sample);
    await _writeSamples(samples);
    return sample;
  }

  Future<void> exportManifestForTraining() async {
    final samples = await getSamples();
    final base = await _baseDir();
    final exportFile = File(p.join(base.path, 'training_manifest.json'));
    final payload = {
      'version': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'samples': samples.map((e) => e.toJson()).toList(),
    };
    await exportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<void> _writeSamples(List<TrainingSample> samples) async {
    final manifest = await _manifestFile();
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(samples.map((e) => e.toJson()).toList());
    await manifest.writeAsString(encoded);
  }

  Future<Map<String, int>> labelStats() async {
    final samples = await getSamples();
    final stats = <String, int>{};
    for (final sample in samples) {
      stats[sample.primaryLabel] = (stats[sample.primaryLabel] ?? 0) + 1;
    }
    return stats;
  }

  Future<String> baseDirectoryPath() async {
    final dir = await _baseDir();
    return dir.path;
  }
}
