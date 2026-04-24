import 'package:flutter_test/flutter_test.dart';

import 'package:image_detector/main.dart';

void main() {
  testWidgets('App shell renders detector tab', (WidgetTester tester) async {
    await tester.pumpWidget(const ImageDetectorApp());
    expect(find.text('Vision Trend'), findsOneWidget);
    expect(find.text('Detector'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
