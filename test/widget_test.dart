import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:image_detector/firebase_options.dart';
import 'package:image_detector/main.dart';

final bool _isCi = Platform.environment.containsKey('CI');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
  });

  testWidgets(
    'Detector app renders Milk Mirror home',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ImageDetectorApp());
      await tester.pump();
      // Model init + header/carousel animations (flutter_animate).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('MILK MIRROR'), findsOneWidget);
      expect(
        find.textContaining('BOOTING AI').evaluate().isNotEmpty ||
            find.textContaining('AI ONLINE').evaluate().isNotEmpty,
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
    skip: _isCi,
  );
}
