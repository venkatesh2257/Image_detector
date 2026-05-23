import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';
import 'models/dairy_pipeline_report.dart';
import 'services/capture_firestore_service.dart';
import 'services/classifier_service_new.dart';
import 'services/image_based_milk_calculator.dart';
import 'services/inference_logger.dart';
import 'services/milk_mirror_measurement_service.dart';
import 'theme/app_theme.dart';
import 'widgets/enterprise/ai_analysis_overlay.dart';
import 'widgets/enterprise/enterprise_ai_dashboard.dart';
import 'widgets/enterprise/enterprise_app_header.dart';
import 'widgets/enterprise/enterprise_capture_zone.dart';
import 'widgets/enterprise/enterprise_measurement_card.dart';
import 'widgets/enterprise/glass_card.dart';
import 'widgets/enterprise/responsive_layout.dart';
import 'widgets/anatomy_overlay_layer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  runApp(const ImageDetectorApp());
}

class ImageFitInfo {
  final Size size;
  final Offset offset;

  ImageFitInfo({required this.size, required this.offset});
}

enum _CaptureFlowStage { capture, review, results }

class ImageDetectorApp extends StatelessWidget {
  const ImageDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Milk Mirror',
      theme: AppTheme.build(),
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
  final _captureStore = CaptureFirestoreService();

  /// Model is trained for local (desi) buffalo only — not breed/race-specific.
  static const String _localBuffaloType = 'Local/Desi';

  // Debug-only hybrid model tuning (hidden in release builds).
  String _selectedFeed = 'Standard';
  int _age = 5;
  int _lactation = 1;
  int _daysInMilk = 30;

  File? _pickedImage;
  PredictionResult? _prediction;
  Map<String, dynamic>? _imageBasedResult;
  _CaptureFlowStage _flowStage = _CaptureFlowStage.capture;
  /// Farmer-selected health before prediction (mutually exclusive).
  bool? _animalIsHealthy;
  bool _isLoading = false;
  bool _isModelReady = false;
  String? _modelLoadError;
  String? _error;
  /// Firestore document id for the current photo (`captures/{captureId}`).
  String? _currentCaptureId;

  @override
  void initState() {
    super.initState();
    _prepareModel();
  }

  String _engineLabel(String source) {
    switch (source) {
      case 'milk_mirror':
        return 'Pin bones + escutcheon (A–B, C–D)';
      case 'milk_mirror+tflite':
        return 'Milk Mirror + AI';
      case 'tflite':
        return 'TFLite AI';
      case 'tflite_untrained':
        return 'TFLite (needs training)';
      case 'rules_gate':
        return 'Rules gate only';
      default:
        return source;
    }
  }

  Future<void> _prepareModel() async {
    debugPrint('LOG: ═══ Initializing TFLite on app start ═══');
    final ready = await _classifier.loadModel();
    final diag = _classifier.lastDiagnostics;
    debugPrint(
      'LOG: Model ready=$ready | interpreter=${_classifier.isTfliteReady}',
    );
    if (diag != null) {
      debugPrint('LOG: Init proof: ${diag.proofSummary}');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isModelReady = ready;
      _modelLoadError = ready ? null : _classifier.modelLoadError;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    debugPrint('LOG: Requesting image from ${source.name}');

    if (Platform.isWindows && source == ImageSource.camera) {
      if (!mounted) return;
      setState(() {
        _error =
            'Camera is not supported on Windows desktop. Please use "Gallery" to upload a buffalo photo.';
      });
      return;
    }

    setState(() => _error = null);

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      debugPrint('LOG: Image picked: ${image.path}');
      if (!mounted) return;
      setState(() {
        _pickedImage = File(image.path);
        _prediction = null;
        _imageBasedResult = null;
        _flowStage = _CaptureFlowStage.review;
        _animalIsHealthy = true;
        _error = null;
        _currentCaptureId = null;
      });
      _uploadCaptureDraft(image.path, source.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Failed to open ${source.name.toLowerCase()}. Please check app permissions.';
      });
    }
  }

  Future<void> _uploadCaptureDraft(String imagePath, String source) async {
    try {
      final id = await _captureStore.saveCaptureDraft(
        imagePath: imagePath,
        source: source,
        breed: _localBuffaloType,
      );
      if (!mounted) return;
      setState(() => _currentCaptureId = id);
      debugPrint('LOG: Firestore capture id=$id');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firestore: captures/$id'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      debugPrint('LOG: Firestore capture draft failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firestore save failed: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _syncReviewToFirestore() async {
    final id = _currentCaptureId;
    if (id == null || _animalIsHealthy == null) return;
    try {
      final params = _hybridModelParams();
      await _captureStore.markReviewed(
        captureId: id,
        animalHealthy: _animalIsHealthy!,
        age: params.age,
        lactation: params.lactation,
        daysInMilk: params.daysInMilk,
        feed: params.feed,
        breed: _localBuffaloType,
      );
    } catch (e) {
      debugPrint('LOG: Firestore review update failed: $e');
    }
  }

  Future<void> _syncAnalysisToFirestore(PredictionResult result) async {
    final id = _currentCaptureId;
    if (id == null) return;
    try {
      await _captureStore.completeAnalysis(
        captureId: id,
        result: result,
      );
    } catch (e) {
      debugPrint('LOG: Firestore analysis update failed: $e');
    }
  }

  /// Instant UI feedback, then run CV on the next frame (keeps button responsive).
  void _onProceedTapped() {
    if (_pickedImage == null || _animalIsHealthy == null || _isLoading) return;

    unawaited(_syncReviewToFirestore());

    setState(() {
      _isLoading = true;
      _error = null;
      _prediction = null;
      _imageBasedResult = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isLoading) return;
      _runPredictionWork();
    });
  }

  Future<void> _runPredictionWork() async {
    try {
      debugPrint('LOG: Starting classification...');
      final path = _pickedImage!.path;
      final params = _hybridModelParams();
      final result = await _classifier.classifyImage(
        path,
        breed: _localBuffaloType,
        age: params.age,
        lactation: params.lactation,
        daysInMilk: params.daysInMilk,
        feed: params.feed,
      );

      if (!mounted) return;

      Map<String, dynamic>? imageBasedResult;
      if (kDebugMode) {
        imageBasedResult =
            await ImageBasedMilkCalculator().calculateMilkFromImage(path);
        final diag = result.diagnostics;
        debugPrint('LOG: ══════════ PREDICTION PROOF ══════════');
        debugPrint('LOG: Source: ${result.predictionSource}');
        debugPrint('LOG: Label shown: ${result.label}');
        debugPrint('LOG: Milk: ${result.estimatedLiters} L/day');
        debugPrint('LOG: Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
        if (diag != null) {
          debugPrint('LOG: ${diag.proofSummary}');
          debugPrint(
            'LOG: TFLite ran interpreter.run: ${diag.tfliteInferenceExecuted}',
          );
          debugPrint('LOG: Raw class: ${diag.rawTfliteLabel}');
          debugPrint(
            'LOG: Timings — load ${diag.tfliteLoadMs}ms | rules ${diag.rulesGateMs}ms | infer ${diag.tfliteInferenceMs}ms',
          );
        }
        debugPrint(
          'LOG: IMAGE-BASED (debug): ${imageBasedResult['milk_per_day_liters']} L/day',
        );
        debugPrint('LOG: ══════════════════════════════════════');
      }

      await _syncAnalysisToFirestore(result);

      setState(() {
        _prediction = result;
        _imageBasedResult = imageBasedResult;
        _flowStage = _CaptureFlowStage.results;
      });
    } catch (e) {
      debugPrint('LOG: Error during classification: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Analysis failed. Please try another photo.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetToCapture() {
    setState(() {
      _flowStage = _CaptureFlowStage.capture;
      _pickedImage = null;
      _prediction = null;
      _imageBasedResult = null;
      _animalIsHealthy = null;
      _error = null;
      _currentCaptureId = null;
    });
  }

  void _backToReview() {
    setState(() {
      _flowStage = _CaptureFlowStage.review;
      _prediction = null;
      _imageBasedResult = null;
    });
  }

  DairyPipelineReport? _reportWithUserHealth(DairyPipelineReport? report) {
    if (report == null || _animalIsHealthy == null) return report;
    final label = _animalIsHealthy! ? 'Healthy' : 'Not healthy';
    final steps = report.workflowSteps.map((s) {
      if (s.index != 6) return s;
      return PipelineStep(
        index: s.index,
        title: s.title,
        subtitle: label,
        status: _animalIsHealthy!
            ? PipelineStepStatus.pass
            : PipelineStepStatus.partial,
      );
    }).toList();
    return report.copyWith(healthStatus: label, workflowSteps: steps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            decoration: AppColors.backgroundDecoration,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padding = ResponsiveLayout.pagePadding(context);
                  final isWide = ResponsiveLayout.tier(context) != ScreenTier.compact;

                  return SingleChildScrollView(
                    padding: padding,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveLayout.contentMaxWidth(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            EnterpriseAppHeader(
                      modelReady: _isModelReady,
                      subtitle: _isModelReady
                          ? 'AI dairy analytics · rear udder capture'
                          : 'Booting prediction engine…',
                    ),
                if (!_isModelReady && _modelLoadError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Text(
                      _modelLoadError!,
                      style: const TextStyle(
                        color: Color(0xFF9A3412),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      _buildDebugProfileForm(),
                    ],
                            SizedBox(height: isWide ? 14 : 12),
                            _buildFlowStepper(isWide),
                            SizedBox(height: isWide ? 16 : 12),
                            if (_flowStage == _CaptureFlowStage.capture) ...[
                              _buildCaptureSection(showOverlay: false),
                              SizedBox(height: isWide ? 16 : 14),
                              _buildCaptureActions(isWide),
                            ],
                            if (_flowStage == _CaptureFlowStage.review) ...[
                              _buildCaptureSection(showOverlay: false),
                              SizedBox(height: isWide ? 14 : 12),
                              _buildReviewPanel(isWide),
                            ],
                            if (_flowStage == _CaptureFlowStage.results) ...[
                              _buildCaptureSection(showOverlay: true),
                              SizedBox(height: isWide ? 14 : 12),
                            ],
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_flowStage == _CaptureFlowStage.results &&
                        _prediction != null) ...[
                      if (_prediction!.pipeline != null)
                        EnterpriseAiDashboard(
                          report: _reportWithUserHealth(_prediction!.pipeline!)!,
                          sessionId: _prediction!.diagnostics?.sessionId,
                        ),
                      if (_prediction!.milkMirror != null) ...[
                        const SizedBox(height: 12),
                        EnterpriseMeasurementCard(
                          metrics: _prediction!.milkMirror!,
                          engineLabel: _engineLabel(_prediction!.predictionSource),
                        ),
                      ] else if (_prediction!.pipeline == null) ...[
                        const SizedBox(height: 12),
                        _buildOriginalModelCard(_prediction!),
                      ],
                      if (_prediction!.diagnostics != null) ...[
                        const SizedBox(height: 12),
                        _buildDiagnosticsExpansion(_prediction!.diagnostics!),
                      ],
                      const SizedBox(height: 12),
                      _buildResultsActions(isWide),
                    ],
                    if (kDebugMode &&
                        _flowStage == _CaptureFlowStage.results &&
                        _imageBasedResult != null) ...[
                      _buildImageBasedModelCard(_imageBasedResult!),
                      const SizedBox(height: 18),
                    ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isLoading)
            AiAnalysisOverlay(
              activeStepIndex: _flowStage == _CaptureFlowStage.review ? 2 : 3,
            ),
        ],
      ),
    );
  }

  Widget _buildFlowStepper(bool isWide) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      child: Row(
        children: [
          _flowStepChip(1, 'Capture', _flowStage == _CaptureFlowStage.capture),
          _flowConnector(),
          _flowStepChip(2, 'Review', _flowStage == _CaptureFlowStage.review),
          _flowConnector(),
          _flowStepChip(3, 'Results', _flowStage == _CaptureFlowStage.results),
        ],
      ),
    );
  }

  Widget _flowConnector() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: AppColors.border,
      ),
    );
  }

  Widget _flowStepChip(int step, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: TextStyle(
              color: active ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProceedButton() {
    final ready = _animalIsHealthy != null && _isModelReady;
    return FilledButton.icon(
      onPressed: ready && !_isLoading ? _onProceedTapped : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primaryDark,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.arrow_forward_rounded),
      label: Text(_isLoading ? 'Analyzing…' : 'Proceed'),
    );
  }

  Widget _buildReviewPanel(bool isWide) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Uploaded photo',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm animal health, then proceed to AI analysis.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text(
            'Animal health',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _healthCheckbox(
            label: 'Healthy',
            subtitle: 'Normal condition, fit for milking assessment',
            selected: _animalIsHealthy == true,
            onSelect: () => setState(() => _animalIsHealthy = true),
          ),
          const SizedBox(height: 6),
          _healthCheckbox(
            label: 'Not healthy',
            subtitle: 'Visible illness, injury, or poor condition',
            selected: _animalIsHealthy == false,
            onSelect: () => setState(() => _animalIsHealthy = false),
          ),
          SizedBox(height: isWide ? 20 : 16),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _resetToCapture,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Change photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildProceedButton(),
                ),
              ],
            )
          else ...[
            _buildProceedButton(),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _resetToCapture,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Change photo'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _healthCheckbox({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onSelect,
  }) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onSelect(),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsActions(bool isWide) {
    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _backToReview,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Edit health & retry'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _resetToCapture,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('New photo'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _backToReview,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Edit health & retry'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _isLoading ? null : _resetToCapture,
          icon: const Icon(Icons.add_a_photo_rounded),
          label: const Text('New photo'),
        ),
      ],
    );
  }

  Widget _buildCaptureActions(bool isWide) {
    final camera = FilledButton.icon(
      onPressed: _isLoading || !_isModelReady
          ? null
          : () => _pickImage(ImageSource.camera),
      icon: const Icon(Icons.camera_alt_rounded),
      label: const Text('Camera'),
    );
    final gallery = OutlinedButton.icon(
      onPressed: _isLoading || !_isModelReady
          ? null
          : () => _pickImage(ImageSource.gallery),
      icon: const Icon(Icons.photo_library_rounded),
      label: const Text('Gallery'),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: camera),
          const SizedBox(width: 12),
          Expanded(child: gallery),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        camera,
        const SizedBox(height: 10),
        gallery,
      ],
    );
  }

  Widget _buildCaptureSection({required bool showOverlay}) {
    final overlay = showOverlay &&
            _pickedImage != null &&
            _prediction != null &&
            _prediction!.milkMirror != null
        ? AnatomyOverlayLayer(
            imageFile: _pickedImage!,
            metrics: _prediction!.milkMirror,
            fallbackKeypoints: _prediction!.keypoints,
          )
        : null;

    return EnterpriseCaptureZone(
      image: _pickedImage,
      modelReady: _isModelReady,
      overlay: overlay,
    );
  }

  Widget _buildDiagnosticsExpansion(InferenceDiagnostics d) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          title: const Text(
            'Inference proof',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            d.proofSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: _buildInferenceProofCard(d, milkMirror: _prediction?.milkMirror),
            ),
          ],
        ),
      ),
    );
  }

  /// Production uses typical local-buffalo defaults; debug UI can override.
  _HybridModelParams _hybridModelParams() {
    if (kDebugMode) {
      return _HybridModelParams(
        feed: _selectedFeed,
        age: _age,
        lactation: _lactation,
        daysInMilk: _daysInMilk,
      );
    }
    return const _HybridModelParams(
      feed: 'Standard',
      age: 5,
      lactation: 2,
      daysInMilk: 60,
    );
  }

  Widget _buildDebugProfileForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, size: 16, color: Colors.orange.shade800),
              const SizedBox(width: 6),
              Text(
                'DEBUG — hybrid model inputs',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Local buffalo only ($_localBuffaloType). Hidden in production.',
            style: const TextStyle(color: Color(0xFF9A3412), fontSize: 11),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            'Feed quality',
            _selectedFeed,
            ['High Protein', 'Standard', 'Low'],
            (val) => setState(() => _selectedFeed = val!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput('Age (yrs)', _age, (val) => setState(() => _age = val)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput('Lactation #', _lactation, (val) => setState(() => _lactation = val)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput('Days in milk', _daysInMilk, (val) => setState(() => _daysInMilk = val)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          // Use initialValue if available in latest Flutter, or value if controlled
          value: value,
          onChanged: onChanged,
          isExpanded: true,
          style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          dropdownColor: const Color(0xFFFFFFFF),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ],
    );
  }

  Widget _buildNumberInput(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value.toString(),
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (val) {
            final parsed = int.tryParse(val);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        color: const Color(0xFFFFFFFF),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_search_rounded, color: Color(0xFF6B7280), size: 48),
              SizedBox(height: 12),
              Text(
                'Capture or upload an image to start recognition',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(File imageFile) {
    debugPrint('[UI DEBUG] Rendering refined focus frame');
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // The actual image
                  Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                  
                  // --- ANATOMICAL MEASUREMENT OVERLAY ---
                  if (_prediction != null && _prediction!.keypoints.isNotEmpty)
                    _buildAnatomicalOverlay(constraints, imageFile),
                  
                  // Technical Scanning Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  // Focus Frame - Set to gone (hidden)
                  if (false) // Always false to hide the align area square box
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // The Lens (Focus Area)
                        Container(
                          width: 150,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                        // The Visual Scanner Frame
                        Container(
                          width: 150,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF6D5EF7).withValues(alpha: 0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              _buildCorner(Alignment.topLeft),
                              _buildCorner(Alignment.topRight),
                              _buildCorner(Alignment.bottomLeft),
                              _buildCorner(Alignment.bottomRight),
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.center_focus_strong, color: Color(0xFF6D5EF7), size: 18),
                                    SizedBox(height: 8),
                                    Text(
                                      'ALIGN REAR',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnatomicalOverlay(BoxConstraints constraints, File imageFile) {
    return FutureBuilder<Size>(
      future: _getImageDimensions(imageFile),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final imageSize = snapshot.data!;
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Calculate how the image fits within the container with BoxFit.contain
        final imageFit = _calculateImageFit(imageSize, containerSize);
        
        return Positioned(
          left: imageFit.offset.dx,
          top: imageFit.offset.dy,
          child: SizedBox(
            width: imageFit.size.width,
            height: imageFit.size.height,
            child: CustomPaint(
              painter: AnatomicalPainter(
                keypoints: _prediction!.keypoints,
                milkMirror: _prediction!.milkMirror,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Size> _getImageDimensions(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      return const Size(400, 300); // Default fallback size
    }
    return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
  }

  ImageFitInfo _calculateImageFit(Size imageSize, Size containerSize) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;
    
    double finalWidth, finalHeight;
    double offsetX = 0, offsetY = 0;
    
    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container - fit to width
      finalWidth = containerSize.width;
      finalHeight = containerSize.width / imageAspectRatio;
      offsetY = (containerSize.height - finalHeight) / 2;
    } else {
      // Image is taller than container - fit to height
      finalHeight = containerSize.height;
      finalWidth = containerSize.height * imageAspectRatio;
      offsetX = (containerSize.width - finalWidth) / 2;
    }
    
    return ImageFitInfo(
      size: Size(finalWidth, finalHeight),
      offset: Offset(offsetX, offsetY),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildMilkMirrorAnalysisCard(PredictionResult prediction) {
    final m = prediction.milkMirror!;
    final liters = prediction.estimatedLiters;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.straighten_rounded, color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Milk Mirror Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      'AI-powered dairy insights · ${_engineLabel(prediction.predictionSource)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MEASURED',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  m.rangeLabel.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Center estimate: ${liters.toStringAsFixed(1)} L/day',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
                Text(
                  'Confidence: ${(m.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: m.confidence >= 0.6 ? const Color(0xFF059669) : const Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Escutcheon measurements',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _buildModernCalculationRow(
                  'Height (A → B)',
                  '${(m.heightNorm * 100).toStringAsFixed(1)}% of frame',
                  Icons.height,
                ),
                _buildModernCalculationRow(
                  'Width (C → D)',
                  '${(m.widthNorm * 100).toStringAsFixed(1)}% of frame',
                  Icons.swap_horiz,
                ),
                _buildModernCalculationRow(
                  'Area (H × W)',
                  '${(m.areaNorm * 100).toStringAsFixed(1)}%',
                  Icons.crop_square,
                ),
                _buildModernCalculationRow(
                  'Symmetry index',
                  '${m.symmetryPercent.toStringAsFixed(1)}% balanced',
                  Icons.balance,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Key features extracted',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _featureChip('Area', '${(m.areaNorm * 100).toStringAsFixed(0)}%'),
              _featureChip('Symmetry', '${m.symmetryPercent.toStringAsFixed(0)}%'),
              _featureChip('Fullness', '${(m.udderFullness * 100).toStringAsFixed(0)}%'),
              _featureChip('Texture', '${(m.textureScore * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.memory, size: 18, color: Color(0xFF6D5EF7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI cross-check: ${m.litersPerDay.toStringAsFixed(1)} L/day '
                    '(${(m.tfliteConfidence * 100).toStringAsFixed(0)}% match)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4C1D95)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildWorkflowSteps(prediction),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildModernCalculationRow(
                  'Daily revenue',
                  '₹${(liters * 60).toStringAsFixed(0)}',
                  Icons.payments_outlined,
                ),
                _buildModernCalculationRow(
                  'Monthly revenue',
                  '₹${(liters * 30 * 60).toStringAsFixed(0)}',
                  Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '* Pin bones (C/D) and udder (B) on photo — see overlay. '
            'Production scale 1–30 L/day from escutcheon + on-device AI.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _featureChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
      ),
    );
  }

  Widget _buildWorkflowSteps(PredictionResult prediction) {
    final steps = [
      ('Rules gate', true),
      ('Pin bones detected', prediction.keypoints.length >= 3),
      ('Escutcheon measured', prediction.milkMirror != null),
      ('TFLite ran', prediction.diagnostics?.tfliteInferenceExecuted ?? false),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: steps
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: s.$2 ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s.$2 ? Icons.check_circle : Icons.cancel,
                    size: 14,
                    color: s.$2 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    s.$1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: s.$2 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInferenceProofCard(
    InferenceDiagnostics diag, {
    MilkMirrorUiMetrics? milkMirror,
  }) {
    final ran = diag.tfliteInferenceExecuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ran ? Icons.verified_outlined : Icons.info_outline,
                size: 18,
                color: ran ? const Color(0xFF15803D) : const Color(0xFF9A3412),
              ),
              const SizedBox(width: 8),
              const Text(
                'Inference proof (see Debug Console)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF14532D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _proofRow('Session', diag.sessionId),
          _proofRow('Predicted by', diag.predictionSource.toUpperCase()),
          _proofRow('TFLite loaded', '${diag.tfliteModelLoaded}'),
          _proofRow('Interpreter', '${diag.tfliteInterpreterAllocated}'),
          _proofRow('interpreter.run()', '${diag.tfliteInferenceExecuted}'),
          _proofRow('Rules gate', diag.rulesGatePassed ? 'PASS' : 'FAIL'),
          if (milkMirror != null) ...[
            const SizedBox(height: 6),
            const Text(
              'Milk Mirror (UI):',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF14532D)),
            ),
            _proofRow('Height A→B', '${(milkMirror.heightNorm * 100).toStringAsFixed(1)}%'),
            _proofRow('Width C→D', '${(milkMirror.widthNorm * 100).toStringAsFixed(1)}%'),
            _proofRow('Area', '${(milkMirror.areaNorm * 100).toStringAsFixed(1)}%'),
            _proofRow('Liters (measured)', milkMirror.litersPerDay.toStringAsFixed(1)),
          ],
          if (diag.rawTfliteLabel.isNotEmpty)
            _proofRow('TFLite class', diag.rawTfliteLabel),
          if (diag.tfliteAllScores.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'All class scores:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            ...diag.tfliteAllScores.entries.map(
              (e) => Text(
                '  ${e.key}: ${(e.value * 100).toStringAsFixed(2)}%',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _proofRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$key: $value',
        style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
      ),
    );
  }

  Widget _buildOriginalModelCard(PredictionResult prediction) {
    final isInvalid = prediction.label == 'No Buffalo Detected' ||
        prediction.label == 'AI Model Not Loaded' ||
        prediction.label == 'Detection Error';
    final isUntrainedTflite = !isInvalid &&
        prediction.predictionSource == 'tflite' &&
        prediction.confidence < 0.25;
    double liters = prediction.estimatedLiters;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isInvalid 
            ? [const Color(0xFFFFF1F2), const Color(0xFFFFF7F7)]
            : [const Color(0xFFFFFFFF), const Color(0xFFF7F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isInvalid ? Colors.redAccent : const Color(0xFF6D5EF7)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isInvalid ? Icons.warning_amber_rounded : Icons.analytics_outlined, 
                  color: isInvalid ? Colors.redAccent : const Color(0xFF6D5EF7), 
                  size: 20
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5EF7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prediction.predictionSource.startsWith('milk_mirror')
                      ? 'MILK MIRROR MEASUREMENT'
                      : 'AI MODEL (TFLite)',
                  style: const TextStyle(
                    color: Color(0xFF6D5EF7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.label,
                      style: TextStyle(
                        color: isInvalid ? Colors.redAccent : const Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isInvalid) ...[
                      Text(
                        'Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: prediction.confidence > 0.8 ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Engine: ${_engineLabel(prediction.predictionSource)}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (liters > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${(liters * 30).toStringAsFixed(0)}L / Mo',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          if (isUntrainedTflite) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: const Text(
                'This TFLite file is not trained on your buffalo photos yet. '
                'The app always picks a class label, but 0% scores mean the model '
                'cannot distinguish 6–10 L bands. Train with training/train_model.py '
                'using images like your 10 L/day buffalo.',
                style: TextStyle(color: Color(0xFF9A3412), fontSize: 12, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (isInvalid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                prediction.hashtags.first,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildModernCalculationRow('Estimated yield', '${liters.toStringAsFixed(1)} L/day', Icons.opacity),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFE5E7EB), height: 1),
                  ),
                  _buildModernCalculationRow('Daily Revenue', '₹${(liters * 60).toStringAsFixed(0)}', Icons.payments_outlined),
                  _buildModernCalculationRow('Monthly Revenue', '₹${(liters * 30 * 60).toStringAsFixed(0)}', Icons.account_balance_wallet_outlined),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            isInvalid
                ? '* Could not identify buffalo from this photo'
                : kDebugMode
                    ? '* Local buffalo — hybrid model with debug inputs above'
                    : '* Local buffalo — estimate from photo only',
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBasedModelCard(Map<String, dynamic> result) {
    final milk = result['milk_per_day_liters'] as double;
    final confidence = result['confidence'] as double;
    final analysis = result['analysis'] as Map<String, dynamic>;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF4FFF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.visibility_rounded, 
                  color: Color(0xFF4CAF50), 
                  size: 20
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'IMAGE-BASED MODEL',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visual Analysis Complete',
                      style: TextStyle(
                        color: const Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Based on image features',
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _buildModernCalculationRow('Visual Prediction', '${milk.toStringAsFixed(1)} Liters', Icons.visibility),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Color(0xFFE5E7EB), height: 1),
                ),
                _buildModernCalculationRow('Visual Score', '${(confidence * 100).toStringAsFixed(1)}%', Icons.remove_red_eye),
                _buildModernCalculationRow('Udder size', '${analysis['udder_size']}', Icons.pets),
                _buildModernCalculationRow('Body condition', '${analysis['body_condition']}', Icons.fitness_center),
                _buildModernCalculationRow('Frame size', '${analysis['size_category']}', Icons.straighten),
                if (kDebugMode)
                  _buildModernCalculationRow(
                    'Build score (debug)',
                    '${((analysis['build_score'] as num?) ?? 0).toStringAsFixed(2)}',
                    Icons.bug_report,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '* Based on Visual AI Model (Image Analysis)',
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCalculationRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class AnatomicalPainter extends CustomPainter {
  final List<Offset> keypoints;
  final MilkMirrorUiMetrics? milkMirror;

  AnatomicalPainter({required this.keypoints, this.milkMirror});

  Offset _pt(Offset n, Size size) => Offset(n.dx * size.width, n.dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (keypoints.length < 3) return;

    canvas.clipRect(ui.Rect.fromLTRB(0.0, 0.0, size.width, size.height));

    final escutcheonPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final leftPin = _pt(keypoints[0], size);
    final rightPin = _pt(keypoints[1], size);
    final udder = _pt(keypoints[2], size);
    final spine = keypoints.length > 3 ? _pt(keypoints[3], size) : Offset((leftPin.dx + rightPin.dx) / 2, leftPin.dy - 40);

    final m = milkMirror;
    final pointA = m?.pointA != null ? _pt(m!.pointA!, size) : spine;
    final pointB = m?.pointB != null ? _pt(m!.pointB!, size) : udder;
    final pointC = m?.pointC != null ? _pt(m!.pointC!, size) : Offset(leftPin.dx, (leftPin.dy + udder.dy) / 2);
    final pointD = m?.pointD != null ? _pt(m!.pointD!, size) : Offset(rightPin.dx, (rightPin.dy + udder.dy) / 2);

    // Escutcheon region (master diagram)
    final escutcheonRect = ui.Rect.fromPoints(
      Offset(pointC.dx, pointA.dy),
      Offset(pointD.dx, pointB.dy),
    );
    canvas.drawRect(escutcheonRect, fillPaint);
    canvas.drawRect(escutcheonRect, escutcheonPaint);

    // Height A–B on spine (midpoint of pin row)
    final spineX = (pointC.dx + pointD.dx) / 2;
    canvas.drawLine(
      Offset(spineX, pointA.dy),
      Offset(spineX, pointB.dy),
      escutcheonPaint,
    );
    // Width C–D (horizontal)
    canvas.drawLine(pointC, pointD, escutcheonPaint);

    canvas.drawLine(spine, leftPin, linePaint);
    canvas.drawLine(spine, rightPin, linePaint);
    canvas.drawLine(leftPin, udder, linePaint);
    canvas.drawLine(rightPin, udder, linePaint);

    final anatomicalPoints = [
      {'point': pointA, 'label': 'A', 'color': const Color(0xFFFFD54F)},
      {'point': pointB, 'label': 'B', 'color': const Color(0xFFFFD54F)},
      {'point': pointC, 'label': 'C', 'color': const Color(0xFFFFD54F)},
      {'point': pointD, 'label': 'D', 'color': const Color(0xFFFFD54F)},
      {'point': leftPin, 'label': 'L Pin', 'color': Colors.redAccent},
      {'point': rightPin, 'label': 'R Pin', 'color': Colors.redAccent},
      {'point': udder, 'label': 'Udder', 'color': Colors.blueAccent},
    ];

    for (var item in anatomicalPoints) {
      final point = item['point'] as Offset;
      final label = item['label'] as String;
      final color = item['color'] as Color;

      // Outer glow
      canvas.drawCircle(point, 12, Paint()..color = color.withValues(alpha: 0.2)..style = PaintingStyle.fill);
      // Middle ring
      canvas.drawCircle(point, 8, Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.fill);
      // Inner dot
      canvas.drawCircle(point, 4, Paint()..color = color..style = PaintingStyle.fill);

      // Draw labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 2, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, point.dy - 20));
    }

    if (m != null) {
      final measurementText =
          'H: ${(m.heightNorm * 100).toStringAsFixed(0)}%  W: ${(m.widthNorm * 100).toStringAsFixed(0)}%';
      final measurementPainter = TextPainter(
        text: TextSpan(
          text: measurementText,
          style: const TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 3, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      measurementPainter.layout();
      measurementPainter.paint(
        canvas,
        Offset(escutcheonRect.left + 4, escutcheonRect.top + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AnatomicalPainter oldDelegate) {
    return oldDelegate.keypoints != keypoints ||
        oldDelegate.milkMirror != milkMirror;
  }
}

class _HybridModelParams {
  const _HybridModelParams({
    required this.feed,
    required this.age,
    required this.lactation,
    required this.daysInMilk,
  });

  final String feed;
  final int age;
  final int lactation;
  final int daysInMilk;
}
