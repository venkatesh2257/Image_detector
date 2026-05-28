import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_detector/services/classifier_service_new.dart';

final bool _isCi = Platform.environment.containsKey('CI');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rules gate passes on 9 lit rear buffalo',
    () async {
    const path = r'assets/images/animal photos/9 lit/k3 (2).jpg';
    if (!File(path).existsSync()) return;

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(result.predictionSource, isNot('rules_gate'));
    expect(result.label, isNot('No Buffalo Detected'));
    },
    skip: _isCi,
  );

  test(
    'rules gate passes on 10 lit rear buffalo (dark hide)',
    () async {
    const path = r'assets/images/animal photos/10 lit/k3 (2).jpg';
    if (!File(path).existsSync()) return;

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(
      result.predictionSource,
      isNot('rules_gate'),
      reason: result.diagnostics?.rulesRejectReason ?? result.label,
    );
    expect(result.label, isNot('No Buffalo Detected'));
    },
    skip: _isCi,
  );

  test(
    'rules gate rejects centered portrait selfie',
    () async {
    final dir = Directory.systemTemp.createTempSync('buffalo_gate_selfie');
    final path = '${dir.path}/fake_selfie.jpg';
    final image = img.Image(width: 400, height: 700);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final inFace = x > 120 &&
            x < 280 &&
            y > 80 &&
            y < 320;
        final inTorso = x > 90 &&
            x < 310 &&
            y >= 320 &&
            y < 520;
        image.setPixel(
          x,
          y,
          inFace || inTorso
              ? img.ColorRgb8(205, 165, 135)
              : img.ColorRgb8(40, 42, 48),
        );
      }
    }
    File(path).writeAsBytesSync(img.encodeJpg(image));

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(result.predictionSource, 'rules_gate');
    expect(result.label, 'No Buffalo Detected');

    dir.deleteSync(recursive: true);
    },
    skip: _isCi,
  );

  test(
    'rules gate rejects human skin tone photo',
    () async {
    final dir = Directory.systemTemp.createTempSync('buffalo_gate_human');
    final path = '${dir.path}/fake_human.jpg';
    final image = img.Image(width: 480, height: 640);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final isUpper = y < image.height * 0.55;
        image.setPixel(
          x,
          y,
          isUpper
              ? img.ColorRgb8(210, 170, 140)
              : img.ColorRgb8(90, 95, 100),
        );
      }
    }
    File(path).writeAsBytesSync(img.encodeJpg(image));

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(result.predictionSource, 'rules_gate');
    expect(result.label, 'No Buffalo Detected');

    dir.deleteSync(recursive: true);
    },
    skip: _isCi,
  );

  test(
    'rules gate rejects real user laptop screenshot',
    () async {
    const path = 'test/fixtures/user_laptop.png';
    if (!File(path).existsSync()) return;

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(result.predictionSource, 'rules_gate');
    expect(result.label, 'No Buffalo Detected');
    },
    skip: _isCi,
  );

  test(
    'rules gate rejects realistic laptop on desk photo',
    () async {
    final dir = Directory.systemTemp.createTempSync('buffalo_gate_laptop');
    final path = '${dir.path}/fake_laptop_desk.jpg';
    final image = img.Image(width: 640, height: 900);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final yn = y / image.height;
        final xn = x / image.width;
        img.ColorRgb8 color;
        if (yn < 0.32) {
          color = img.ColorRgb8(235, 238, 242);
        } else if (yn > 0.78) {
          color = img.ColorRgb8(120, 85, 55);
        } else {
          final inLaptop = xn > 0.22 &&
              xn < 0.78 &&
              yn > 0.34 &&
              yn < 0.76;
          if (!inLaptop) {
            color = img.ColorRgb8(180, 175, 170);
          } else {
            final inScreen = xn > 0.28 &&
                xn < 0.72 &&
                yn > 0.40 &&
                yn < 0.66;
            final inBezel = !inScreen;
            if (inBezel) {
              color = img.ColorRgb8(22, 24, 28);
            } else {
              final ui = ((x + y) % 40);
              color = ui < 10
                  ? img.ColorRgb8(90, 160, 220)
                  : ui < 20
                      ? img.ColorRgb8(180, 90, 200)
                      : img.ColorRgb8(240, 245, 250);
            }
          }
        }
        image.setPixel(x, y, color);
      }
    }
    File(path).writeAsBytesSync(img.encodeJpg(image));

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(result.predictionSource, 'rules_gate');
    expect(result.label, 'No Buffalo Detected');

    dir.deleteSync(recursive: true);
    },
    skip: _isCi,
  );

  test(
    'rules gate rejects flat gray laptop-like photo',
    () async {
    final dir = Directory.systemTemp.createTempSync('buffalo_gate_test');
    final path = '${dir.path}/fake_laptop.jpg';
    final image = img.Image(width: 640, height: 480);
    img.fill(image, color: img.ColorRgb8(130, 132, 135));
    File(path).writeAsBytesSync(img.encodeJpg(image));

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(result.predictionSource, 'rules_gate');
    expect(result.label, 'No Buffalo Detected');

    dir.deleteSync(recursive: true);
    },
    skip: _isCi,
  );

  test('rules gate passes on user buffalo screenshot if present', () async {
    const path = 'test_user_buffalo.png';
    if (!File(path).existsSync()) return;

    final service = ClassifierService();
    await service.loadModel();
    final result = await service.classifyImage(path);

    expect(
      result.predictionSource,
      isNot('rules_gate'),
      reason: result.diagnostics?.rulesRejectReason ?? result.label,
    );
    expect(result.label, isNot('No Buffalo Detected'));
  });
}
