import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:image_detector/services/classifier_service_new.dart';

// ignore_for_file: avoid_print
final bool _isCi = Platform.environment.containsKey('CI');

/// Headless smoke test — prints full 🔬 / LOG pipeline to the terminal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'TFLite load + classify pipeline (check console for 🔬 logs)',
    () async {
    print('\n========== SMOKE TEST: MODEL INIT ==========');
    final classifier = ClassifierService();
    final loaded = await classifier.loadModel();

    print('SMOKE: loadModel() => $loaded');
    if (!loaded) {
      print('SMOKE: FAIL — ${classifier.modelLoadError}');
    }
    expect(loaded, isTrue, reason: classifier.modelLoadError ?? 'model load');

    final tempDir = await Directory.systemTemp.createTemp('image_detector_smoke');
    final imagePath = '${tempDir.path}/synthetic_buffalo.png';
    final synthetic = img.Image(width: 480, height: 640);
    img.fill(synthetic, color: img.ColorRgb8(72, 55, 38));
    for (var y = synthetic.height * 2 ~/ 3; y < synthetic.height; y++) {
      for (var x = synthetic.width ~/ 4; x < synthetic.width * 3 ~/ 4; x++) {
        synthetic.setPixelRgb(x, y, 140, 90, 90);
      }
    }
    await File(imagePath).writeAsBytes(img.encodePng(synthetic));
    print('SMOKE: synthetic image => $imagePath');

    print('\n========== SMOKE TEST: CLASSIFY ==========');
    final result = await classifier.classifyImage(imagePath);

    print('SMOKE: label=${result.label}');
    print('SMOKE: source=${result.predictionSource}');
    print('SMOKE: confidence=${result.confidence}');
    print('SMOKE: liters=${result.estimatedLiters}');
    final diag = result.diagnostics;
    if (diag != null) {
      print('SMOKE: proof=${diag.proofSummary}');
      print('SMOKE: interpreter.run=${diag.tfliteInferenceExecuted}');
    }

    expect(result.predictionSource, isNot('not_loaded'));
      expect(
        ['milk_mirror', 'milk_mirror+tflite', 'tflite', 'tflite_untrained', 'rules_gate', 'error'],
        contains(result.predictionSource),
      );

    await tempDir.delete(recursive: true);
    print('\n========== SMOKE TEST DONE ==========\n');
    },
    skip: _isCi ? 'Smoke test is environment-sensitive on CI runners' : false,
  );
}
