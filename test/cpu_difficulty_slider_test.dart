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

  testWidgets('maps taps around visual tick midpoints to the nearest tick', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(width: 320));
    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));
    final sliderRect = tester.getRect(slider);
    const tickInset = 40.0;
    final tickRange = sliderRect.width - tickInset * 2;
    final tickStep = tickRange / (CpuDifficulty.values.length - 1);
    final tickCenters = <double>[
      for (var index = 0; index < CpuDifficulty.values.length; index++)
        sliderRect.left + tickInset + index * tickStep,
    ];
    final cases = <({double x, CpuDifficulty expected})>[
      (x: sliderRect.left + 1, expected: CpuDifficulty.veryEasy),
      (
        x: (tickCenters[0] + tickCenters[1]) / 2 - 1,
        expected: CpuDifficulty.veryEasy,
      ),
      (
        x: (tickCenters[0] + tickCenters[1]) / 2 + 1,
        expected: CpuDifficulty.easy,
      ),
      (
        x: (tickCenters[1] + tickCenters[2]) / 2 - 1,
        expected: CpuDifficulty.easy,
      ),
      (
        x: (tickCenters[1] + tickCenters[2]) / 2 + 1,
        expected: CpuDifficulty.normal,
      ),
      (
        x: (tickCenters[2] + tickCenters[3]) / 2 - 1,
        expected: CpuDifficulty.normal,
      ),
      (
        x: (tickCenters[2] + tickCenters[3]) / 2 + 1,
        expected: CpuDifficulty.hard,
      ),
      (x: sliderRect.right - 1, expected: CpuDifficulty.hard),
    ];

    for (final testCase in cases) {
      await tester.tapAt(Offset(testCase.x, sliderRect.center.dy));
      await tester.pump();
      expect(_testValue, testCase.expected, reason: 'tap at ${testCase.x}');
    }
  });

  testWidgets('maps drags around visual tick midpoints to the nearest tick', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(width: 320));
    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));
    final sliderRect = tester.getRect(slider);
    const tickInset = 40.0;
    final tickRange = sliderRect.width - tickInset * 2;
    final tickStep = tickRange / (CpuDifficulty.values.length - 1);
    final tickCenters = <double>[
      for (var index = 0; index < CpuDifficulty.values.length; index++)
        sliderRect.left + tickInset + index * tickStep,
    ];
    final cases = <({double x, CpuDifficulty expected})>[
      (x: sliderRect.left + 1, expected: CpuDifficulty.veryEasy),
      (
        x: (tickCenters[0] + tickCenters[1]) / 2 - 1,
        expected: CpuDifficulty.veryEasy,
      ),
      (
        x: (tickCenters[0] + tickCenters[1]) / 2 + 1,
        expected: CpuDifficulty.easy,
      ),
      (
        x: (tickCenters[1] + tickCenters[2]) / 2 - 1,
        expected: CpuDifficulty.easy,
      ),
      (
        x: (tickCenters[1] + tickCenters[2]) / 2 + 1,
        expected: CpuDifficulty.normal,
      ),
      (
        x: (tickCenters[2] + tickCenters[3]) / 2 - 1,
        expected: CpuDifficulty.normal,
      ),
      (
        x: (tickCenters[2] + tickCenters[3]) / 2 + 1,
        expected: CpuDifficulty.hard,
      ),
      (x: sliderRect.right - 1, expected: CpuDifficulty.hard),
    ];

    for (final testCase in cases) {
      final gesture = await tester.startGesture(
        Offset(testCase.x, sliderRect.center.dy),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(_testValue, testCase.expected, reason: 'drag at ${testCase.x}');
    }
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

  testWidgets('does not paint a value indicator during interaction or focus', (
    tester,
  ) async {
    final valueIndicator = _RecordingValueIndicatorShape();
    await tester.pumpWidget(
      _Harness(width: 320, valueIndicatorShape: valueIndicator),
    );

    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));
    final sliderControl = find.byKey(
      const ValueKey('cpu-difficulty-slider-control'),
    );
    expect(tester.widget<Slider>(sliderControl).label, isNull);
    expect(
      tester
          .widget<SliderTheme>(
            find
                .ancestor(of: sliderControl, matching: find.byType(SliderTheme))
                .first,
          )
          .data
          .showValueIndicator,
      ShowValueIndicator.never,
    );

    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    harness.focusNode.requestFocus();
    await tester.pump();
    expect(
      tester
          .widget<SliderTheme>(
            find
                .ancestor(of: sliderControl, matching: find.byType(SliderTheme))
                .first,
          )
          .data
          .overlayColor,
      isNot(Colors.transparent),
    );
    await tester.tapAt(tester.getRect(slider).center);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getRect(slider).center);
    await tester.pump();
    await gesture.moveBy(const Offset(12, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(valueIndicator.paintCount, 0);
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
      find.byKey(const ValueKey('cpu-difficulty-reduced-motion')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a reduced-motion drag active across multiple steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(width: 320, disableAnimations: true),
    );

    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));
    final sliderRect = tester.getRect(slider);
    final gesture = await tester.startGesture(
      Offset(sliderRect.left + 200, sliderRect.center.dy),
    );
    await tester.pump();
    for (final delta in <double>[-50, -40, -40]) {
      await gesture.moveBy(Offset(delta, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(_testValue, CpuDifficulty.veryEasy);
  });

  testWidgets('supports 2x text in a wide parent inside vertical scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        width: 560,
        textScaler: TextScaler.linear(2),
        verticalScroll: true,
        scrollHeight: 96,
      ),
    );

    final slider = find.byKey(const ValueKey('cpu-difficulty-slider'));
    final sliderRect = tester.getRect(slider);
    expect(sliderRect.width, 560);
    for (final difficulty in CpuDifficulty.values) {
      final labelRect = tester.getRect(
        find.byKey(ValueKey('cpu-difficulty-${difficulty.name}')),
      );
      expect(labelRect.left, greaterThanOrEqualTo(sliderRect.left));
      expect(labelRect.right, lessThanOrEqualTo(sliderRect.right));
    }

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -32));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({
    this.width,
    this.disableAnimations = false,
    this.valueIndicatorShape,
    this.textScaler,
    this.verticalScroll = false,
    this.scrollHeight = 160,
  });

  final double? width;
  final bool disableAnimations;
  final SliderComponentShape? valueIndicatorShape;
  final TextScaler? textScaler;
  final bool verticalScroll;
  final double scrollHeight;

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
    Widget slider = CpuDifficultySlider(
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
    );
    if (widget.valueIndicatorShape != null) {
      slider = SliderTheme(
        data: SliderTheme.of(
          context,
        ).copyWith(valueIndicatorShape: widget.valueIndicatorShape),
        child: slider,
      );
    }
    Widget content = SizedBox(width: widget.width, child: slider);
    if (widget.verticalScroll) {
      content = SizedBox(
        height: widget.scrollHeight,
        child: SingleChildScrollView(child: content),
      );
    }
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: widget.disableAnimations,
              textScaler: widget.textScaler,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _RecordingValueIndicatorShape extends SliderComponentShape {
  var paintCount = 0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.zero;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    paintCount++;
  }
}
