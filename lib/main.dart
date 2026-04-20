import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/classifier_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImageDetectorApp());
}

class ImageDetectorApp extends StatelessWidget {
  const ImageDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6D5EF7),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF090A17),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vision Trend',
      theme: theme,
      home: const DetectorHomePage(),
    );
  }
}

class DetectorHomePage extends StatefulWidget {
  const DetectorHomePage({super.key});

  @override
  State<DetectorHomePage> createState() => _DetectorHomePageState();
}

class _DetectorHomePageState extends State<DetectorHomePage> {
  final _picker = ImagePicker();
  final _classifier = ClassifierService();

  File? _pickedImage;
  PredictionResult? _prediction;
  bool _isLoading = false;
  bool _isModelReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareModel();
  }

  Future<void> _prepareModel() async {
    final ready = await _classifier.loadModel();
    if (!mounted) {
      return;
    }
    setState(() {
      _isModelReady = ready;
    });
  }

  Future<void> _pickAndPredict(ImageSource source) async {
    setState(() {
      _error = null;
    });

    final image = await _picker.pickImage(source: source, imageQuality: 85);
    if (image == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _pickedImage = File(image.path);
    });

    try {
      final result = await _classifier.classifyImage(image.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _prediction = result;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Prediction failed. Please try another image.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1026), Color(0xFF15123A), Color(0xFF090A17)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vision Trend',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isModelReady
                      ? 'AI model is ready for predictions'
                      : 'Running with demo mode until model is added',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _pickedImage == null
                      ? _buildEmptyState()
                      : _buildImagePreview(_pickedImage!),
                ),
                const SizedBox(height: 18),
                if (_isLoading) const LinearProgressIndicator(minHeight: 4),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                if (_prediction != null) ...[
                  const SizedBox(height: 14),
                  _buildPredictionCard(_prediction!),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _pickAndPredict(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _isLoading
                            ? null
                            : () => _pickAndPredict(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_search_rounded, color: Colors.white70, size: 48),
              SizedBox(height: 12),
              Text(
                'Capture or upload an image to start recognition',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(File imageFile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.file(imageFile, width: double.infinity, fit: BoxFit.cover),
    );
  }

  Widget _buildPredictionCard(PredictionResult prediction) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B34).withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prediction.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prediction.hashtags
                .map((tag) => Chip(
                      label: Text(tag),
                      side: BorderSide.none,
                      backgroundColor: const Color(0xFF2E2A63),
                      labelStyle: const TextStyle(color: Colors.white),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
