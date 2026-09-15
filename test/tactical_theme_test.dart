import 'package:conquest/main.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps supported, regional, and unsupported locales to font sets', () {
    final cases = <Locale, (String, List<String>)>{
      const Locale('ja'): (
        TacticalTypography.notoSansJpFamily,
        <String>[TacticalTypography.robotoFamily],
      ),
      const Locale('ja', 'JP'): (
        TacticalTypography.notoSansJpFamily,
        <String>[TacticalTypography.robotoFamily],
      ),
      const Locale('en'): (
        TacticalTypography.robotoFamily,
        <String>[TacticalTypography.notoSansJpFamily],
      ),
      const Locale('en', 'US'): (
        TacticalTypography.robotoFamily,
        <String>[TacticalTypography.notoSansJpFamily],
      ),
      const Locale('en', 'GB'): (
        TacticalTypography.robotoFamily,
        <String>[TacticalTypography.notoSansJpFamily],
      ),
      const Locale('fr', 'FR'): (
        TacticalTypography.robotoFamily,
        <String>[TacticalTypography.notoSansJpFamily],
      ),
    };

    for (final entry in cases.entries) {
      final typography = TacticalTypography.forLocale(entry.key);
      expect(typography.fontFamily, entry.value.$1);
      expect(typography.fontFamilyFallback, entry.value.$2);
      expect(
        typography.display(fontWeight: FontWeight.w600).fontFamily,
        entry.value.$1,
      );
      expect(
        typography.body(fontWeight: FontWeight.w700).fontFamilyFallback,
        entry.value.$2,
      );
      expect(
        typography.mono(fontWeight: FontWeight.w800).fontFamily,
        entry.value.$1,
      );
    }
  });

  testWidgets('uses the resolved localization locale for the app theme', (
    tester,
  ) async {
    for (final testCase in <(Locale, String)>[
      (const Locale('ja', 'JP'), TacticalTypography.notoSansJpFamily),
      (const Locale('en', 'US'), TacticalTypography.robotoFamily),
      (const Locale('en', 'GB'), TacticalTypography.robotoFamily),
      (const Locale('fr', 'FR'), TacticalTypography.robotoFamily),
    ]) {
      await tester.pumpWidget(MyApp(locale: testCase.$1));
      await tester.pump();

      final title = find.byKey(const ValueKey('title-view'));
      final theme = Theme.of(tester.element(title));
      final bodyStyle = theme.textTheme.bodyMedium!;
      expect(bodyStyle.fontFamily, testCase.$2);
      expect(bodyStyle.fontFamilyFallback, <String>[
        testCase.$2 == TacticalTypography.notoSansJpFamily
            ? TacticalTypography.robotoFamily
            : TacticalTypography.notoSansJpFamily,
      ]);
      expect(
        tester.widget<Text>(find.text('START')).style!.fontFamily,
        testCase.$2,
      );
      expect(
        tester
            .widget<Text>(find.text('A STRATEGY FOR A WIDER WORLD'))
            .style!
            .fontFamily,
        testCase.$2,
      );
    }
  });
}
