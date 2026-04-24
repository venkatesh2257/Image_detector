import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'screens/admin_panel_screen.dart';
import 'services/classifier_service_new.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImageDetectorApp());
}

class ImageFitInfo {
  final Size size;
  final Offset offset;

  ImageFitInfo({required this.size, required this.offset});
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
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [DetectorHomePage(), AdminPanelScreen()];
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.image_search_rounded),
            label: 'Detector',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Admin',
          ),
        ],
      ),
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

  // --- Hybrid Model Inputs ---
  String _selectedBreed = 'Murrah';
  String _selectedFeed = 'Standard';
  int _age = 5;
  int _lactation = 1;
  int _daysInMilk = 30;

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
    debugPrint('LOG: Requesting image from ${source.name}');

    // Handle Windows Camera limitation
    if (Platform.isWindows && source == ImageSource.camera) {
      debugPrint('LOG: Camera not supported on Windows via image_picker');
      if (!mounted) return;
      setState(() {
        _error = 'Camera is not supported on Windows desktop. Please use "Gallery" to upload a buffalo photo.';
      });
      return;
    }

    setState(() {
      _error = null;
    });

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) {
        debugPrint('LOG: Image picking cancelled');
        return;
      }

      debugPrint('LOG: Image picked: ${image.path}');
      setState(() {
        _isLoading = true;
        _pickedImage = File(image.path);
        _error = null; // Clear any previous camera errors on success
      });

      debugPrint('LOG: Starting classification...');
      final result = await _classifier.classifyImage(
        image.path,
        breed: _selectedBreed,
        age: _age,
        lactation: _lactation,
        daysInMilk: _daysInMilk,
        feed: _selectedFeed,
      );
      
      if (!mounted) return;
      
      debugPrint('LOG: Classification successful: ${result.label}');
      setState(() {
        _prediction = result;
      });
    } catch (e) {
      debugPrint('LOG: Error during picking/classification: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to open ${source.name.toLowerCase()}. Please check app permissions.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1026), Color(0xFF15123A), Color(0xFF090A17)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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
                      ? 'AI model is analyzing specific buffalo features for yield'
                      : 'Running with demo mode (Focus on rear/udder area)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                
                // --- Buffalo Profile Section ---
                _buildProfileForm(),
                
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: _pickedImage == null
                      ? _buildEmptyState()
                      : _buildImagePreview(_pickedImage!),
                ),
                const SizedBox(height: 18),
                if (_isLoading) ...[
                  const LinearProgressIndicator(
                    minHeight: 4,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_prediction != null) ...[
                  _buildPredictionCard(_prediction!),
                  const SizedBox(height: 18),
                ],
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

  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BUFFALO PROFILE',
            style: TextStyle(
              color: Color(0xFF6D5EF7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  'Breed',
                  _selectedBreed,
                  ['Murrah', 'Jaffrabadi', 'Nili-Ravi', 'Local/Desi'],
                  (val) => setState(() => _selectedBreed = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  'Feed Quality',
                  _selectedFeed,
                  ['High Protein', 'Standard', 'Low'],
                  (val) => setState(() => _selectedFeed = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput('Age (Yrs)', _age, (val) => setState(() => _age = val)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput('Lactation', _lactation, (val) => setState(() => _lactation = val)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput('Days in Milk', _daysInMilk, (val) => setState(() => _daysInMilk = val)),
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
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          // Use initialValue if available in latest Flutter, or value if controlled
          value: value,
          onChanged: onChanged,
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          dropdownColor: const Color(0xFF15123A),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ],
    );
  }

  Widget _buildNumberInput(String label, int value, ValueChanged<int> onChanged) {
    final controller = TextEditingController(text: value.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 13),
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
    debugPrint('[UI DEBUG] Rendering refined focus frame');
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF090A17),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white10, width: 1),
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
                        color: Colors.black.withValues(alpha: 0.3),
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

  Widget _buildPredictionCard(PredictionResult prediction) {
    bool isInvalid = prediction.label == 'No Buffalo Detected';
    double liters = prediction.estimatedLiters;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isInvalid 
            ? [const Color(0xFF401E1E), const Color(0xFF301515)] // Red for error
            : [const Color(0xFF1E1E40), const Color(0xFF151530)], // Blue for success
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.label,
                      style: TextStyle(
                        color: isInvalid ? Colors.redAccent : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isInvalid)
                      Text(
                        'Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: prediction.confidence > 0.8 ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
          const SizedBox(height: 20),
          if (isInvalid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                prediction.hashtags.first,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildModernCalculationRow('Hybrid Prediction', '${liters.toStringAsFixed(1)} Liters', Icons.opacity),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  _buildModernCalculationRow('Daily Revenue', '₹${(liters * 60).toStringAsFixed(0)}', Icons.payments_outlined),
                  _buildModernCalculationRow('Monthly Revenue', '₹${(liters * 30 * 60).toStringAsFixed(0)}', Icons.account_balance_wallet_outlined),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            isInvalid ? '* System could not identify buffalo features' : '* Based on Hybrid AI Model (Physical + Biological Data)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
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
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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

  AnatomicalPainter({required this.keypoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (keypoints.length < 4) return;

    // Clip drawing to the canvas area (image boundaries)
    canvas.clipRect(ui.Rect.fromLTRB(0.0, 0.0, size.width, size.height));

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final squarePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Map normalized points to canvas size
    final leftPin = Offset(keypoints[0].dx * size.width, keypoints[0].dy * size.height);
    final rightPin = Offset(keypoints[1].dx * size.width, keypoints[1].dy * size.height);
    final udder = Offset(keypoints[2].dx * size.width, keypoints[2].dy * size.height);
    final spine = Offset(keypoints[3].dx * size.width, keypoints[3].dy * size.height);

    // Calculate measurement square based on pin bones and udder
    // The square should connect the pin bones and extend to the udder area
    final squareWidth = (rightPin.dx - leftPin.dx).abs();
    final squareHeight = squareWidth; // Make it a perfect square
    final squareTop = leftPin.dy;
    final squareLeft = leftPin.dx;
    
    // Define the four corners of the measurement square
    final topLeft = Offset(squareLeft, squareTop);
    final topRight = Offset(squareLeft + squareWidth, squareTop);
    final bottomLeft = Offset(squareLeft, squareTop + squareHeight);
    final bottomRight = Offset(squareLeft + squareWidth, squareTop + squareHeight);

    // Draw the measurement square (filled with transparent color)
    final squarePath = Path()
      ..addRect(ui.Rect.fromLTRB(topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy));
    canvas.drawPath(squarePath, squarePaint);

    // Draw the square outline
    canvas.drawRect(ui.Rect.fromLTRB(topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy), linePaint);

    // Draw connecting lines from spine to pin bones
    canvas.drawLine(spine, leftPin, linePaint);
    canvas.drawLine(spine, rightPin, linePaint);

    // Draw lines from pin bones to udder (measurement lines)
    canvas.drawLine(leftPin, udder, linePaint);
    canvas.drawLine(rightPin, udder, linePaint);

    // Draw measurement diagonals for accuracy
    final diagonalPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(topLeft, bottomRight, diagonalPaint);
    canvas.drawLine(topRight, bottomLeft, diagonalPaint);

    // Draw the anatomical points with larger, more visible markers
    final anatomicalPoints = [
      {'point': leftPin, 'label': 'L Pin', 'color': Colors.redAccent},
      {'point': rightPin, 'label': 'R Pin', 'color': Colors.redAccent},
      {'point': udder, 'label': 'Udder', 'color': Colors.blueAccent},
      {'point': spine, 'label': 'Spine', 'color': Colors.yellowAccent},
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

    // Draw measurement info
    final measurementText = 'Square: ${squareWidth.toStringAsFixed(0)}px';
    final measurementPainter = TextPainter(
      text: TextSpan(
        text: measurementText,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    measurementPainter.layout();
    measurementPainter.paint(canvas, Offset(
      topLeft.dx + 10,
      topLeft.dy + 10,
    ));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
