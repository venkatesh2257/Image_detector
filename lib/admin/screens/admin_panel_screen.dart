import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/training_sample.dart';
import '../services/firebase_training_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _picker = ImagePicker();
  final _service = FirebaseTrainingService();
  final _labelController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedImage;
  List<TrainingSample> _samples = [];
  Map<String, int> _stats = {};
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _tagsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isBusy = true);
    try {
      final samples = await _service.getSamples();
      final stats = await _service.labelStats();
      if (!mounted) return;
      setState(() {
        _samples = samples;
        _stats = stats;
        _isBusy = false;
      });
    } catch (e) {
      debugPrint('[ADMIN] Load failed: $e');
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firebase load failed: $e')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 90);
    if (image == null) return;
    setState(() => _selectedImage = File(image.path));
  }

  Future<void> _saveSample() async {
    final image = _selectedImage;
    final label = _labelController.text.trim();
    if (image == null || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo and label are required')),
      );
      return;
    }

    setState(() => _isBusy = true);
    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      await _service.addSample(
        sourceImagePath: image.path,
        primaryLabel: label,
        hashtags: tags,
        description: _descriptionController.text,
      );

      _labelController.clear();
      _tagsController.clear();
      _descriptionController.clear();
      setState(() => _selectedImage = null);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Firebase for training')),
      );
    } catch (e) {
      debugPrint('[ADMIN] Save failed: $e');
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF13122B), Color(0xFF1B1741), Color(0xFF0F1020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Training Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Firebase: ${FirebaseTrainingService.firestoreDatasetPath()}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildFormCard()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildStatsCard()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1C3A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView(
        children: [
          _buildImageSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            decoration: _inputDecoration('Label (e.g. high_yield, low_yield)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tagsController,
            decoration: _inputDecoration('Tags (comma-separated)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: _inputDecoration('Notes (optional)'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isBusy ? null : _saveSample,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload to Firebase'),
          ),
          if (_isBusy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 4),
          ],
          const SizedBox(height: 12),
          const Text(
            'Recent (Firebase)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._samples.take(5).map(
                (sample) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    sample.primaryLabel,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    sample.hashtags.join(', '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildImageSelector() {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: _selectedImage == null
          ? Center(
              child: Wrap(
                spacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _isBusy ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _isBusy ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_selectedImage!, fit: BoxFit.contain),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1C3A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Firebase dataset',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Total samples: ${_samples.length}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          const Text(
            'Labels',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _stats.isEmpty
                ? const Text(
                    'No samples in Firestore yet',
                    style: TextStyle(color: Colors.white54),
                  )
                : ListView(
                    children: _stats.entries
                        .map(
                          (entry) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.key,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Text(
                              '${entry.value}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF2A2950),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}
