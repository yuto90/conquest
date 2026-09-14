import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Enters setup through the real title action after mounting a fresh app.
/// A locale or viewport rebuild may already be showing the current match.
Future<void> openMatchSetup(WidgetTester tester) async {
  final start = find.byKey(const ValueKey('title-start'));
  if (start.evaluate().isEmpty) return;
  await tester.ensureVisible(start);
  await tester.tap(start);
  await tester.pump();
}
