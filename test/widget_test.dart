import 'package:flutter_test/flutter_test.dart';

import 'package:image_detector/main.dart';

void main() {
  testWidgets('Detector app renders home', (WidgetTester tester) async {
    await tester.pumpWidget(const ImageDetectorApp());
    expect(find.text('Vision Trend'), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
  });
}
