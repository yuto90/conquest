import 'dart:async';
import 'dart:io';

import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/home.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/main.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/profile/profile_read_providers.dart';
import 'package:conquest/profile/profile_repository.dart';
import 'package:conquest/profile/profile_database.dart' as db;
import 'package:conquest/profile/storage_native.dart' as native;
import 'package:conquest/rank_progression.dart';
import 'package:conquest/ui/my_page.dart';
import 'package:conquest/ui/my_page_destinations.dart';
import 'package:conquest/ui/profile_editor.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profile_fixture.dart';
import 'support/profile_widget_io.dart';
import 'match_persistence_controller_test.dart' show Harness;

final class _RepositoryProbe implements PlayerProfileRepository {
  _RepositoryProbe(this.delegate);
  final PlayerProfileRepository delegate;
  Object? editError;
  Object? statisticsError;
  Completer<void>? editGate;
  int edits = 0;
  int statisticsReads = 0;
  final fastestQueries = <(CpuDifficulty, int)>[];

  @override
  Future<PlayerProfile> editProfile(String id, ProfileEdit edit) async {
    edits++;
    await editGate?.future;
    if (editError case final error?) throw error;
    return delegate.editProfile(id, edit);
  }

  @override
  Stream<PlayerProfile> watchProfile(String id) => delegate.watchProfile(id);
  @override
  Stream<int> watchTotalXp(String id) => delegate.watchTotalXp(id);
  @override
  Stream<MatchStatistics> watchStatistics(
    String id, {
    MatchHistoryFilter? filter,
  }) {
    statisticsReads++;
    if (statisticsError case final error?) return Stream.error(error);
    return delegate.watchStatistics(id, filter: filter);
  }

  @override
  Stream<Map<CpuDifficulty, MatchStatistics>> watchDifficultyStatistics(
    String id,
  ) => delegate.watchDifficultyStatistics(id);
  @override
  Future<int?> fastestVictoryMs(
    String id, {
    required CpuDifficulty difficulty,
    required int islandCount,
  }) {
    fastestQueries.add((difficulty, islandCount));
    return delegate.fastestVictoryMs(
      id,
      difficulty: difficulty,
      islandCount: islandCount,
    );
  }

  @override
  Future<MatchHistoryPage> loadHistory(
    String id, {
    MatchHistoryFilter? filter,
    MatchHistoryCursor? before,
    int limit = 20,
  }) => delegate.loadHistory(id, filter: filter, before: before, limit: limit);
  @override
  Stream<List<MatchHistoryEntry>> watchRecentMatches(String id) =>
      delegate.watchRecentMatches(id);
  @override
  Future<MatchHistoryEntry?> loadMatch(String id, String matchId) =>
      delegate.loadMatch(id, matchId);
}

final class _SilentBgm implements BgmPlayer {
  @override
  Future<void> prepare() async {}
  @override
  Future<void> playFromStart() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAndReset() async {}
  @override
  Future<void> dispose() async {}
}

Future<void> settle(
  WidgetTester tester, {
  bool backgroundDatabase = false,
}) async {
  if (backgroundDatabase) {
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<ProfileFixture> newFixture(WidgetTester tester, {int? xp}) async {
  final fixture = (await tester.runAsync(() async => ProfileFixture(xp: xp)))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.runtime.close);
  });
  return fixture;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  fail('Could not reveal $finder');
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  ProfileFixture fixture, {
  Widget home = const MyPageScreen(),
  _RepositoryProbe? repository,
  Locale locale = const Locale('en'),
  double scale = 1,
  bool backgroundDatabase = false,
}) async {
  await tester.runAsync(fixture.ready);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      matchPersistenceProvider.overrideWithValue(fixture.runtime),
      if (repository != null)
        playerProfileRepositoryProvider.overrideWith((_) async => repository),
      bgmPlayerProvider.overrideWithValue(_SilentBgm()),
      menuBgmPlayerProvider.overrideWithValue(_SilentBgm()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: home is MyApp
          ? home
          : MaterialApp(
              locale: locale,
              theme: buildTacticalTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: home,
            ),
    ),
  );
  await settle(tester, backgroundDatabase: backgroundDatabase);
  return container;
}

Future<void> openEditor(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('edit-profile')));
  await tester.tap(find.byKey(const ValueKey('edit-profile')));
  await settle(tester);
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('save-profile')));
  await tester.tap(find.byKey(const ValueKey('save-profile')));
  await settle(tester);
}

Future<MatchRecord> seedVictory(ProfileFixture fixture, int id) async {
  final start = MatchStartContext(
    matchId: '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
    profileId: fixture.runtime.profile!.profileId,
    executionId: fixture.store.executionId,
    configuration: GameConfiguration(totalIslandCount: 8),
    sessionKind: SessionKind.normal,
    origin: SessionOrigin.gameplay,
    startedAtUtc: fixture.clock.time.add(Duration(minutes: id)),
    appVersion: 'test',
    rulesVersion: '1',
  );
  await fixture.store.recordStart(start);
  return (await fixture.store.complete(
    MatchCompletion.fromGame(
      start: start,
      result: const GameResult(
        type: GameResultType.victory,
        winner: Faction.player,
        elapsedMs: 3723000,
      ),
      summary: const MatchSummary(
        elapsedMs: 3723000,
        playerDispatchCount: 4,
        playerDispatchedForces: 77,
        playerCaptureCount: 3,
      ),
      endedAtUtc: start.startedAtUtc.add(const Duration(milliseconds: 3723000)),
    ),
  )).record;
}

void main() {
  testWidgets(
    'native opener restart restores controller receipts, profile and provider/UI totals',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('conquest-ui-reopen-'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      final ids = FixtureIds();
      late ProfileFixture reopened;
      late String profileId;
      late String matchId;
      const summary = MatchSummary(
        elapsedMs: 65000,
        playerDispatchCount: 4,
        playerDispatchedForces: 77,
        playerCaptureCount: 3,
      );
      await tester.runAsync(() async {
        final first = await native.openStorageConnection(
          supportDirectory: directory,
        );
        final fixture = ProfileFixture(
          database: db.ProfileDatabase(first.executor),
          lease: first.lease,
          ids: ids,
          xp: 500,
        );
        await fixture.ready();
        final harness = Harness(fixture);
        harness.play();
        harness.controller.state = harness.controller.state.copyWith(
          matchSummary: summary,
        );
        matchId = harness.controller.currentMatchId!;
        await harness.finish(const GameResult.victory(elapsedMs: 65000));
        profileId = fixture.runtime.profile!.profileId;
        await fixture.repository.editProfile(
          profileId,
          ProfileEdit(displayName: 'Restored captain', avatarKey: 'island_02'),
        );
        expect(harness.controller.state.result!.totalXpAfter, 2000);
        harness.dispose();
        await fixture.runtime.close();
        final next = await native.openStorageConnection(
          supportDirectory: directory,
        );
        reopened = ProfileFixture(
          database: db.ProfileDatabase(next.executor),
          lease: next.lease,
          ids: ids,
          xp: 999999,
        );
        await reopened.ready();
        expect(reopened.runtime.profile!.profileId, profileId);
        expect(reopened.legacy.reads, 0);
        expect(
          (await reopened.repository.loadMatch(
            profileId,
            matchId,
          ))!.record.metrics,
          MatchMetrics.fromSummary(summary),
        );
      });
      final container = await mount(tester, reopened, backgroundDatabase: true);
      expect(find.text('Restored captain'), findsOneWidget);
      expect(find.text('Total XP: 2000'), findsOneWidget);
      expect(find.text('100%'), findsWidgets);
      expect(find.text('0:01:05'), findsWidgets);
      await tester.runAsync(() async {
        expect(
          (await container.read(rankProgressProvider.future)).totalXp,
          2000,
        );
        final stats = await container.read(
          profileStatisticsProvider((
            profileId: profileId,
            filter: MatchHistoryFilter(),
          )).future,
        );
        expect(stats.wins, 1);
        expect(stats.elapsedMs, 65000);
        expect(stats.dispatchCount, 4);
        expect(stats.forcesSent, 77);
        expect(stats.captures, 3);
        expect(
          (await container.read(
            playerProfileProvider(profileId).future,
          )).displayName,
          'Restored captain',
        );
      });
      await reveal(tester, find.byType(MyPageRecentMatchRow));
      final row = tester.widget<MyPageRecentMatchRow>(
        find.byType(MyPageRecentMatchRow),
      );
      expect(row.entry.record.start.matchId, matchId);
      expect(row.entry.xpAwarded, 1500);
      await tester.tap(find.byType(MyPageRecentMatchRow));
      await settle(tester, backgroundDatabase: true);
      expect(find.byType(MyPageMatchDetailScreen), findsOneWidget);
      expect(find.text('77'), findsOneWidget);
      expect(find.text('1,500'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
      await runProfileIo(tester, reopened.runtime.close);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'profile initialization is loading until repository data arrives',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await newFixture(tester, xp: 200);
      await tester.runAsync(fixture.ready);
      final profileId = Completer<String>();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          matchPersistenceProvider.overrideWithValue(fixture.runtime),
          activeProfileIdProvider.overrideWith((_) => profileId.future),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            theme: buildTacticalTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MyPageScreen(),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No completed matches recorded yet.'), findsNothing);
      expect(find.byKey(const ValueKey('edit-profile')), findsNothing);
      profileId.complete(fixture.runtime.profile!.profileId);
      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Commander'), findsOneWidget);
      expect(find.text('Total XP: 200'), findsOneWidget);
      expect(find.text('No completed matches recorded yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings route preserves configuration, map and BGM toggle', (
    tester,
  ) async {
    final fixture = await newFixture(tester);
    addTearDown(fixture.runtime.dispose);
    final container = await mount(
      tester,
      fixture,
      home: const MyApp(locale: Locale('en')),
    );
    await tester.tap(find.byKey(const ValueKey('title-start')));
    await settle(tester);
    final gameContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('start-game'))),
    );
    final controller = gameContainer.read(gameControllerProvider.notifier);
    controller.selectIslandCount(12);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('bgm-toggle')));
    await tester.tap(find.byKey(const ValueKey('bgm-toggle')));
    await tester.pumpAndSettle();
    final before = gameContainer.read(gameControllerProvider);
    final toggle = tester
        .widget<Switch>(find.byKey(const ValueKey('bgm-toggle')))
        .value;
    await tester.ensureVisible(find.byKey(const ValueKey('open-my-page')));
    await tester.tap(find.byKey(const ValueKey('open-my-page')));
    await settle(tester);
    expect(find.byKey(const ValueKey('my-page')), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(gameContainer.read(gameControllerProvider), same(before));
    expect(
      tester.widget<Switch>(find.byKey(const ValueKey('bgm-toggle'))).value,
      toggle,
    );
    expect(container.read(matchPersistenceProvider), same(fixture.runtime));
  });

  testWidgets('trimmed grapheme name and avatar persist; keyboard submits', (
    tester,
  ) async {
    final fixture = await newFixture(tester, xp: 200);
    addTearDown(fixture.runtime.dispose);
    await mount(tester, fixture);
    expect(find.text('Total XP: 200'), findsOneWidget);
    final rank = RankCatalog.progressForXp(200);
    expect(find.textContaining('${rank.rank}'), findsWidgets);
    await openEditor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      '  👨‍👩‍👧‍👦隊長  ',
    );
    await tester.tap(find.byKey(const ValueKey('profile-avatar-island_03')));
    await tester.showKeyboard(find.byKey(const ValueKey('profile-name')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    final stored = await tester.runAsync(
      () => fixture.repository
          .watchProfile(fixture.runtime.profile!.profileId)
          .first,
    );
    expect(stored!.displayName, '👨‍👩‍👧‍👦隊長');
    expect(stored.avatarKey, 'island_03');
    expect(find.byKey(const ValueKey('profile-editor')), findsNothing);
    expect(find.text('👨‍👩‍👧‍👦隊長'), findsOneWidget);
  });

  testWidgets('empty, control and overlong names never reach the repository', (
    tester,
  ) async {
    final fixture = await newFixture(tester);
    addTearDown(fixture.runtime.dispose);
    final probe = _RepositoryProbe(fixture.repository);
    await mount(tester, fixture, repository: probe);
    await openEditor(tester);
    for (final invalid in ['   ', 'A\u0001B', List.filled(21, '界').join()]) {
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        invalid,
      );
      await save(tester);
      expect(find.textContaining('1–20'), findsWidgets);
      expect(probe.edits, 0);
      expect(find.byKey(const ValueKey('profile-editor')), findsOneWidget);
    }
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      List.filled(20, '👨‍👩‍👧‍👦').join(),
    );
    await save(tester);
    expect(probe.edits, 1);
    expect(find.byKey(const ValueKey('profile-editor')), findsNothing);
  });

  testWidgets(
    'saving disables controls; failure retains draft and retry saves it',
    (tester) async {
      final fixture = await newFixture(tester);
      addTearDown(fixture.runtime.dispose);
      final probe = _RepositoryProbe(fixture.repository)
        ..editError = StateError('disk full')
        ..editGate = Completer<void>();
      await mount(tester, fixture, repository: probe);
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Captain',
      );
      await tester.tap(find.byKey(const ValueKey('profile-avatar-island_02')));
      await save(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-profile')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('profile-name')))
            .enabled,
        isFalse,
      );
      probe.editGate!.complete();
      await settle(tester);
      expect(find.text('Captain'), findsOneWidget);
      expect(find.textContaining('Not saved.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      final unchanged = await tester.runAsync(
        () => fixture.repository
            .watchProfile(fixture.runtime.profile!.profileId)
            .first,
      );
      expect(unchanged!.displayName, isNull);
      probe.editError = null;
      await save(tester);
      expect(probe.edits, 2);
      expect(find.byKey(const ValueKey('profile-editor')), findsNothing);
      final stored = await tester.runAsync(
        () => fixture.repository
            .watchProfile(fixture.runtime.profile!.profileId)
            .first,
      );
      expect(stored!.displayName, 'Captain');
      expect(stored.avatarKey, 'island_02');
    },
  );

  testWidgets(
    'cancel and back confirm dirty edits; default avatar-only edit keeps name null',
    (tester) async {
      final fixture = await newFixture(tester);
      addTearDown(fixture.runtime.dispose);
      await mount(tester, fixture);
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Unsaved',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('cancel-profile-edit')),
      );
      await tester.tap(find.byKey(const ValueKey('cancel-profile-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discard-profile-edit')));
      await settle(tester);
      expect(find.text('Unsaved'), findsNothing);
      await openEditor(tester);
      await tester.tap(find.byKey(const ValueKey('profile-avatar-island_04')));
      await save(tester);
      final stored = await tester.runAsync(
        () => fixture.repository
            .watchProfile(fixture.runtime.profile!.profileId)
            .first,
      );
      expect(stored!.displayName, isNull);
      expect(stored.avatarKey, 'island_04');
    },
  );

  testWidgets(
    'repository stats, exact fastest query, recent five and scoped detail route',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await newFixture(tester);
      addTearDown(fixture.runtime.dispose);
      await tester.runAsync(() async {
        await fixture.ready();
        for (var i = 1; i <= 6; i++) {
          await seedVictory(fixture, i);
        }
      });
      final probe = _RepositoryProbe(fixture.repository);
      await mount(tester, fixture, repository: probe);
      expect(find.text('100%'), findsWidgets);
      expect(find.text('6:12:18'), findsWidgets);
      await reveal(tester, find.byKey(const ValueKey('fastest-islands')));
      await tester.tap(find.byKey(const ValueKey('fastest-islands')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8 islands').last);
      await settle(tester);
      expect(probe.fastestQueries, contains((CpuDifficulty.normal, 8)));
      expect(find.text('1:02:03'), findsWidgets);
      await reveal(tester, find.byKey(const ValueKey('my-page-view-history')));
      await settle(tester);
      expect(find.byType(MyPageRecentMatchRow), findsNWidgets(5));
      final row = tester.widget<MyPageRecentMatchRow>(
        find.byType(MyPageRecentMatchRow).first,
      );
      expect(row.entry.record.start.matchId, endsWith('000000000006'));
      await tester.ensureVisible(find.byType(MyPageRecentMatchRow).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MyPageRecentMatchRow).first);
      await settle(tester);
      final detail = tester.widget<MyPageMatchDetailScreen>(
        find.byType(MyPageMatchDetailScreen),
      );
      expect(detail.profileId, fixture.runtime.profile!.profileId);
      expect(detail.matchId, row.entry.record.start.matchId);
      final route = ModalRoute.of(
        tester.element(find.byType(MyPageMatchDetailScreen)),
      )!;
      expect(route.settings.name, '/my-page/match');
      expect(route.settings.arguments, (
        profileId: detail.profileId,
        matchId: detail.matchId,
      ));
      await tester.pageBack();
      await settle(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('my-page-view-history')),
      );
      await tester.tap(find.byKey(const ValueKey('my-page-view-history')));
      await tester.pumpAndSettle();
      expect(find.byType(MyPageHistoryTab), findsOneWidget);
      expect(find.byKey(const ValueKey('history-difficulty')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-result')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-islands')), findsOneWidget);
      await settle(tester);
      final history =
          ProviderScope.containerOf(
                tester.element(find.byType(MyPageHistoryTab)),
              )
              .read(
                matchHistoryProvider((
                  profileId: detail.profileId,
                  filter: MatchHistoryFilter(),
                )),
              )
              .requireValue;
      expect(history.entries.length, 6);
      expect(history.entries.first.record.start.matchId, detail.matchId);
      expect(history.nextCursor, isNull);
    },
  );

  testWidgets(
    'read failure is not empty; retry recovers to genuine empty data',
    (tester) async {
      final fixture = await newFixture(tester);
      addTearDown(fixture.runtime.dispose);
      final probe = _RepositoryProbe(fixture.repository)
        ..statisticsError = StateError('read failed');
      await mount(tester, fixture, repository: probe);
      expect(find.textContaining('Could not load'), findsWidgets);
      expect(find.text('No completed matches recorded yet.'), findsNothing);
      final reads = probe.statisticsReads;
      probe.statisticsError = null;
      await reveal(tester, find.text('Retry').first);
      await tester.tap(find.text('Retry').first);
      await settle(tester);
      expect(probe.statisticsReads, greaterThan(reads));
      expect(find.text('No completed matches recorded yet.'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    },
  );

  testWidgets(
    'Japanese scaled phone layout, keyboard traversal and unknown avatar remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await newFixture(tester);
      addTearDown(fixture.runtime.dispose);
      final semantics = tester.ensureSemantics();
      await mount(tester, fixture, locale: const Locale('ja'), scale: 2);
      expect(find.text('マイページ / PROFILE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await openEditor(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.ensureVisible(find.byKey(const ValueKey('profile-name')));
      await tester.enterText(find.byKey(const ValueKey('profile-name')), '日本語');
      await save(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('日本語'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: ProfileAvatar(avatarKey: 'future-avatar')),
      );
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'nullable metrics and noncompleted counts have accurate accessible labels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatisticsValues(
              statistics: MatchStatistics(
                wins: 2,
                losses: 1,
                draws: 1,
                abandoned: 3,
                interrupted: 4,
                elapsedMs: null,
                dispatchCount: null,
                forcesSent: null,
                captures: null,
              ),
            ),
          ),
        ),
      );
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(4));
      expect(find.bySemanticsLabel('Completed matches: 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Abandoned: 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Result unknown: 4'), findsOneWidget);
      semantics.dispose();
    },
  );
}
