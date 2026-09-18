import 'dart:ui' show SemanticsAction, Tristate;

import 'package:conquest/game/game_state.dart';
import 'package:conquest/ui/cpu_difficulty_slider.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders four ordered labels and exposes the current value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const _Harness());

    for (final difficulty in CpuDifficulty.values) {
      expect(
        find.byKey(ValueKey('cpu-difficulty-${difficulty.name}')),
        findsOneWidget,
      );
    }
    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));
    expect(slider, findsOneWidget);

    final node = tester.getSemantics(slider);
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(node.label, 'CPU難易度');
    expect(node.value, 'Normal');
    expect(node.increasedValue, 'Hard');
    expect(node.decreasedValue, 'Easy');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    semantics.dispose();
  });

  testWidgets('selects labels and notifies only when the difficulty changes', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-hard')));
    await tester.pump();
    expect(_changes, <CpuDifficulty>[CpuDifficulty.hard]);

    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-hard')));
    await tester.pump();
    expect(_changes, <CpuDifficulty>[CpuDifficulty.hard]);
  });

  testWidgets('maps every label to its matching difficulty', (tester) async {
    await tester.pumpWidget(const _Harness());

    for (final difficulty in CpuDifficulty.values) {
      await tester.tap(
        find.byKey(ValueKey('cpu-difficulty-${difficulty.name}')),
      );
      await tester.pump();
      expect(_testValue, difficulty);
    }
  });

  testWidgets('uses purple for Hard and returns to the sea color', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    final hardLabel = find.byKey(const ValueKey('cpu-difficulty-hard'));
    final slider = find.byKey(const ValueKey('cpu-difficulty-slider-control'));

    Text hardText() => tester.widget<Text>(
      find.descendant(of: hardLabel, matching: find.byType(Text)),
    );

    expect(hardText().style!.color, CpuDifficultySlider.hardLabelColor);
    expect(
      tester
          .widget<SliderTheme>(
            find.ancestor(of: slider, matching: find.byType(SliderTheme)),
          )
          .data
          .activeTrackColor,
      TacticalPalette.seaDeep,
    );

    await tester.tap(hardLabel);
    await tester.pump();
    expect(hardText().style!.color, CpuDifficultySlider.hardLabelColor);
    expect(
      tester
          .widget<SliderTheme>(
            find.ancestor(of: slider, matching: find.byType(SliderTheme)),
          )
          .data
          .activeTrackColor,
      CpuDifficultySlider.hardTrackColor,
    );

    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-normal')));
    await tester.pump();
    expect(
      tester
          .widget<SliderTheme>(
            find.ancestor(of: slider, matching: find.byType(SliderTheme)),
          )
          .data
          .activeTrackColor,
      TacticalPalette.seaDeep,
    );
  });

  testWidgets('snaps drag positions and clamps both ends', (tester) async {
    await tester.pumpWidget(const _Harness());
    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));

    await tester.drag(slider, const Offset(1000, 0));
    await tester.pump();
    expect(_testValue, CpuDifficulty.hard);

    await tester.drag(slider, const Offset(-1000, 0));
    await tester.pump();
    expect(_testValue, CpuDifficulty.veryEasy);
  });

  testWidgets('supports keyboard and semantics increment/decrement', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const _Harness());
    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));

    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    harness.focusNode.requestFocus();
    await tester.pump();
    expect(
      tester.getSemantics(slider).getSemanticsData().flagsCollection.isFocused,
      Tristate.isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_testValue, CpuDifficulty.hard);

    final node = tester.getSemantics(slider);
    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await tester.pump();
    expect(_testValue, CpuDifficulty.normal);
    semantics.dispose();
  });

  testWidgets('keeps the control usable at narrow widths with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(width: 280, disableAnimations: true),
    );

    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));
    final sliderRect = tester.getRect(slider);
    for (final difficulty in CpuDifficulty.values) {
      final labelRect = tester.getRect(
        find.byKey(ValueKey('cpu-difficulty-${difficulty.name}')),
      );
      expect(labelRect.left, greaterThanOrEqualTo(sliderRect.left));
      expect(labelRect.right, lessThanOrEqualTo(sliderRect.right));
    }

    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-hard')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('cpu-difficulty-reduced-motion-3')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({this.width, this.disableAnimations = false});

  final double? width;
  final bool disableAnimations;

  @override
  State<_Harness> createState() => _HarnessState();
}

final List<CpuDifficulty> _changes = <CpuDifficulty>[];
CpuDifficulty _testValue = CpuDifficulty.normal;

class _HarnessState extends State<_Harness> {
  CpuDifficulty value = CpuDifficulty.normal;
  final FocusNode focusNode = FocusNode(debugLabel: 'cpu-difficulty-test');

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _changes.clear();
    _testValue = CpuDifficulty.normal;
  }

  void _change(CpuDifficulty next) {
    _changes.add(next);
    _testValue = next;
    setState(() => value = next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: widget.disableAnimations),
            child: SizedBox(
              width: widget.width,
              child: CpuDifficultySlider(
                value: value,
                onChanged: _change,
                title: 'CPU難易度',
                labels: const <CpuDifficulty, String>{
                  CpuDifficulty.veryEasy: 'Very Easy',
                  CpuDifficulty.easy: 'Easy',
                  CpuDifficulty.normal: 'Normal',
                  CpuDifficulty.hard: 'Hard',
                },
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
