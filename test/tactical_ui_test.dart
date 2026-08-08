import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ManualGameLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;

  void tickMany(int count) {
    for (var index = 0; index < count; index++) {
      _onTick?.call();
    }
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _ManualGameLoop loop,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ],
      child: const MyApp(),
    ),
  );
}

void main() {
  testWidgets('matches the tactical chart configuration screen', (
    tester,
  ) async {
    await _pumpApp(tester, loop: _ManualGameLoop());

    expect(find.byKey(const ValueKey('tactical-map-background')), findsOne);
    expect(find.byKey(const ValueKey('settings-view')), findsOne);
    expect(find.text('対戦設定 / 01'), findsOne);
    expect(find.text('対戦設定'), findsOne);
    expect(find.text('海域の規模とCPUの判断速度を選択してください。'), findsOne);
    expect(find.text('島数'), findsOne);
    expect(find.text('CPU難易度'), findsOne);
    expect(find.text('06'), findsOne);
    expect(find.text('08'), findsOne);
    expect(find.text('10'), findsAtLeastNWidgets(1));
    expect(find.text('12'), findsOne);
    expect(find.text('ゲーム開始'), findsOne);
    expect(find.text('選択中：10島 / Normal'), findsOne);

    expect(tester.takeException(), isNull);
  });

  testWidgets('matches countdown and play HUD states', (tester) async {
    final loop = _ManualGameLoop();
    await _pumpApp(tester, loop: loop);

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    expect(find.byKey(const ValueKey('countdown-ring')), findsOne);
    expect(find.text('3'), findsOne);
    expect(find.text('出撃準備'), findsOne);

    loop.tickMany(60);
    await tester.pump();
    expect(find.text('CONQUEST'), findsOne);
    expect(find.text('戦術海図 / 10島'), findsOne);
    expect(find.byKey(const ValueKey('pause-game')), findsOne);

    final cpuHeadquarters = tester.getRect(
      find.byKey(const ValueKey('island-button-1')),
    );
    final playerHeadquarters = tester.getRect(
      find.byKey(const ValueKey('island-button-0')),
    );
    expect(
      cpuHeadquarters.overlaps(
        tester.getRect(find.byKey(const ValueKey('board-title-block'))),
      ),
      isFalse,
    );
    expect(
      playerHeadquarters.overlaps(
        tester.getRect(find.byKey(const ValueKey('board-status-label'))),
      ),
      isFalse,
    );
    expect(
      playerHeadquarters.overlaps(
        tester.getRect(find.byKey(const ValueKey('board-status-detail'))),
      ),
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('island-button-0')));
    await tester.pump();
    expect(find.text('出兵元'), findsOne);
    expect(find.text('出兵元を選択中'), findsOne);
    expect(find.text('タップで目標を指定\n兵力の半分を派遣'), findsOne);
  });

  testWidgets('matches the tactical pause sheet', (tester) async {
    final loop = _ManualGameLoop();
    await _pumpApp(tester, loop: loop);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    loop.tickMany(60);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('pause-game')));
    await tester.pump();

    expect(find.byKey(const ValueKey('pause-sheet')), findsOne);
    expect(find.text('対戦を一時停止'), findsOne);
    expect(find.text('一時停止'), findsOne);
    expect(find.text('現在の盤面を確認できます。'), findsOne);
    expect(find.text('再開'), findsOne);
    expect(find.text('設定へ戻る'), findsOne);
  });

  testWidgets('renders each result with its own Japanese outcome', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    await _pumpApp(tester, loop: loop);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);

    for (final result in <(GameResult, String)>[
      (const GameResult.victory(elapsedMs: 1000), '勝利'),
      (const GameResult.defeat(elapsedMs: 1000), '敗北'),
      (const GameResult.draw(elapsedMs: 1000), '引き分け'),
    ]) {
      controller.state = controller.state.finishWithResult(result.$1);
      await tester.pump();

      expect(find.byKey(const ValueKey('result-sheet')), findsOne);
      expect(find.text('戦闘終了'), findsOne);
      expect(find.text(result.$2), findsOne);
      expect(find.text('再戦'), findsOne);
      expect(find.text('設定へ戻る'), findsOne);
    }
  });
}
