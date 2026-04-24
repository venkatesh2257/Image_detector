import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class PredictionResult {
  final String label;
  final double confidence;
  final List<String> hashtags;
  final double estimatedLiters;
  final List<Offset> keypoints;

  PredictionResult({
    required this.label,
    required this.confidence,
    this.hashtags = const [],
    this.estimatedLiters = 0.0,
    this.keypoints = const [],
  });
}

class BuffaloAnalysisResult {
  final String status;
  final String? reason;
  final double confidence;
  final String animal;
  final Map<String, dynamic>? features;
  final Map<String, dynamic>? prediction;

  BuffaloAnalysisResult({
    required this.status,
    this.reason,
    required this.confidence,
    required this.animal,
    this.features,
    this.prediction,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (reason != null) 'reason': reason,
      'confidence': confidence,
      'animal': animal,
      if (features != null) 'features': features,
      if (prediction != null) 'prediction': prediction,
    };
  }
}

class ClassifierService {
  final VeterinaryBuffaloDetector _detector = VeterinaryBuffaloDetector();
  
  Future<bool> loadModel() async {
    debugPrint('[BUFFALO DETECTOR] Clean buffalo identification system ready');
    return true;
  }
  
  Future<PredictionResult> classifyImage(
    String imagePath, {
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) async {
    debugPrint('[BUFFALO DETECTION] Starting clean buffalo identification...');
    
    try {
      final result = _detector.identifyBuffalo(
        imagePath,
        breed: breed,
        age: age,
        lactation: lactation,
        daysInMilk: daysInMilk,
        feed: feed,
      );
      
      if (result.status != 'valid') {
        return PredictionResult(
          label: 'No Buffalo Detected',
          confidence: 1.0,
          hashtags: ['Error: ${result.reason ?? 'Unknown error'}'],
          keypoints: [],
        );
      }
      
      // Convert to PredictionResult for UI compatibility
      final milkLiters = result.prediction?['milk_per_day_liters']?.toDouble() ?? 0.0;
      
      return PredictionResult(
        label: 'Buffalo Identified Successfully',
        confidence: result.confidence,
        estimatedLiters: milkLiters,
        keypoints: [], // Can be enhanced later with actual keypoints
        hashtags: ['Milk Yield: ${milkLiters.toStringAsFixed(1)} Liters/Day'],
      );
    } catch (e) {
      debugPrint('[BUFFALO DETECTION] Error: $e');
      return PredictionResult(
        label: 'Detection Error',
        confidence: 0.0,
        hashtags: ['Error: ${e.toString()}'],
        keypoints: [],
      );
    }
  }
}

class VeterinaryBuffaloDetector {
  // 🐃 Clean Buffalo Identification Algorithm Implementation
  
  BuffaloAnalysisResult identifyBuffalo(
    String imagePath, {
    String breed = 'Local/Desi',
    int age = 5,
    int lactation = 1,
    int daysInMilk = 30,
    String feed = 'Standard',
  }) {
    debugPrint('[STEP 0] Input: $imagePath');
    
    try {
      // 🔹 Step 1: Preprocessing
      debugPrint('[STEP 1] Preprocessing image...');
      final processedImage = _preprocessImage(imagePath);
      if (processedImage == null) {
        return _createRejectResult('Cannot process image');
      }
      
      // 🔹 Step 2: Object Detection (Primary Filter)
      debugPrint('[STEP 2] Object detection...');
      final objectDetection = _detectObjects(processedImage);
      if (objectDetection['rejected'] == true) {
        return _createRejectResult(objectDetection['reason']);
      }
      
      // 🔹 Step 3: Species Classification
      debugPrint('[STEP 3] Species classification...');
      final classification = _classifySpecies(processedImage);
      if (classification['rejected'] == true) {
        return _createRejectResult(classification['reason']);
      }
      
      // 🔹 Step 4: Visual Validation Rules
      debugPrint('[STEP 4] Visual validation...');
      final visualValidation = _validateVisualQuality(processedImage);
      if (visualValidation['rejected'] == true) {
        return _createRejectResult(visualValidation['reason']);
      }
      
      // 🔹 Step 5: Anatomical Keypoint Detection
      debugPrint('[STEP 5] Keypoint detection...');
      final keypoints = _detectKeypoints(processedImage);
      if (keypoints['rejected'] == true) {
        return _createRejectResult(keypoints['reason']);
      }
      
      // 🔹 Step 6: Structural Validation
      debugPrint('[STEP 6] Structural validation...');
      final structuralValidation = _validateStructure(keypoints);
      if (structuralValidation['rejected'] == true) {
        return _createRejectResult(structuralValidation['reason']);
      }
      
      // 🔹 Step 7: Confidence Scoring
      debugPrint('[STEP 7] Confidence scoring...');
      final confidence = _calculateFinalConfidence(
        classification['buffalo_prob'],
        keypoints['confidence'],
        visualValidation['quality_score'],
      );
      
      if (confidence < 0.75) {
        return _createRejectResult('Low confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      }
      
      // 🔹 Step 8: Final Output
      debugPrint('[STEP 8] Final output...');
      final features = _extractFeatures(processedImage);
      final prediction = _predictMilkProduction(features, breed, age, lactation, daysInMilk, feed);
      
      return BuffaloAnalysisResult(
        status: 'valid',
        confidence: confidence,
        animal: 'buffalo',
        features: features,
        prediction: prediction,
      );
      
    } catch (e) {
      debugPrint('[BUFFALO DETECTION] Error: $e');
      return _createRejectResult('Analysis failed: ${e.toString()}');
    }
  }
  
  // 🔹 Step 1: Preprocessing
  img.Image? _preprocessImage(String imagePath) {
    try {
      final file = File(imagePath);
      final bytes = file.readAsBytesSync();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Resize to 224x224
      final resized = img.copyResize(image, width: 224, height: 224);
      
      // KEEP RGB COLORS - DO NOT CONVERT TO GRAYSCALE
      debugPrint('[PREPROCESS] Image resized to 224x224, RGB colors preserved');
      return resized;
    } catch (e) {
      debugPrint('[PREPROCESS] Error: $e');
      return null;
    }
  }
  
  // 🔹 Step 2: Object Detection (Primary Filter)
  Map<String, dynamic> _detectObjects(img.Image image) {
    // Simplified object detection using heuristics
    final width = image.width;
    final height = image.height;
    
    // Detect humans (simplified)
    final humanDetected = _detectHumanPresenceSimple(image, width, height);
    if (humanDetected) {
      return {'rejected': true, 'reason': 'Human detected'};
    }
    
    // Check if any animal-like object is present
    final animalPresent = _detectAnimalPresence(image, width, height);
    if (!animalPresent) {
      return {'rejected': true, 'reason': 'No animal found'};
    }
    
    debugPrint('[OBJECT DETECTION] Animal detected, no humans');
    return {'rejected': false};
  }
  
  bool _detectHumanPresenceSimple(img.Image image, int width, int height) {
    // Simple human detection based on face-like patterns and body proportions
    int faceLikeRegions = 0;
    int upperBodyPixels = 0;
    int lowerBodyPixels = 0;
    
    final midY = height ~/ 2;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final brightness = image.getPixel(x, y).r;
        
        // Face detection (upper region, circular patterns)
        if (y < height * 0.3 && _isFaceLikePixel(image, x, y, width, height)) {
          faceLikeRegions++;
        }
        
        // Body proportions
        if (y < midY && brightness > 80 && brightness < 180) {
          upperBodyPixels++;
        } else if (y >= midY && brightness > 60 && brightness < 160) {
          lowerBodyPixels++;
        }
      }
    }
    
    // Human indicators
    final hasFace = faceLikeRegions > 10;
    final hasHumanProportions = upperBodyPixels > lowerBodyPixels * 1.5;
    
    debugPrint('[HUMAN DETECTION] Face regions: $faceLikeRegions, Body ratio: ${upperBodyPixels / lowerBodyPixels}');
    return hasFace && hasHumanProportions;
  }
  
  bool _isFaceLikePixel(img.Image image, int x, int y, int width, int height) {
    if (x < 2 || y < 2 || x >= width - 2 || y >= height - 2) return false;
    
    final center = image.getPixel(x, y).r;
    final neighbors = [
      image.getPixel(x-1, y-1).r,
      image.getPixel(x+1, y-1).r,
      image.getPixel(x-1, y+1).r,
      image.getPixel(x+1, y+1).r,
    ];
    
    final avgNeighbor = neighbors.reduce((a, b) => a + b) / neighbors.length;
    return (center < avgNeighbor - 20) && center > 60 && center < 140;
  }
  
  bool _detectAnimalPresence(img.Image image, int width, int height) {
    int animalPixels = 0;
    int totalPixels = width * height;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final brightness = image.getPixel(x, y).r;
        if (brightness > 30 && brightness < 200) {
          animalPixels++;
        }
      }
    }
    
    final animalRatio = animalPixels / totalPixels;
    debugPrint('[ANIMAL DETECTION] Animal pixel ratio: $animalRatio');
    return animalRatio > 0.2;
  }
  
  // 🔹 Step 3: Species Classification
  Map<String, dynamic> _classifySpecies(img.Image image) {
    // Simplified species classification using heuristics
    final buffaloProb = _calculateBuffaloProbability(image);
    final cowProb = _calculateCowProbability(image);
    final otherProb = 1.0 - buffaloProb - cowProb;
    
    debugPrint('[SPECIES] Buffalo: ${buffaloProb.toStringAsFixed(3)}, Cow: ${cowProb.toStringAsFixed(3)}, Other: ${otherProb.toStringAsFixed(3)}');
    
    if (buffaloProb < 0.65) {
      return {'rejected': true, 'reason': 'Not a buffalo (confidence: ${(buffaloProb * 100).toStringAsFixed(1)}%)'};
    }
    
    return {'rejected': false, 'buffalo_prob': buffaloProb};
  }
  
  double _calculateBuffaloProbability(img.Image image) {
    // Enhanced buffalo characteristics detection using RGB colors
    int darkPixels = 0;
    int blackPixels = 0;
    int bodyMassPixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final brightness = (r + g + b) / 3;
        
        // Buffalo are typically dark/black
        if (brightness < 80) darkPixels++;
        if (brightness < 50) blackPixels++; // Very dark/black buffalo
        
        // Buffalo body mass detection
        if (brightness > 20 && brightness < 140) bodyMassPixels++;
        
        // Buffalo color patterns (dark with some variation)
        if (r < 100 && g < 100 && b < 100) darkPixels++;
      }
    }
    
    final darkRatio = darkPixels / totalPixels;
    final blackRatio = blackPixels / totalPixels;
    final bodyRatio = bodyMassPixels / totalPixels;
    
    debugPrint('[BUFFALO PROB] Dark: $darkRatio, Black: $blackRatio, Body: $bodyRatio');
    
    // Enhanced buffalo scoring with RGB features
    double buffaloScore = 0.0;
    
    // Dark/black color feature (buffalo are typically dark)
    if (blackRatio > 0.2) buffaloScore += 0.4;
    else if (blackRatio > 0.1) buffaloScore += 0.3;
    else if (blackRatio > 0.05) buffaloScore += 0.2;
    
    // Overall dark color feature
    if (darkRatio > 0.4) buffaloScore += 0.3;
    else if (darkRatio > 0.3) buffaloScore += 0.2;
    else if (darkRatio > 0.2) buffaloScore += 0.1;
    
    // Body mass feature (buffalo have substantial body)
    if (bodyRatio > 0.6) buffaloScore += 0.3;
    else if (bodyRatio > 0.4) buffaloScore += 0.2;
    else if (bodyRatio > 0.2) buffaloScore += 0.1;
    
    debugPrint('[BUFFALO PROB] Final score: $buffaloScore');
    return math.max(0.0, math.min(1.0, buffaloScore));
  }
  
  double _calculateCowProbability(img.Image image) {
    // Cows are typically lighter colored with different body shape
    int lightPixels = 0;
    int brownPixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final brightness = (r + g + b) / 3;
        
        // Cows are typically lighter
        if (brightness > 120) lightPixels++;
        
        // Cows often have brown/white patterns
        if (r > 100 && g > 80 && b > 60) brownPixels++;
      }
    }
    
    final lightRatio = lightPixels / totalPixels;
    final brownRatio = brownPixels / totalPixels;
    
    debugPrint('[COW PROB] Light: $lightRatio, Brown: $brownRatio');
    
    // Cow scoring based on light and brown colors
    double cowScore = 0.0;
    if (lightRatio > 0.3) cowScore += 0.6;
    else if (lightRatio > 0.2) cowScore += 0.4;
    else if (lightRatio > 0.1) cowScore += 0.2;
    
    if (brownRatio > 0.4) cowScore += 0.4;
    else if (brownRatio > 0.2) cowScore += 0.2;
    
    return math.max(0.0, math.min(1.0, cowScore));
  }
  
  // 🔹 Step 4: Visual Validation Rules
  Map<String, dynamic> _validateVisualQuality(img.Image image) {
    // Check for cartoon/illustration
    if (_isCartoonImage(image)) {
      return {'rejected': true, 'reason': 'Not real animal (cartoon/illustration)'};
    }
    
    // Check for blur and brightness
    final qualityScore = _calculateImageQuality(image);
    if (qualityScore < 0.3) {
      return {'rejected': true, 'reason': 'Low quality image (blurry/too dark/too bright)'};
    }
    
    debugPrint('[VISUAL VALIDATION] Quality score: ${qualityScore.toStringAsFixed(3)}');
    return {'rejected': false, 'quality_score': qualityScore};
  }
  
  bool _isCartoonImage(img.Image image) {
    int smoothRegions = 0;
    int uniformColors = 0;
    int totalSamples = 0;
    
    for (int y = 2; y < image.height - 2; y += 4) {
      for (int x = 2; x < image.width - 2; x += 4) {
        totalSamples++;
        
        final center = image.getPixel(x, y).r;
        final neighbors = [
          image.getPixel(x-1, y).r,
          image.getPixel(x+1, y).r,
          image.getPixel(x, y-1).r,
          image.getPixel(x, y+1).r,
        ];
        
        final maxDiff = neighbors.map((n) => (n - center).abs()).reduce(math.max);
        if (maxDiff < 3) smoothRegions++;
        
        if (center > 230 || center < 25) uniformColors++;
      }
    }
    
    final smoothRatio = smoothRegions / totalSamples;
    final uniformRatio = uniformColors / totalSamples;
    
    debugPrint('[CARTOON DETECTION] Smooth: $smoothRatio, Uniform: $uniformRatio');
    
    // Only reject if extremely smooth and uniform
    return smoothRatio > 0.95 && uniformRatio > 0.8;
  }
  
  double _calculateImageQuality(img.Image image) {
    double totalBrightness = 0;
    int edgePixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final brightness = image.getPixel(x, y).r;
        totalBrightness += brightness;
        
        // Simple edge detection
        final neighbors = [
          image.getPixel(x-1, y).r,
          image.getPixel(x+1, y).r,
          image.getPixel(x, y-1).r,
          image.getPixel(x, y+1).r,
        ];
        
        for (final neighbor in neighbors) {
          if ((brightness - neighbor).abs() > 30) {
            edgePixels++;
            break;
          }
        }
      }
    }
    
    final avgBrightness = totalBrightness / totalPixels;
    final edgeRatio = edgePixels / totalPixels;
    
    // Quality factors
    double brightnessScore = 0.0;
    if (avgBrightness >= 40 && avgBrightness <= 200) {
      brightnessScore = 1.0;
    } else if (avgBrightness >= 30 && avgBrightness <= 220) {
      brightnessScore = 0.7;
    } else {
      brightnessScore = 0.3;
    }
    
    double edgeScore = math.min(1.0, edgeRatio * 10); // More edges = better quality
    
    final qualityScore = (brightnessScore * 0.6) + (edgeScore * 0.4);
    return math.max(0.0, math.min(1.0, qualityScore));
  }
  
  // 🔹 Step 5: Anatomical Keypoint Detection
  Map<String, dynamic> _detectKeypoints(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Detect key buffalo body points
    final spine = _detectSpine(image, width, height);
    final leftHip = _detectLeftHip(image, width, height);
    final rightHip = _detectRightHip(image, width, height);
    final udder = _detectUdder(image, width, height);
    
    final keypoints = [spine, leftHip, rightHip, udder];
    final missingKeypoints = keypoints.where((k) => k == null).length;
    
    if (missingKeypoints > 1) {
      return {'rejected': true, 'reason': 'Body parts not visible (missing $missingKeypoints key points)'};
    }
    
    debugPrint('[KEYPOINTS] Detected ${4 - missingKeypoints}/4 keypoints');
    debugPrint('[KEYPOINTS] Spine: ${spine != null}, LeftHip: ${leftHip != null}, RightHip: ${rightHip != null}, Udder: ${udder != null}');
    
    // Pass the actual keypoints to structural validation
    return {
      'rejected': false, 
      'confidence': (4 - missingKeypoints) / 4.0,
      'spine': spine,
      'leftHip': leftHip,
      'rightHip': rightHip,
      'udder': udder,
    };
  }
  
  Offset? _detectSpine(img.Image image, int width, int height) {
    // Spine is typically in the upper center region
    final centerX = width ~/ 2;
    final upperRegion = height ~/ 3;
    
    int spinePixels = 0;
    for (int y = 0; y < upperRegion; y++) {
      if (centerX > 0 && centerX < width) {
        final pixel = image.getPixel(centerX, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        if (brightness > 40 && brightness < 160) {
          spinePixels++;
        }
      }
    }
    
    return spinePixels > 10 ? Offset(centerX / width, 0.2) : null;
  }
  
  Offset? _detectLeftHip(img.Image image, int width, int height) {
    final centerX = width ~/ 2;
    final hipY = height ~/ 2;
    final hipRegion = width ~/ 3;
    
    int hipPixels = 0;
    for (int y = hipY - 10; y <= hipY + 10; y++) {
      for (int x = centerX - hipRegion; x < centerX; x++) {
        if (x >= 0 && y >= 0 && x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          if (brightness > 50 && brightness < 150) {
            hipPixels++;
          }
        }
      }
    }
    
    return hipPixels > 5 ? Offset((centerX - hipRegion/2) / width, hipY / height) : null;
  }
  
  Offset? _detectRightHip(img.Image image, int width, int height) {
    final centerX = width ~/ 2;
    final hipY = height ~/ 2;
    final hipRegion = width ~/ 3;
    
    int hipPixels = 0;
    for (int y = hipY - 10; y <= hipY + 10; y++) {
      for (int x = centerX; x < centerX + hipRegion; x++) {
        if (x >= 0 && y >= 0 && x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          if (brightness > 50 && brightness < 150) {
            hipPixels++;
          }
        }
      }
    }
    
    return hipPixels > 5 ? Offset((centerX + hipRegion/2) / width, hipY / height) : null;
  }
  
  Offset? _detectUdder(img.Image image, int width, int height) {
    final centerX = width ~/ 2;
    final lowerRegion = height * 2 ~/ 3;
    final udderWidth = width ~/ 4;
    
    int udderPixels = 0;
    for (int y = lowerRegion; y < height; y++) {
      for (int x = centerX - udderWidth; x < centerX + udderWidth; x++) {
        if (x >= 0 && y >= 0 && x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          if (brightness > 30 && brightness < 120) {
            udderPixels++;
          }
        }
      }
    }
    
    return udderPixels > 8 ? Offset(centerX / width, (lowerRegion + height) / 2 / height) : null;
  }
  
  // 🔹 Step 6: Structural Validation
  Map<String, dynamic> _validateStructure(Map<String, dynamic> keypoints) {
    debugPrint('[STRUCTURAL] Starting structural validation...');
    
    // Check udder visibility
    debugPrint('[STRUCTURAL] Checking udder visibility...');
    if (keypoints['udder'] == null) {
      debugPrint('[STRUCTURAL] REJECTED: Udder not visible');
      return {'rejected': true, 'reason': 'Udder not visible'};
    }
    debugPrint('[STRUCTURAL] Udder visible: ${(keypoints['udder'] as Offset).dy.toStringAsFixed(3)}');
    
    // Check rear angle (simplified - check if lower body is visible)
    debugPrint('[STRUCTURAL] Checking rear angle...');
    final rearAngleValid = _checkRearAngle(keypoints);
    debugPrint('[STRUCTURAL] Rear angle valid: $rearAngleValid');
    if (!rearAngleValid) {
      debugPrint('[STRUCTURAL] REJECTED: Wrong angle (rear view required)');
      return {'rejected': true, 'reason': 'Wrong angle (rear view required)'};
    }
    
    // Check body proportions
    debugPrint('[STRUCTURAL] Checking body proportions...');
    final proportionsValid = _checkBodyProportions(keypoints);
    debugPrint('[STRUCTURAL] Body proportions valid: $proportionsValid');
    if (!proportionsValid) {
      debugPrint('[STRUCTURAL] REJECTED: Not buffalo structure');
      return {'rejected': true, 'reason': 'Not buffalo structure'};
    }
    
    debugPrint('[STRUCTURAL] All structural checks passed');
    return {'rejected': false};
  }
  
  bool _checkRearAngle(Map<String, dynamic> keypoints) {
    // Simplified rear angle check - udder should be in lower portion
    final udder = keypoints['udder'];
    if (udder == null) {
      debugPrint('[REAR ANGLE] No udder found');
      return false;
    }
    
    final udderY = (udder as Offset).dy;
    final isValid = udderY > 0.6; // Udder should be in lower 40% of image
    debugPrint('[REAR ANGLE] Udder Y: ${udderY.toStringAsFixed(3)}, Valid: $isValid');
    return isValid;
  }
  
  bool _checkBodyProportions(Map<String, dynamic> keypoints) {
    final spine = keypoints['spine'];
    final leftHip = keypoints['leftHip'];
    final rightHip = keypoints['rightHip'];
    
    if (spine == null || leftHip == null || rightHip == null) {
      debugPrint('[BODY PROPORTIONS] Missing keypoints - Spine: $spine != null, LeftHip: $leftHip != null, RightHip: $rightHip != null');
      return false;
    }
    
    // Check if hips are reasonably spaced
    final leftX = (leftHip as Offset).dx;
    final rightX = (rightHip as Offset).dx;
    final hipDistance = (rightX - leftX).abs();
    
    // Hips should be reasonably spaced (not too close, not too far)
    final isValid = hipDistance > 0.1 && hipDistance < 0.5;
    debugPrint('[BODY PROPORTIONS] LeftX: ${leftX.toStringAsFixed(3)}, RightX: ${rightX.toStringAsFixed(3)}, Distance: ${hipDistance.toStringAsFixed(3)}, Valid: $isValid');
    return isValid;
  }
  
  // 🔹 Step 7: Confidence Scoring
  double _calculateFinalConfidence(double buffaloProb, double keypointConfidence, double qualityScore) {
    final finalConfidence = (buffaloProb * 0.5) + (keypointConfidence * 0.3) + (qualityScore * 0.2);
    debugPrint('[CONFIDENCE] Buffalo: ${buffaloProb.toStringAsFixed(3)}, Keypoints: ${keypointConfidence.toStringAsFixed(3)}, Quality: ${qualityScore.toStringAsFixed(3)}');
    debugPrint('[CONFIDENCE] Final: ${finalConfidence.toStringAsFixed(3)}');
    return finalConfidence;
  }
  
  // Helper methods for final steps
  Map<String, dynamic> _extractFeatures(img.Image image) {
    return {
      'body_condition': _assessBodyCondition(image),
      'udder_size': _assessUdderSize(image),
      'frame_size': _assessFrameSize(image),
      'breed_estimate': _estimateBreed(image),
    };
  }
  
  String _assessBodyCondition(img.Image image) {
    int healthyPixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final brightness = image.getPixel(x, y).r;
        if (brightness > 60 && brightness < 160) {
          healthyPixels++;
        }
      }
    }
    
    final ratio = healthyPixels / totalPixels;
    if (ratio > 0.6) return 'healthy';
    if (ratio > 0.4) return 'moderate';
    return 'thin';
  }
  
  String _assessUdderSize(img.Image image) {
    final centerX = image.width ~/ 2;
    final lowerRegion = image.height * 2 ~/ 3;
    final udderWidth = image.width ~/ 4;
    
    int udderPixels = 0;
    int totalLowerPixels = 0;
    
    for (int y = lowerRegion; y < image.height; y++) {
      for (int x = centerX - udderWidth; x < centerX + udderWidth; x++) {
        if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
          totalLowerPixels++;
          final brightness = image.getPixel(x, y).r;
          if (brightness > 30 && brightness < 120) {
            udderPixels++;
          }
        }
      }
    }
    
    final udderRatio = udderPixels / totalLowerPixels;
    if (udderRatio > 0.2) return 'large';
    if (udderRatio > 0.1) return 'medium';
    return 'small';
  }
  
  String _assessFrameSize(img.Image image) {
    int bodyPixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final brightness = image.getPixel(x, y).r;
        if (brightness > 50 && brightness < 180) {
          bodyPixels++;
        }
      }
    }
    
    final bodyRatio = bodyPixels / totalPixels;
    if (bodyRatio > 0.5) return 'large';
    if (bodyRatio > 0.3) return 'medium';
    return 'small';
  }
  
  String _estimateBreed(img.Image image) {
    int darkPixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final brightness = image.getPixel(x, y).r;
        if (brightness < 80) darkPixels++;
      }
    }
    
    final darkRatio = darkPixels / totalPixels;
    if (darkRatio > 0.6) return 'Murrah';
    if (darkRatio > 0.3) return 'Local/Desi';
    return 'Crossbreed';
  }
  
  Map<String, dynamic> _predictMilkProduction(
    Map<String, dynamic> features,
    String breed,
    int age,
    int lactation,
    int daysInMilk,
    String feed,
  ) {
    debugPrint('[MILK PREDICTION] Starting prediction...');
    
    // Base milk production by breed
    final breedFactors = {
      'Murrah': 15.0,
      'Local/Desi': 10.0,
      'Crossbreed': 12.0,
    };
    
    double baseMilk = breedFactors[breed] ?? 10.0;
    debugPrint('[MILK PREDICTION] Base milk for $breed: $baseMilk');
    
    // Adjust for age
    if (age < 3) {
      baseMilk *= 0.6;
    } else if (age >= 3 && age <= 7) {
      baseMilk *= 1.1;
    } else if (age > 10) {
      baseMilk *= 0.85;
    }
    
    // Adjust for lactation
    if (lactation == 1) {
      baseMilk *= 0.9;
    } else if (lactation >= 2 && lactation <= 4) {
      baseMilk *= 1.2;
    } else if (lactation >= 5) {
      baseMilk *= 0.8;
    }
    
    // Adjust for days in milk
    if (daysInMilk < 30) {
      baseMilk *= 0.7;
    } else if (daysInMilk >= 30 && daysInMilk <= 120) {
      baseMilk *= 1.3;
    } else if (daysInMilk > 240) {
      baseMilk *= 0.9;
    }
    
    // Adjust for feed
    final feedFactors = {
      'High Protein': 1.4,
      'Standard': 1.0,
      'Low': 0.6,
    };
    baseMilk *= feedFactors[feed] ?? 1.0;
    
    // Adjust for visual features
    final bodyCondition = features['body_condition'] as String;
    final udderSize = features['udder_size'] as String;
    
    if (bodyCondition == 'healthy') {
      baseMilk *= 1.2;
    } else if (bodyCondition == 'thin') {
      baseMilk *= 0.7;
    }
    
    if (udderSize == 'large') {
      baseMilk *= 1.3;
    } else if (udderSize == 'small') {
      baseMilk *= 0.7;
    }
    
    final predictedLiters = math.max(5.0, math.min(35.0, baseMilk));
    debugPrint('[MILK PREDICTION] Final prediction: $predictedLiters liters/day');
    
    return {
      'milk_per_day_liters': predictedLiters.roundToDouble(),
      'confidence': 0.85,
    };
  }
  
  BuffaloAnalysisResult _createRejectResult(String reason) {
    return BuffaloAnalysisResult(
      status: 'rejected',
      reason: reason,
      confidence: 0.0,
      animal: 'unknown',
    );
  }
}