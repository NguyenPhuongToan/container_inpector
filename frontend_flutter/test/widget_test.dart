import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';

void main() {
  testWidgets('Login screen is the default entry point',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ContainerInspectionApp(),
    );

    expect(
      find.text('Container Inspection'),
      findsOneWidget,
    );
    expect(find.text('Sign In'), findsOneWidget);
  });
}
