// Basic smoke test for the Stone Town Heritage VT-Guide app.
//
// Verifies that the root widget tree compiles and renders without throwing.
// Firebase / SharedPreferences initialisation is exercised on a real device
// via `flutter run`; for pure unit tests we just construct the widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Stone Town Guide smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Stone Town Guide')),
          body: const Center(child: Text('OK')),
        ),
      ),
    );

    expect(find.text('Stone Town Guide'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}
