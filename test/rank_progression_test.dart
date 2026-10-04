import 'dart:math';

import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/main.dart';
import 'package:conquest/home.dart';
import 'package:conquest/l10n/generated/app_localizations_en.dart';
import 'package:conquest/l10n/generated/app_localizations_ja.dart';
import 'package:conquest/rank_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';
import 'support/profile_fixture.dart';
import 'support/profile_widget_io.dart';
import 'support/rank_badge_fixture.dart' show SilentBgmPlayer;
import 'package:conquest/profile/match_persistence.dart';

const _expectedRequiredXp = <int>[
  0,
  3000,
  8000,
  11000,
  13000,
  17000,
  18000,
  21000,
  24000,
  25000,
  28000,
  29000,
  32000,
  33000,
  35000,
  37000,
  39000,
  40000,
  42000,
  44000,
  46000,
  47000,
  48000,
  51000,
  51000,
  54000,
  55000,
  56000,
  58000,
  58000,
  58000,
  69000,
  65000,
  65000,
  65000,
  65000,
  70000,
  70000,
  70000,
  70000,
  80000,
  80000,
  75000,
  75000,
  80000,
  80000,
  80000,
  90000,
  80000,
  90000,
  90000,
  90000,
  100000,
  100000,
  90000,
  90000,
  90000,
  90000,
  100000,
  100000,
  90000,
  110000,
  100000,
  100000,
  110000,
  110000,
  90000,
  110000,
  110000,
  120000,
  120000,
  110000,
  110000,
  110000,
  110000,
  120000,
  120000,
  120000,
  120000,
  120000,
  120000,
  130000,
  120000,
  120000,
  130000,
  130000,
  130000,
  130000,
  120000,
  130000,
  130000,
  140000,
  130000,
  140000,
  130000,
  140000,
  150000,
  140000,
  140000,
  130000,
  140000,
  200000,
  200000,
  200000,
  200000,
  200000,
  200000,
  200000,
  200000,
  200000,
  200000,
  300000,
  470000,
  480000,
  500000,
  510000,
  530000,
  550000,
  560000,
  590000,
  600000,
  620000,
  640000,
  660000,
  680000,
  700000,
  730000,
  740000,
  770000,
  790000,
  810000,
  840000,
  860000,
  890000,
  910000,
  940000,
  960000,
  990000,
  1020000,
  1050000,
  1070000,
];

final _expectedTitleKeys = <RankTitleKey>[
  RankTitleKey.recruit,
  ...List.filled(5, RankTitleKey.privateFirstClass),
  ...List.filled(5, RankTitleKey.lanceCorporal),
  ...List.filled(5, RankTitleKey.corporal),
  ...List.filled(5, RankTitleKey.sergeant),
  ...List.filled(5, RankTitleKey.staffSergeant),
  ...List.filled(5, RankTitleKey.gunnerySergeant),
  ...List.filled(5, RankTitleKey.masterSergeant),
  ...List.filled(5, RankTitleKey.firstSergeant),
  ...List.filled(5, RankTitleKey.masterGunnerySergeant),
  ...List.filled(5, RankTitleKey.sergeantMajor),
  ...List.filled(5, RankTitleKey.warrantOfficerOne),
  ...List.filled(5, RankTitleKey.chiefWarrantOfficerTwo),
  ...List.filled(5, RankTitleKey.chiefWarrantOfficerThree),
  ...List.filled(5, RankTitleKey.chiefWarrantOfficerFour),
  ...List.filled(5, RankTitleKey.chiefWarrantOfficerFive),
  ...List.filled(5, RankTitleKey.secondLieutenant),
  ...List.filled(5, RankTitleKey.firstLieutenant),
  ...List.filled(5, RankTitleKey.captain),
  ...List.filled(5, RankTitleKey.major),
  ...List.filled(4, RankTitleKey.lieutenantColonel),
  ...List.filled(10, RankTitleKey.colonel),
  ...List.filled(10, RankTitleKey.brigadierGeneral),
  ...List.filled(10, RankTitleKey.majorGeneral),
  ...List.filled(10, RankTitleKey.lieutenantGeneral),
  ...List.filled(1, RankTitleKey.general),
];

const _expectedEnglishTitles = <String>[
  "Recruit",
  "Private First Class",
  "Private First Class II",
  "Private First Class III",
  "Private First Class IV",
  "Private First Class V",
  "Lance Corporal",
  "Lance Corporal II",
  "Lance Corporal III",
  "Lance Corporal IV",
  "Lance Corporal V",
  "Corporal",
  "Corporal II",
  "Corporal III",
  "Corporal IV",
  "Corporal V",
  "Sergeant",
  "Sergeant II",
  "Sergeant III",
  "Sergeant IV",
  "Sergeant V",
  "Staff Sergeant",
  "Staff Sergeant II",
  "Staff Sergeant III",
  "Staff Sergeant IV",
  "Staff Sergeant V",
  "Gunnery Sergeant",
  "Gunnery Sergeant II",
  "Gunnery Sergeant III",
  "Gunnery Sergeant IV",
  "Gunnery Sergeant V",
  "Master Sergeant",
  "Master Sergeant II",
  "Master Sergeant III",
  "Master Sergeant IV",
  "Master Sergeant V",
  "First Sergeant",
  "First Sergeant II",
  "First Sergeant III",
  "First Sergeant IV",
  "First Sergeant V",
  "Master Gunnery Sergeant",
  "Master Gunnery Sergeant II",
  "Master Gunnery Sergeant III",
  "Master Gunnery Sergeant IV",
  "Master Gunnery Sergeant V",
  "Sergeant Major",
  "Sergeant Major II",
  "Sergeant Major III",
  "Sergeant Major IV",
  "Sergeant Major V",
  "Warrant Officer One",
  "Warrant Officer One II",
  "Warrant Officer One III",
  "Warrant Officer One IV",
  "Warrant Officer One V",
  "Chief Warrant Officer Two",
  "Chief Warrant Officer Two II",
  "Chief Warrant Officer Two III",
  "Chief Warrant Officer Two IV",
  "Chief Warrant Officer Two V",
  "Chief Warrant Officer Three",
  "Chief Warrant Officer Three II",
  "Chief Warrant Officer Three III",
  "Chief Warrant Officer Three IV",
  "Chief Warrant Officer Three V",
  "Chief Warrant Officer Four",
  "Chief Warrant Officer Four II",
  "Chief Warrant Officer Four III",
  "Chief Warrant Officer Four IV",
  "Chief Warrant Officer Four V",
  "Chief Warrant Officer Five",
  "Chief Warrant Officer Five II",
  "Chief Warrant Officer Five III",
  "Chief Warrant Officer Five IV",
  "Chief Warrant Officer Five V",
  "Second Lieutenant",
  "Second Lieutenant II",
  "Second Lieutenant III",
  "Second Lieutenant IV",
  "Second Lieutenant V",
  "First Lieutenant",
  "First Lieutenant II",
  "First Lieutenant III",
  "First Lieutenant IV",
  "First Lieutenant V",
  "Captain",
  "Captain II",
  "Captain III",
  "Captain IV",
  "Captain V",
  "Major",
  "Major II",
  "Major III",
  "Major IV",
  "Major V",
  "Lieutenant Colonel",
  "Lieutenant Colonel II",
  "Lieutenant Colonel III",
  "Lieutenant Colonel IV",
  "Colonel",
  "Colonel II",
  "Colonel III",
  "Colonel IV",
  "Colonel V",
  "Colonel VI",
  "Colonel VII",
  "Colonel VIII",
  "Colonel IX",
  "Colonel X",
  "Brigadier General",
  "Brigadier General II",
  "Brigadier General III",
  "Brigadier General IV",
  "Brigadier General V",
  "Brigadier General VI",
  "Brigadier General VII",
  "Brigadier General VIII",
  "Brigadier General IX",
  "Brigadier General X",
  "Major General",
  "Major General II",
  "Major General III",
  "Major General IV",
  "Major General V",
  "Major General VI",
  "Major General VII",
  "Major General VIII",
  "Major General IX",
  "Major General X",
  "Lieutenant General",
  "Lieutenant General II",
  "Lieutenant General III",
  "Lieutenant General IV",
  "Lieutenant General V",
  "Lieutenant General VI",
  "Lieutenant General VII",
  "Lieutenant General VIII",
  "Lieutenant General IX",
  "Lieutenant General X",
  "General",
];

const _expectedJapaneseTitles = <String>[
  "新兵",
  "一等兵",
  "一等兵Ⅱ",
  "一等兵Ⅲ",
  "一等兵Ⅳ",
  "一等兵Ⅴ",
  "上等兵",
  "上等兵Ⅱ",
  "上等兵Ⅲ",
  "上等兵Ⅳ",
  "上等兵Ⅴ",
  "伍長",
  "伍長Ⅱ",
  "伍長Ⅲ",
  "伍長Ⅳ",
  "伍長Ⅴ",
  "軍曹",
  "軍曹Ⅱ",
  "軍曹Ⅲ",
  "軍曹Ⅳ",
  "軍曹Ⅴ",
  "二等軍曹",
  "二等軍曹Ⅱ",
  "二等軍曹Ⅲ",
  "二等軍曹Ⅳ",
  "二等軍曹Ⅴ",
  "一等軍曹",
  "一等軍曹Ⅱ",
  "一等軍曹Ⅲ",
  "一等軍曹Ⅳ",
  "一等軍曹Ⅴ",
  "曹長",
  "曹長Ⅱ",
  "曹長Ⅲ",
  "曹長Ⅳ",
  "曹長Ⅴ",
  "専任曹長",
  "専任曹長Ⅱ",
  "専任曹長Ⅲ",
  "専任曹長Ⅳ",
  "専任曹長Ⅴ",
  "上級曹長",
  "上級曹長Ⅱ",
  "上級曹長Ⅲ",
  "上級曹長Ⅳ",
  "上級曹長Ⅴ",
  "最先任上級曹長",
  "最先任上級曹長Ⅱ",
  "最先任上級曹長Ⅲ",
  "最先任上級曹長Ⅳ",
  "最先任上級曹長Ⅴ",
  "准尉",
  "准尉Ⅱ",
  "准尉Ⅲ",
  "准尉Ⅳ",
  "准尉Ⅴ",
  "准尉2級",
  "准尉2級Ⅱ",
  "准尉2級Ⅲ",
  "准尉2級Ⅳ",
  "准尉2級Ⅴ",
  "准尉3級",
  "准尉3級Ⅱ",
  "准尉3級Ⅲ",
  "准尉3級Ⅳ",
  "准尉3級Ⅴ",
  "准尉4級",
  "准尉4級Ⅱ",
  "准尉4級Ⅲ",
  "准尉4級Ⅳ",
  "准尉4級Ⅴ",
  "准尉5級",
  "准尉5級Ⅱ",
  "准尉5級Ⅲ",
  "准尉5級Ⅳ",
  "准尉5級Ⅴ",
  "少尉",
  "少尉Ⅱ",
  "少尉Ⅲ",
  "少尉Ⅳ",
  "少尉Ⅴ",
  "中尉",
  "中尉Ⅱ",
  "中尉Ⅲ",
  "中尉Ⅳ",
  "中尉Ⅴ",
  "大尉",
  "大尉Ⅱ",
  "大尉Ⅲ",
  "大尉Ⅳ",
  "大尉Ⅴ",
  "少佐",
  "少佐Ⅱ",
  "少佐Ⅲ",
  "少佐Ⅳ",
  "少佐Ⅴ",
  "中佐Ⅰ",
  "中佐Ⅱ",
  "中佐Ⅲ",
  "中佐Ⅳ",
  "大佐",
  "大佐Ⅱ",
  "大佐Ⅲ",
  "大佐Ⅳ",
  "大佐Ⅴ",
  "大佐Ⅵ",
  "大佐Ⅶ",
  "大佐Ⅷ",
  "大佐Ⅸ",
  "大佐Ⅹ",
  "准将",
  "准将Ⅱ",
  "准将Ⅲ",
  "准将Ⅳ",
  "准将Ⅴ",
  "准将Ⅵ",
  "准将Ⅶ",
  "准将Ⅷ",
  "准将Ⅸ",
  "准将Ⅹ",
  "少将",
  "少将Ⅱ",
  "少将Ⅲ",
  "少将Ⅳ",
  "少将Ⅴ",
  "少将Ⅵ",
  "少将Ⅶ",
  "少将Ⅷ",
  "少将Ⅸ",
  "少将Ⅹ",
  "中将",
  "中将Ⅱ",
  "中将Ⅲ",
  "中将Ⅳ",
  "中将Ⅴ",
  "中将Ⅵ",
  "中将Ⅶ",
  "中将Ⅷ",
  "中将Ⅸ",
  "中将Ⅹ",
  "大将",
];

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

Future<void> closeProfile(WidgetTester tester, ProfileFixture store) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await runProfileIo(tester, store.runtime.close);
}

void main() {
  group('BF4 rank table', () {
    test('contains every rank and the source total', () {
      expect(RankCatalog.tiers, hasLength(141));
      expect([
        for (final tier in RankCatalog.tiers) tier.requiredXp,
      ], orderedEquals(_expectedRequiredXp));
      expect([
        for (final tier in RankCatalog.tiers) tier.titleKey,
      ], orderedEquals(_expectedTitleKeys));
      expect(
        RankCatalog.tiers.first,
        const RankTier(0, RankTitleKey.recruit, 0),
      );
      expect(
        RankCatalog.tiers[1],
        const RankTier(1, RankTitleKey.privateFirstClass, 3000),
      );
      expect(
        RankCatalog.tiers[31],
        const RankTier(31, RankTitleKey.masterSergeant, 69000),
      );
      expect(
        RankCatalog.tiers[140],
        const RankTier(140, RankTitleKey.general, 1070000),
      );
      expect(RankCatalog.stageXpTotal, 32180000);
      expect([
        for (var rank = 0; rank < RankCatalog.tiers.length; rank++)
          RankCatalog.tiers[rank].rank,
      ], orderedEquals(List<int>.generate(141, (rank) => rank)));
    });

    test('localizes every rank title without changing the rank data', () {
      final english = AppLocalizationsEn();
      final japanese = AppLocalizationsJa();

      expect([
        for (final tier in RankCatalog.tiers) tier.localizedTitle(english),
      ], orderedEquals(_expectedEnglishTitles));
      expect([
        for (final tier in RankCatalog.tiers) tier.localizedTitle(japanese),
      ], orderedEquals(_expectedJapaneseTitles));
      expect([
        for (final tier in RankCatalog.tiers) tier.requiredXp,
      ], orderedEquals(_expectedRequiredXp));
    });

    test('uses the resolved language for regional and fallback locales', () {
      final tier = RankCatalog.tiers[42];

      expect(
        tier.localizedTitle(AppLocalizationsEn('en_US')),
        'Master Gunnery Sergeant II',
      );
      expect(
        tier.localizedTitle(AppLocalizationsEn('en_GB')),
        'Master Gunnery Sergeant II',
      );
      expect(tier.localizedTitle(AppLocalizationsJa('ja_JP')), '上級曹長Ⅱ');
      expect(
        tier.localizedTitle(AppLocalizationsEn('fr_FR')),
        'Master Gunnery Sergeant II',
      );
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
      expect(rankOne.localizedTitle(AppLocalizationsJa()), '一等兵');
      expect(
        rankOne.localizedTitle(AppLocalizationsEn()),
        'Private First Class',
      );
      expect(rankOne.currentRankXp, 500);
      expect(rankOne.nextRankXp, 8000);
      expect(rankOne.xpToNextRank, 7500);

      final max = RankProgress.fromTotalXp(RankCatalog.stageXpTotal + 1234);
      expect(max.rank, 140);
      expect(max.localizedTitle(AppLocalizationsJa()), '大将');
      expect(max.localizedTitle(AppLocalizationsEn()), 'General');
      expect(max.totalXp, RankCatalog.stageXpTotal + 1234);
      expect(max.isMax, isTrue);
      expect(max.nextRankXp, isNull);
      expect(max.progressRatio, 1);
    });
  });

  group('result progress snapshots', () {
    test('fills the old rank before resetting into the next rank', () {
      final before = RankProgress.fromTotalXp(2500);
      final after = RankProgress.fromTotalXp(3000);

      expect(
        rankProgressBarValue(before: before, after: after, animation: 0),
        closeTo(before.progressRatio, 1e-12),
      );
      expect(
        rankProgressBarValue(before: before, after: after, animation: 0.5),
        1,
      );
      expect(
        rankProgressBarValue(before: before, after: after, animation: 1),
        closeTo(after.progressRatio, 1e-12),
      );
    });

    test('interpolates within one rank and stays full after MAX', () {
      final before = RankProgress.fromTotalXp(3500);
      final after = RankProgress.fromTotalXp(4500);
      expect(
        rankProgressBarValue(before: before, after: after, animation: 0.5),
        closeTo(0.125, 1e-12),
      );

      final maxBefore = RankProgress.fromTotalXp(RankCatalog.stageXpTotal);
      final maxAfter = RankProgress.fromTotalXp(
        RankCatalog.stageXpTotal + 3000,
      );
      for (final animation in [0.0, 0.5, 1.0]) {
        expect(
          rankProgressBarValue(
            before: maxBefore,
            after: maxAfter,
            animation: animation,
          ),
          1,
        );
      }
    });
  });

  testWidgets('exposes rank progress in settings and result screens', (
    tester,
  ) async {
    final store = (await tester.runAsync(() async {
      final fixture = ProfileFixture(xp: 2500);
      await fixture.ready();
      return fixture;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchPersistenceProvider.overrideWithValue(store.runtime),
          bgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
          menuBgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );

    await tester.pumpAndSettle();
    await openMatchSetup(tester);
    expect(find.text('ランク 0・新兵'), findsOneWidget);
    expect(find.text('次の昇級まで 500 XP'), findsOneWidget);
    await closeProfile(tester, store);
  });

  testWidgets(
    'updates rank names in settings and results when locale changes',
    (tester) async {
      final locale = ValueNotifier(const Locale('en', 'US'));
      addTearDown(locale.dispose);
      final loop = _ManualRankGameLoop();
      final store = (await tester.runAsync(() async {
        final fixture = ProfileFixture(xp: 2500);
        await fixture.ready();
        return fixture;
      }))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchPersistenceProvider.overrideWithValue(store.runtime),
            bgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
            menuBgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
            cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
          ],
          child: ValueListenableBuilder<Locale>(
            valueListenable: locale,
            builder: (context, value, child) => MyApp(locale: value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openMatchSetup(tester);
      expect(find.text('Rank 0 · Recruit'), findsOneWidget);

      final rankElement = tester.element(
        find.byKey(const ValueKey('rank-progress-card')),
      );
      final container = ProviderScope.containerOf(rankElement);
      final controller = container.read(gameControllerProvider.notifier);
      controller.selectCpuDifficulty(CpuDifficulty.hard);
      await runProfileIo(tester, () async {
        controller.startGame();
        loop.tickMany(60);
        controller.finish(const GameResult.victory(elapsedMs: 100));
        await store.runtime.drain();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        find.text('Rank Up! Rank 1 · Private First Class'),
        findsOneWidget,
      );
      final before = container.read(rankProgressProvider).value!;
      expect(before.totalXp, 5500);

      locale.value = const Locale('ja', 'JP');
      await tester.pump();

      expect(find.text('昇級！ ランク 1・一等兵'), findsOneWidget);
      expect(container.read(rankProgressProvider).value, before);
      await closeProfile(tester, store);
    },
  );

  testWidgets('fits a long English rank title in the compact settings layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = (await tester.runAsync(() async {
      final fixture = ProfileFixture(xp: RankCatalog.cumulativeXp[42]);
      await fixture.ready();
      return fixture;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchPersistenceProvider.overrideWithValue(store.runtime),
          bgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
          menuBgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
        ],
        child: const MyApp(locale: Locale('en', 'US')),
      ),
    );

    await tester.pumpAndSettle();
    await openMatchSetup(tester);
    expect(find.text('Rank 42 · Master Gunnery Sergeant II'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('rank-progress-card'))).width,
      lessThanOrEqualTo(280),
    );
    expect(tester.takeException(), isNull);
    await closeProfile(tester, store);
  });

  testWidgets('shows animated XP and rank-up emphasis in the result sheet', (
    tester,
  ) async {
    final loop = _ManualRankGameLoop();
    final store = (await tester.runAsync(() async {
      final fixture = ProfileFixture();
      await fixture.ready();
      return fixture;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchPersistenceProvider.overrideWithValue(store.runtime),
          bgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
          menuBgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await tester.pumpAndSettle();
    await openMatchSetup(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-button-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    await runProfileIo(tester, () async {
      controller.startGame();
      loop.tickMany(60);
      controller.finish(const GameResult.victory(elapsedMs: 100));
      await store.runtime.drain();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const ValueKey('result-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('rank-award-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-rank-progress')), findsOneWidget);
    expect(find.text('+3000 XP'), findsOneWidget);
    expect(find.text('昇級！ ランク 1・一等兵'), findsOneWidget);
    await closeProfile(tester, store);
  });

  testWidgets('animates the result bar from saved before and after XP', (
    tester,
  ) async {
    final loop = _ManualRankGameLoop();
    final store = (await tester.runAsync(() async {
      final fixture = ProfileFixture(xp: 2500);
      await fixture.ready();
      return fixture;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchPersistenceProvider.overrideWithValue(store.runtime),
          bgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
          menuBgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await tester.pumpAndSettle();
    await openMatchSetup(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-button-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.veryEasy);
    await runProfileIo(tester, () async {
      controller.startGame();
      loop.tickMany(60);
      controller.finish(const GameResult.victory(elapsedMs: 100));
      await store.runtime.drain();
    });
    await tester.pump();
    await tester.pump();

    final barFinder = find.byKey(const ValueKey('result-rank-progress'));
    expect(barFinder, findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(barFinder).value,
      closeTo(2500 / 3000, 1e-6),
    );

    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<LinearProgressIndicator>(barFinder).value,
      closeTo(1, 1e-6),
    );

    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<LinearProgressIndicator>(barFinder).value,
      closeTo(0, 1e-6),
    );
    expect(find.text('昇級！ ランク 1・一等兵'), findsOneWidget);
    await closeProfile(tester, store);
  });
}
