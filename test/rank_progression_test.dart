import 'dart:async';
import 'dart:math';

import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/main.dart';
import 'package:conquest/rank_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _expectedBf4Tiers = <RankTier>[
  RankTier(0, '新兵', 0),
  RankTier(1, "一等兵", 3000),
  RankTier(2, "一等兵Ⅱ", 8000),
  RankTier(3, "一等兵Ⅲ", 11000),
  RankTier(4, "一等兵Ⅳ", 13000),
  RankTier(5, "一等兵Ⅴ", 17000),
  RankTier(6, "上等兵", 18000),
  RankTier(7, "上等兵Ⅱ", 21000),
  RankTier(8, "上等兵Ⅲ", 24000),
  RankTier(9, "上等兵Ⅳ", 25000),
  RankTier(10, "上等兵Ⅴ", 28000),
  RankTier(11, "伍長", 29000),
  RankTier(12, "伍長Ⅱ", 32000),
  RankTier(13, "伍長Ⅲ", 33000),
  RankTier(14, "伍長Ⅳ", 35000),
  RankTier(15, "伍長Ⅴ", 37000),
  RankTier(16, "軍曹", 39000),
  RankTier(17, "軍曹Ⅱ", 40000),
  RankTier(18, "軍曹Ⅲ", 42000),
  RankTier(19, "軍曹Ⅳ", 44000),
  RankTier(20, "軍曹Ⅴ", 46000),
  RankTier(21, "二等軍曹", 47000),
  RankTier(22, "二等軍曹Ⅱ", 48000),
  RankTier(23, "二等軍曹Ⅲ", 51000),
  RankTier(24, "二等軍曹Ⅳ", 51000),
  RankTier(25, "二等軍曹Ⅴ", 54000),
  RankTier(26, "一等軍曹", 55000),
  RankTier(27, "一等軍曹Ⅱ", 56000),
  RankTier(28, "一等軍曹Ⅲ", 58000),
  RankTier(29, "一等軍曹Ⅳ", 58000),
  RankTier(30, "一等軍曹Ⅴ", 58000),
  RankTier(31, "曹長", 69000),
  RankTier(32, "曹長Ⅱ", 65000),
  RankTier(33, "曹長Ⅲ", 65000),
  RankTier(34, "曹長Ⅳ", 65000),
  RankTier(35, "曹長Ⅴ", 65000),
  RankTier(36, "専任曹長", 70000),
  RankTier(37, "専任曹長Ⅱ", 70000),
  RankTier(38, "専任曹長Ⅲ", 70000),
  RankTier(39, "専任曹長Ⅳ", 70000),
  RankTier(40, "専任曹長Ⅴ", 80000),
  RankTier(41, "上級曹長", 80000),
  RankTier(42, "上級曹長Ⅱ", 75000),
  RankTier(43, "上級曹長Ⅲ", 75000),
  RankTier(44, "上級曹長Ⅳ", 80000),
  RankTier(45, "上級曹長Ⅴ", 80000),
  RankTier(46, "最先任上級曹長", 80000),
  RankTier(47, "最先任上級曹長Ⅱ", 90000),
  RankTier(48, "最先任上級曹長Ⅲ", 80000),
  RankTier(49, "最先任上級曹長Ⅳ", 90000),
  RankTier(50, "最先任上級曹長Ⅴ", 90000),
  RankTier(51, "准尉", 90000),
  RankTier(52, "准尉Ⅱ", 100000),
  RankTier(53, "准尉Ⅲ", 100000),
  RankTier(54, "准尉Ⅳ", 90000),
  RankTier(55, "准尉Ⅴ", 90000),
  RankTier(56, "准尉2級", 90000),
  RankTier(57, "准尉2級Ⅱ", 90000),
  RankTier(58, "准尉2級Ⅲ", 100000),
  RankTier(59, "准尉2級Ⅳ", 100000),
  RankTier(60, "准尉2級Ⅴ", 90000),
  RankTier(61, "准尉3級", 110000),
  RankTier(62, "准尉3級Ⅱ", 100000),
  RankTier(63, "准尉3級Ⅲ", 100000),
  RankTier(64, "准尉3級Ⅳ", 110000),
  RankTier(65, "准尉3級Ⅴ", 110000),
  RankTier(66, "准尉4級", 90000),
  RankTier(67, "准尉4級Ⅱ", 110000),
  RankTier(68, "准尉4級Ⅲ", 110000),
  RankTier(69, "准尉4級Ⅳ", 120000),
  RankTier(70, "准尉4級Ⅴ", 120000),
  RankTier(71, "准尉5級", 110000),
  RankTier(72, "准尉5級Ⅱ", 110000),
  RankTier(73, "准尉5級Ⅲ", 110000),
  RankTier(74, "准尉5級Ⅳ", 110000),
  RankTier(75, "准尉5級Ⅴ", 120000),
  RankTier(76, "少尉", 120000),
  RankTier(77, "少尉Ⅱ", 120000),
  RankTier(78, "少尉Ⅲ", 120000),
  RankTier(79, "少尉Ⅳ", 120000),
  RankTier(80, "少尉Ⅴ", 120000),
  RankTier(81, "中尉", 130000),
  RankTier(82, "中尉Ⅱ", 120000),
  RankTier(83, "中尉Ⅲ", 120000),
  RankTier(84, "中尉Ⅳ", 130000),
  RankTier(85, "中尉Ⅴ", 130000),
  RankTier(86, "大尉", 130000),
  RankTier(87, "大尉Ⅱ", 130000),
  RankTier(88, "大尉Ⅲ", 120000),
  RankTier(89, "大尉Ⅳ", 130000),
  RankTier(90, "大尉Ⅴ", 130000),
  RankTier(91, "少佐", 140000),
  RankTier(92, "少佐Ⅱ", 130000),
  RankTier(93, "少佐Ⅲ", 140000),
  RankTier(94, "少佐Ⅳ", 130000),
  RankTier(95, "少佐Ⅴ", 140000),
  RankTier(96, "中佐Ⅰ", 150000),
  RankTier(97, "中佐Ⅱ", 140000),
  RankTier(98, "中佐Ⅲ", 140000),
  RankTier(99, "中佐Ⅳ", 130000),
  RankTier(100, "大佐", 140000),
  RankTier(101, "大佐Ⅱ", 200000),
  RankTier(102, "大佐Ⅲ", 200000),
  RankTier(103, "大佐Ⅳ", 200000),
  RankTier(104, "大佐Ⅴ", 200000),
  RankTier(105, "大佐Ⅵ", 200000),
  RankTier(106, "大佐Ⅶ", 200000),
  RankTier(107, "大佐Ⅷ", 200000),
  RankTier(108, "大佐Ⅸ", 200000),
  RankTier(109, "大佐Ⅹ", 200000),
  RankTier(110, "准将", 200000),
  RankTier(111, "准将Ⅱ", 300000),
  RankTier(112, "准将Ⅲ", 470000),
  RankTier(113, "准将Ⅳ", 480000),
  RankTier(114, "准将Ⅴ", 500000),
  RankTier(115, "准将Ⅵ", 510000),
  RankTier(116, "准将Ⅶ", 530000),
  RankTier(117, "准将Ⅷ", 550000),
  RankTier(118, "准将Ⅸ", 560000),
  RankTier(119, "准将Ⅹ", 590000),
  RankTier(120, "少将", 600000),
  RankTier(121, "少将Ⅱ", 620000),
  RankTier(122, "少将Ⅲ", 640000),
  RankTier(123, "少将Ⅳ", 660000),
  RankTier(124, "少将Ⅴ", 680000),
  RankTier(125, "少将Ⅵ", 700000),
  RankTier(126, "少将Ⅶ", 730000),
  RankTier(127, "少将Ⅷ", 740000),
  RankTier(128, "少将Ⅸ", 770000),
  RankTier(129, "少将Ⅹ", 790000),
  RankTier(130, "中将", 810000),
  RankTier(131, "中将Ⅱ", 840000),
  RankTier(132, "中将Ⅲ", 860000),
  RankTier(133, "中将Ⅳ", 890000),
  RankTier(134, "中将Ⅴ", 910000),
  RankTier(135, "中将Ⅵ", 940000),
  RankTier(136, "中将Ⅶ", 960000),
  RankTier(137, "中将Ⅷ", 990000),
  RankTier(138, "中将Ⅸ", 1020000),
  RankTier(139, "中将Ⅹ", 1050000),
  RankTier(140, "大将", 1070000),
];

class _FakeRankStore implements RankProgressStore {
  _FakeRankStore({
    this.value,
    this.loadError,
    this.saveError,
    this.loadCompleter,
  });

  int? value;
  Object? loadError;
  Object? saveError;
  Completer<int?>? loadCompleter;
  int loadCount = 0;
  int saveCount = 0;

  @override
  Future<int?> loadTotalXp() async {
    loadCount++;
    if (loadError != null) throw loadError!;
    if (loadCompleter != null) return loadCompleter!.future;
    return value;
  }

  @override
  Future<void> saveTotalXp(int totalXp) async {
    saveCount++;
    if (saveError != null) throw saveError!;
    value = totalXp;
  }
}

final class _ManualRankGameLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;

  void tick() => _onTick?.call();

  void tickMany(int count) {
    for (var index = 0; index < count; index++) {
      _onTick?.call();
    }
  }
}

void main() {
  group('BF4 rank table', () {
    test('contains every rank and the source total', () {
      expect(RankCatalog.tiers, hasLength(141));
      expect(RankCatalog.tiers, orderedEquals(_expectedBf4Tiers));
      expect(RankCatalog.tiers.first, const RankTier(0, '新兵', 0));
      expect(RankCatalog.tiers[1], const RankTier(1, '一等兵', 3000));
      expect(RankCatalog.tiers[31], const RankTier(31, '曹長', 69000));
      expect(RankCatalog.tiers[140], const RankTier(140, '大将', 1070000));
      expect(RankCatalog.stageXpTotal, 32180000);
      expect([
        for (var rank = 0; rank < RankCatalog.tiers.length; rank++)
          RankCatalog.tiers[rank].rank,
      ], orderedEquals(List<int>.generate(141, (rank) => rank)));
    });

    test('maps every cumulative threshold to the matching rank', () {
      for (var rank = 1; rank < RankCatalog.tiers.length; rank++) {
        final threshold = RankCatalog.cumulativeXp[rank];
        expect(RankProgress.fromTotalXp(threshold).rank, rank);
        expect(RankProgress.fromTotalXp(threshold - 1).rank, rank - 1);
      }
    });

    test('carries overflow and caps the displayed rank at MAX', () {
      final rankOne = RankProgress.fromTotalXp(3500);
      expect(rankOne.rank, 1);
      expect(rankOne.title, '一等兵');
      expect(rankOne.currentRankXp, 500);
      expect(rankOne.nextRankXp, 8000);
      expect(rankOne.xpToNextRank, 7500);

      final max = RankProgress.fromTotalXp(RankCatalog.stageXpTotal + 1234);
      expect(max.rank, 140);
      expect(max.title, '大将');
      expect(max.totalXp, RankCatalog.stageXpTotal + 1234);
      expect(max.isMax, isTrue);
      expect(max.nextRankXp, isNull);
      expect(max.progressRatio, 1);
    });
  });

  group('RankProgressManager', () {
    test('awards each difficulty exactly once per match', () async {
      final store = _FakeRankStore();
      final manager = RankProgressManager(store: store);

      expect(await manager.load(), RankProgress.zero);
      for (final entry in <CpuDifficulty, int>{
        CpuDifficulty.veryEasy: 500,
        CpuDifficulty.easy: 1000,
        CpuDifficulty.normal: 1500,
        CpuDifficulty.hard: 3000,
      }.entries) {
        final award = await manager.recordVictory(
          matchId: entry.key.name,
          difficulty: entry.key,
        );
        expect(award.xpAwarded, entry.value);
      }
      final duplicate = await manager.recordVictory(
        matchId: CpuDifficulty.hard.name,
        difficulty: CpuDifficulty.hard,
      );
      expect(duplicate.xpAwarded, 0);
      expect(manager.current.totalXp, 6000);
      expect(store.saveCount, 4);
    });

    test('waits for load before applying a victory', () async {
      final store = _FakeRankStore(value: 2500);
      final manager = RankProgressManager(store: store);

      final award = await manager.recordVictory(
        matchId: 'race',
        difficulty: CpuDifficulty.veryEasy,
      );

      expect(award.before.totalXp, 2500);
      expect(award.after.totalXp, 3000);
      expect(award.after.rank, 1);
      expect(store.loadCount, 1);
    });

    test('serializes a victory behind an in-flight load', () async {
      final loadCompleter = Completer<int?>();
      final store = _FakeRankStore(loadCompleter: loadCompleter);
      final manager = RankProgressManager(store: store);

      final pending = manager.recordVictory(
        matchId: 'load-race',
        difficulty: CpuDifficulty.normal,
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.loadCount, 1);
      expect(store.saveCount, 0);
      loadCompleter.complete(2500);

      final award = await pending;
      expect(award.before.totalXp, 2500);
      expect(award.after.totalXp, 4000);
      expect(store.value, 4000);
      expect(store.saveCount, 1);
    });

    test('keeps the in-memory result when storage fails', () async {
      final manager = RankProgressManager(
        store: _FakeRankStore(saveError: StateError('unavailable')),
      );

      final award = await manager.recordVictory(
        matchId: 'storage-error',
        difficulty: CpuDifficulty.easy,
      );

      expect(award.after.totalXp, 1000);
      expect(manager.current.totalXp, 1000);
      expect(manager.storageError, isA<StateError>());
    });

    test('starts from zero when loading storage fails', () async {
      final manager = RankProgressManager(
        store: _FakeRankStore(loadError: StateError('unavailable')),
      );

      final award = await manager.recordVictory(
        matchId: 'load-error',
        difficulty: CpuDifficulty.veryEasy,
      );

      expect(award.before, RankProgress.zero);
      expect(award.after.totalXp, 500);
      expect(manager.storageError, isA<StateError>());
    });
  });

  test(
    'controller awards one player victory and ignores duplicate finish',
    () async {
      final store = _FakeRankStore();
      final loop = _ManualRankGameLoop();
      final container = ProviderContainer(
        overrides: [
          rankProgressStoreProvider.overrideWithValue(store),
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
        ],
      );
      addTearDown(container.dispose);
      final gameStateSubscription = container.listen(
        gameControllerProvider,
        (_, __) {},
      );
      addTearDown(gameStateSubscription.close);

      final controller = container.read(gameControllerProvider.notifier);
      controller.selectCpuDifficulty(CpuDifficulty.hard);
      controller.startGame();
      loop.tickMany(60);
      expect(container.read(gameControllerProvider).phase, GamePhase.playing);
      controller.finish(const GameResult.victory(elapsedMs: 100));
      await Future<void>.delayed(Duration.zero);
      controller.finish(const GameResult.victory(elapsedMs: 100));
      await Future<void>.delayed(Duration.zero);

      final result = container.read(gameControllerProvider).result!;
      expect(result.xpAwarded, 3000);
      expect(result.rankBefore, 0);
      expect(result.rankAfter, 1);
      expect(store.value, 3000);
      expect(store.saveCount, 1);
    },
  );

  test('controller excludes spectator and non-win results', () async {
    final store = _FakeRankStore();
    final loop = _ManualRankGameLoop();
    final container = ProviderContainer(
      overrides: [
        rankProgressStoreProvider.overrideWithValue(store),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
      ],
    );
    addTearDown(container.dispose);
    final gameStateSubscription = container.listen(
      gameControllerProvider,
      (_, __) {},
    );
    addTearDown(gameStateSubscription.close);

    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    loop.tickMany(60);
    controller.finish(const GameResult.defeat(elapsedMs: 100));
    await Future<void>.delayed(Duration.zero);
    expect(store.loadCount, 0);
    expect(store.saveCount, 0);

    controller.returnToConfiguration();
    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.startGame();
    loop.tickMany(60);
    controller.finish(
      const GameResult.victory(elapsedMs: 100, winner: Faction.player),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.loadCount, 0);
    expect(store.saveCount, 0);
  });

  test('controller awards a victory resolved by the game loop', () async {
    final store = _FakeRankStore();
    final loop = _ManualRankGameLoop();
    final container = ProviderContainer(
      overrides: [
        rankProgressStoreProvider.overrideWithValue(store),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
      ],
    );
    addTearDown(container.dispose);
    final gameStateSubscription = container.listen(
      gameControllerProvider,
      (_, __) {},
    );
    addTearDown(gameStateSubscription.close);

    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    loop.tickMany(60);
    final configuration = container.read(gameControllerProvider).configuration;
    controller.state = GameState(
      configuration: configuration,
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: const [
        IslandState(
          id: 0,
          faction: Faction.player,
          currentForces: 10,
          capacity: 50,
        ),
        IslandState(
          id: 1,
          faction: Faction.cpu,
          currentForces: 1,
          capacity: 50,
        ),
      ],
      movingForces: const [
        MovingForce(
          faction: Faction.player,
          sourceIslandId: 0,
          destinationIslandId: 1,
          strength: 2,
          arrivalTimeMs: 0,
          durationMs: 1,
        ),
      ],
    );

    loop.tick();
    await Future<void>.delayed(Duration.zero);
    final result = container.read(gameControllerProvider).result!;
    expect(result.type, GameResultType.victory);
    expect(result.xpAwarded, 1500);
    expect(store.value, 1500);
    expect(store.saveCount, 1);
  });

  testWidgets('exposes rank progress in settings and result screens', (
    tester,
  ) async {
    final store = _FakeRankStore(value: 2500);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rankProgressStoreProvider.overrideWithValue(store)],
        child: const MyApp(locale: Locale('ja')),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('ランク 0・新兵'), findsOneWidget);
    expect(find.text('次の昇級まで 500 XP'), findsOneWidget);
  });

  testWidgets('shows animated XP and rank-up emphasis in the result sheet', (
    tester,
  ) async {
    final store = _FakeRankStore();
    final loop = _ManualRankGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankProgressStoreProvider.overrideWithValue(store),
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-button-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    controller.startGame();
    loop.tickMany(60);
    controller.finish(const GameResult.victory(elapsedMs: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const ValueKey('result-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('rank-award-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-rank-progress')), findsOneWidget);
    expect(find.text('+3000 XP'), findsOneWidget);
    expect(find.text('昇級！ ランク 1・一等兵'), findsOneWidget);
  });
}
