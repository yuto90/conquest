import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conquest/main.dart';

void main() {
  testWidgets('Conquest ready screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('T A P  T O  P L A Y'), findsOneWidget);
  });
}
