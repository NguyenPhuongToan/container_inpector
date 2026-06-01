import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/screens/login_screen.dart';

void main() {
  testWidgets('Login screen is the default entry point',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(
      find.text('Container Inspection'),
      findsOneWidget,
    );
    expect(find.text('Sign In'), findsOneWidget);
  });
}
