import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageBasedMilkCalculator {
  static const int _sampleStep = 2;
  
  Future<Map<String, dynamic>> calculateMilkFromImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return {'error': 'Could not decode image'};
      }
      
      debugPrint('[IMAGE MILK CALCULATOR] Starting image analysis...');
      
      // Analyze visual milk indicators
      final udderAnalysis = _analyzeUdderFromImage(image);
      final bodyAnalysis = _analyzeBodyConditionFromImage(image);
      final buildAnalysis = _assessLocalBuffaloBuild(image);
      final sizeAnalysis = _analyzeSizeFromImage(image);
      
      debugPrint('[IMAGE MILK CALCULATOR] Udder: $udderAnalysis');
      debugPrint('[IMAGE MILK CALCULATOR] Body: $bodyAnalysis');
      debugPrint('[IMAGE MILK CALCULATOR] Build: $buildAnalysis');
      debugPrint('[IMAGE MILK CALCULATOR] Size: $sizeAnalysis');
      
      final milkCalculation = _calculateMilkFromVisuals(
        udderAnalysis,
        bodyAnalysis,
        buildAnalysis,
        sizeAnalysis,
      );
      
      return {
        'milk_per_day_liters': milkCalculation['milk'],
        'confidence': milkCalculation['confidence'],
        'analysis': {
          'udder_size': udderAnalysis['size'],
          'udder_condition': udderAnalysis['condition'],
          'body_condition': bodyAnalysis['condition'],
          'buffalo_type': 'Local',
          'size_category': sizeAnalysis['category'],
          'build_score': buildAnalysis['score'],
          'visual_score': milkCalculation['visual_score'],
        }
      };
      
    } catch (e) {
      debugPrint('[IMAGE MILK CALCULATOR] Error: $e');
      return {'error': e.toString()};
    }
  }
  
  // Analyze udder from image
  Map<String, dynamic> _analyzeUdderFromImage(img.Image image) {
    final width = image.width;
    final height = image.height;
    final centerX = width ~/ 2;
    final lowerRegion = height * 2 ~/ 3;
    
    int udderPixels = 0;
    int swollenPixels = 0;
    int veinPixels = 0;
    int totalUdderArea = 0;
    
    // Analyze lower third of image where udder is located
    for (int y = lowerRegion; y < height; y += _sampleStep) {
      for (int x = centerX - width ~/ 4; x < centerX + width ~/ 4; x += _sampleStep) {
        if (x >= 0 && x < width && y >= 0 && y < height) {
          totalUdderArea++;
          final pixel = image.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          final brightness = (r + g + b) / 3;
          
          // Udder tissue detection
          if (brightness > 30 && brightness < 140) {
            udderPixels++;
          }
          
          // Swollen/engorged udder detection
          if (r > 120 && g > 100 && b > 110 && brightness > 80) {
            swollenPixels++;
          }
          
          // Vein detection (indicates milk production)
          if (r > 80 && r < 120 && g > 70 && g < 100 && b > 80 && b < 110) {
            veinPixels++;
          }
        }
      }
    }
    
    final udderRatio = udderPixels / totalUdderArea;
    final swollenRatio = swollenPixels / totalUdderArea;
    final veinRatio = veinPixels / totalUdderArea;
    
    // Determine udder size
    String udderSize;
    double udderScore = 0;
    
    if (udderRatio > 0.4) {
      udderSize = 'large';
      udderScore = 0.9;
    } else if (udderRatio > 0.25) {
      udderSize = 'medium';
      udderScore = 0.7;
    } else if (udderRatio > 0.15) {
      udderSize = 'small';
      udderScore = 0.5;
    } else {
      udderSize = 'very_small';
      udderScore = 0.3;
    }
    
    // Determine udder condition
    String udderCondition;
    if (swollenRatio > 0.3 && veinRatio > 0.2) {
      udderCondition = 'excellent'; // Well-engorged with visible veins
      udderScore += 0.2;
    } else if (swollenRatio > 0.2 || veinRatio > 0.15) {
      udderCondition = 'good'; // Moderate engorgement
      udderScore += 0.1;
    } else if (swollenRatio > 0.1) {
      udderCondition = 'fair'; // Some engorgement
    } else {
      udderCondition = 'poor'; // Not engorged
      udderScore -= 0.1;
    }
    
    return {
      'size': udderSize,
      'condition': udderCondition,
      'score': udderScore,
      'udder_ratio': udderRatio,
      'swollen_ratio': swollenRatio,
      'vein_ratio': veinRatio
    };
  }
  
  // Analyze body condition from image
  Map<String, dynamic> _analyzeBodyConditionFromImage(img.Image image) {
    int healthyPixels = 0;
    int thinPixels = 0;
    int obesePixels = 0;
    int totalPixels = image.width * image.height;
    
    int sampledPixels = 0;
    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final brightness = (r + g + b) / 3;
        
        // Healthy body condition detection
        if (brightness > 40 && brightness < 120) {
          healthyPixels++;
        }
        
        // Thin body condition detection
        if (brightness > 100) {
          thinPixels++;
        }
        
        // Obese body condition detection
        if (brightness < 30) {
          obesePixels++;
        }
      }
    }
    
    final effectiveTotal = sampledPixels == 0 ? totalPixels : sampledPixels;
    final healthyRatio = healthyPixels / effectiveTotal;
    final thinRatio = thinPixels / effectiveTotal;
    final obeseRatio = obesePixels / effectiveTotal;
    
    String bodyCondition;
    double bodyScore = 0;
    
    if (healthyRatio > 0.4 && thinRatio < 0.2 && obeseRatio < 0.1) {
      bodyCondition = 'healthy';
      bodyScore = 0.8;
    } else if (thinRatio > 0.3) {
      bodyCondition = 'thin';
      bodyScore = 0.5;
    } else if (obeseRatio > 0.2) {
      bodyCondition = 'obese';
      bodyScore = 0.6;
    } else {
      bodyCondition = 'average';
      bodyScore = 0.7;
    }
    
    return {
      'condition': bodyCondition,
      'score': bodyScore,
      'healthy_ratio': healthyRatio,
      'thin_ratio': thinRatio,
      'obese_ratio': obeseRatio
    };
  }
  
  /// Visual build quality for local buffalo (not breed/race classification).
  Map<String, dynamic> _assessLocalBuffaloBuild(img.Image image) {
    int bodyPixels = 0;
    int sampledPixels = 0;

    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        if (brightness > 25 && brightness < 150) {
          bodyPixels++;
        }
      }
    }

    final bodyRatio = sampledPixels == 0 ? 0.0 : bodyPixels / sampledPixels;
    double score;
    if (bodyRatio > 0.55) {
      score = 0.85;
    } else if (bodyRatio > 0.35) {
      score = 0.7;
    } else {
      score = 0.55;
    }

    return {
      'type': 'Local',
      'score': score,
      'body_coverage': bodyRatio,
    };
  }
  
  // Analyze size from image
  Map<String, dynamic> _analyzeSizeFromImage(img.Image image) {
    int bodyPixels = 0;
    int totalPixels = image.width * image.height;
    
    int sampledPixels = 0;
    for (int y = 0; y < image.height; y += _sampleStep) {
      for (int x = 0; x < image.width; x += _sampleStep) {
        sampledPixels++;
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        if (brightness > 20 && brightness < 160) {
          bodyPixels++;
        }
      }
    }
    
    final effectiveTotal = sampledPixels == 0 ? totalPixels : sampledPixels;
    final bodyRatio = bodyPixels / effectiveTotal;
    
    String sizeCategory;
    double sizeScore = 0;
    
    if (bodyRatio > 0.7) {
      sizeCategory = 'large';
      sizeScore = 0.8;
    } else if (bodyRatio > 0.5) {
      sizeCategory = 'medium';
      sizeScore = 0.7;
    } else if (bodyRatio > 0.3) {
      sizeCategory = 'small';
      sizeScore = 0.6;
    } else {
      sizeCategory = 'very_small';
      sizeScore = 0.4;
    }
    
    return {
      'category': sizeCategory,
      'score': sizeScore,
      'body_ratio': bodyRatio
    };
  }
  
  // Calculate milk from visual analysis
  Map<String, dynamic> _calculateMilkFromVisuals(
    Map<String, dynamic> udderAnalysis,
    Map<String, dynamic> bodyAnalysis,
    Map<String, dynamic> buildAnalysis,
    Map<String, dynamic> sizeAnalysis,
  ) {
    const double baseMilkLocal = 10.0;
    double baseMilk = baseMilkLocal;

    debugPrint('[MILK CALCULATION] Base milk (local buffalo): $baseMilk');
    
    // Apply udder adjustments
    final udderScore = udderAnalysis['score'] as double;
    if (udderScore > 0.8) {
      baseMilk *= 1.4; // Excellent udder
    } else if (udderScore > 0.6) {
      baseMilk *= 1.2; // Good udder
    } else if (udderScore > 0.4) {
      baseMilk *= 1.0; // Fair udder
    } else {
      baseMilk *= 0.7; // Poor udder
    }
    
    // Apply body condition adjustments
    final bodyScore = bodyAnalysis['score'] as double;
    if (bodyScore > 0.7) {
      baseMilk *= 1.1; // Healthy body
    } else if (bodyScore > 0.5) {
      baseMilk *= 0.9; // Average body
    } else {
      baseMilk *= 0.7; // Thin/poor body
    }
    
    // Apply size adjustments
    final sizeScore = sizeAnalysis['score'] as double;
    if (sizeScore > 0.7) {
      baseMilk *= 1.2; // Large frame
    } else if (sizeScore > 0.5) {
      baseMilk *= 1.0; // Medium frame
    } else {
      baseMilk *= 0.8; // Small frame
    }
    
    final buildScore = buildAnalysis['score'] as double;
    if (buildScore > 0.75) {
      baseMilk *= 1.1;
    } else if (buildScore < 0.6) {
      baseMilk *= 0.9;
    }

    double finalMilk = math.max(3.0, math.min(25.0, baseMilk));

    double visualScore = (udderScore + bodyScore + buildScore + sizeScore) / 4;
    double confidence = visualScore * 0.9; // Image-based confidence
    
    debugPrint('[MILK CALCULATION] Final milk: $finalMilk liters/day');
    debugPrint('[MILK CALCULATION] Visual score: $visualScore, Confidence: $confidence');
    
    return {
      'milk': finalMilk.roundToDouble(),
      'confidence': confidence,
      'visual_score': visualScore
    };
  }
}
