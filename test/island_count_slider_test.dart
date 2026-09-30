import 'dart:ui' show SemanticsAction, Tristate;

import 'package:conquest/game/game_state.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/ui/island_count_slider.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sliderKey = ValueKey('island-count-slider-control');
const _semanticsKey = ValueKey('island-count-slider');

Future<void> _pumpSlider(
  WidgetTester tester, {
  int initialValue = 10,
  Locale locale = const Locale('en'),
  double width = 330,
  double textScale = 1,
  bool disableAnimations = false,
  FocusNode? focusNode,
  ValueChanged<int>? onChanged,
  bool rebuildOnChanged = true,
}) async {
  var value = initialValue;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTacticalTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: disableAnimations,
                ),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    final l10n = AppLocalizations.of(context);
                    return IslandCountSlider(
                      value: value,
                      focusNode: focusNode,
                      title: l10n.islandCountLabel,
                      countLabel: (count) =>
                          l10n.islandCountChoice(count: count),
                      onChanged: (count) {
                        onChanged?.call(count);
                        if (rebuildOnChanged) setState(() => value = count);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset _positionFor(WidgetTester tester, int count) {
  final rect = tester.getRect(find.byKey(_sliderKey));
  return Offset(
    rect.left +
        40 +
        (rect.width - 80) *
            (count - GameConfiguration.minIslandCount) /
            (GameConfiguration.maxIslandCount -
                GameConfiguration.minIslandCount),
    rect.center.dy,
  );
}

void _performAction(WidgetTester tester, SemanticsAction action) {
  final node = tester.getSemantics(find.byKey(_semanticsKey));
  node.owner!.performAction(node.id, action);
}

void main() {
  testWidgets('matches the pill, cream thumb, sea color and discrete range', (
    tester,
  ) async {
    await _pumpSlider(tester);
    final slider = tester.widget<Slider>(find.byKey(_sliderKey));
    final theme = SliderTheme.of(tester.element(find.byKey(_sliderKey)));

    expect(slider.value, 10);
    expect(slider.min, 6);
    expect(slider.max, 20);
    expect(slider.divisions, 14);
    expect(theme.trackHeight, 32);
    expect(theme.activeTrackColor, TacticalPalette.seaDeep);
    expect(theme.thumbColor, TacticalPalette.paper);
    expect((theme.thumbShape! as RoundSliderThumbShape).enabledThumbRadius, 20);
    expect(theme.showValueIndicator, ShowValueIndicator.never);
    expect(find.text('10 islands'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('7'), findsNothing);
    expect(find.text('19'), findsNothing);
  });

  for (final width in [260.0, 330.0]) {
    testWidgets('every integer is reachable by tap at width $width', (
      tester,
    ) async {
      final changes = <int>[];
      await _pumpSlider(tester, width: width, onChanged: changes.add);
      for (var count = 6; count <= 20; count++) {
        await tester.tapAt(_positionFor(tester, count));
        await tester.pumpAndSettle();
        expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, count);
        expect(find.text('$count islands'), findsOneWidget);
      }
      expect(changes, List.generate(15, (index) => index + 6));
    });
  }

  testWidgets('dot marks fit all fifteen positions on narrow screens', (
    tester,
  ) async {
    for (final width in [200.0, 260.0, 330.0]) {
      await _pumpSlider(tester, width: width);
      final theme = SliderTheme.of(tester.element(find.byKey(_sliderKey)));
      final tickWidth = theme.tickMarkShape!
          .getPreferredSize(isEnabled: true, sliderTheme: theme)
          .width;
      expect((width - 80) / 14, greaterThanOrEqualTo(3 * tickWidth));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('pointer focus and arrows change exactly one island at a time', (
    tester,
  ) async {
    final changes = <int>[];
    await _pumpSlider(tester, initialValue: 6, onChanged: changes.add);
    await tester.tapAt(_positionFor(tester, 6));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Slider>(find.byKey(_sliderKey)).focusNode!.hasFocus,
      isTrue,
    );
    for (var count = 7; count <= 20; count++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, count);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes, List.generate(14, (index) => index + 7));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, 19);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, 20);
    for (var count = 19; count >= 6; count--) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, count);
    }
    final callsAtMinimum = changes.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(changes, hasLength(callsAtMinimum));
  });

  for (final locale in ['en', 'ja']) {
    testWidgets('localized semantics step once and respect bounds: $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpSlider(tester, initialValue: 6, locale: Locale(locale));
        String label(int count) =>
            locale == 'ja' ? '$count島' : '$count islands';
        var node = tester.getSemantics(find.byKey(_semanticsKey));
        expect(node.label, locale == 'ja' ? '島数' : 'Island Count');
        expect(node.value, label(6));
        expect(node.increasedValue, label(7));
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.decrease),
          isFalse,
        );
        _performAction(tester, SemanticsAction.focus);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(find.byKey(_semanticsKey))
              .getSemanticsData()
              .flagsCollection
              .isFocused,
          Tristate.isTrue,
        );
        for (var count = 7; count <= 20; count++) {
          _performAction(tester, SemanticsAction.increase);
          await tester.pumpAndSettle();
          node = tester.getSemantics(find.byKey(_semanticsKey));
          expect(node.value, label(count));
          expect(node.decreasedValue, label(count - 1));
        }
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.increase),
          isFalse,
        );
        _performAction(tester, SemanticsAction.decrease);
        await tester.pumpAndSettle();
        expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, 19);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'one drag crosses all counts without duplicates; reduced motion '
      '$reducedMotion',
      (tester) async {
        final changes = <int>[];
        await _pumpSlider(
          tester,
          initialValue: 6,
          disableAnimations: reducedMotion,
          onChanged: changes.add,
        );
        final element = tester.element(find.byKey(_sliderKey));
        final gesture = await tester.startGesture(_positionFor(tester, 6));
        await tester.pump();
        for (var count = 7; count <= 20; count++) {
          await gesture.moveTo(_positionFor(tester, count));
          await gesture.moveBy(const Offset(0.1, 0));
          await tester.pump();
          expect(tester.element(find.byKey(_sliderKey)), same(element));
        }
        for (var count = 19; count >= 6; count--) {
          await gesture.moveTo(_positionFor(tester, count));
          await tester.pump();
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(changes, [
          ...List.generate(14, (index) => index + 7),
          ...List.generate(14, (index) => 19 - index),
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('same-integer events do not repeat before owner rebuild', (
    tester,
  ) async {
    final changes = <int>[];
    await _pumpSlider(
      tester,
      initialValue: 6,
      rebuildOnChanged: false,
      onChanged: changes.add,
    );
    final gesture = await tester.startGesture(_positionFor(tester, 6));
    for (var count = 7; count <= 10; count++) {
      await gesture.moveTo(_positionFor(tester, count));
      await gesture.moveBy(const Offset(0.1, 0));
      await gesture.moveBy(const Offset(-0.1, 0));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, [7, 8, 9, 10]);
  });

  testWidgets('external focus nodes can be replaced without being disposed', (
    tester,
  ) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await _pumpSlider(tester, focusNode: first);
    first.requestFocus();
    await tester.pump();
    expect(first.hasFocus, isTrue);
    await _pumpSlider(tester, focusNode: second);
    second.requestFocus();
    await tester.pump();
    expect(second.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(() => first.addListener(() {}), returnsNormally);
    expect(() => second.addListener(() {}), returnsNormally);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'ja']) {
    testWidgets(
      'localized current value fits narrow large-text layout: $locale',
      (tester) async {
        await _pumpSlider(
          tester,
          initialValue: 20,
          locale: Locale(locale),
          width: 200,
          textScale: 3,
        );
        expect(
          find.text(locale == 'ja' ? '20島' : '20 islands'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
