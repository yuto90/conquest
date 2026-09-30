import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Selects a count through the setup slider's real keyboard controls.
Future<void> setIslandCount(WidgetTester tester, int count) async {
  final finder = find.byKey(const ValueKey('island-count-slider-control'));
  await tester.ensureVisible(finder);
  final slider = tester.widget<Slider>(finder);
  expect(count, inInclusiveRange(slider.min, slider.max));
  expect(slider.focusNode, isNotNull);
  final focusNode = slider.focusNode!;

  // Traverse focus rather than invoking the slider's callbacks directly.
  for (var attempt = 0; !focusNode.hasFocus && attempt < 30; attempt++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(focusNode.hasFocus, isTrue);

  final currentCount = tester.widget<Slider>(finder).value.round();
  final key = count > currentCount
      ? LogicalKeyboardKey.arrowUp
      : LogicalKeyboardKey.arrowDown;
  for (var step = 0; step < (count - currentCount).abs(); step++) {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }
  expect(tester.widget<Slider>(finder).value, count.toDouble());
}
