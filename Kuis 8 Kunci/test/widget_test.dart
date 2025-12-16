// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kuis_8_kunci/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Build the app and ensure it renders without errors.
    await tester.pumpWidget(const MyApp());

    // Expect a MaterialApp to be present as the root widget.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
