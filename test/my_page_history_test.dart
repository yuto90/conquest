import 'dart:async';

import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/profile_read_providers.dart';
import 'package:conquest/profile/profile_repository.dart';
import 'package:conquest/ui/my_page_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/profile_fixture.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final started = DateTime.utc(2026, 10, 2, 23, 45);

MatchHistoryEntry entry(
  int n, {
  String? profileId,
  CpuDifficulty difficulty = CpuDifficulty.normal,
  int islands = 10,
  MatchStatus status = MatchStatus.completed,
  MatchOutcome outcome = MatchOutcome.win,
  String? executionId,
}) {
  return MatchHistoryEntry(
    xpAwarded: status == MatchStatus.completed && outcome == MatchOutcome.win
        ? 777
        : 0,
    record: MatchRecord(
      start: MatchStartContext(
        matchId: id(n),
        profileId: profileId ?? id(99999),
        executionId: executionId ?? id(99998),
        configuration: GameConfiguration(
          cpuDifficulty: difficulty,
          totalIslandCount: islands,
        ),
        sessionKind: SessionKind.normal,
        origin: SessionOrigin.gameplay,
        startedAtUtc: started,
        appVersion: 'historical-app',
        rulesVersion: 'historical-rules',
        metricsVersion: 2,
      ),
      status: status,
      outcome: status == MatchStatus.completed ? outcome : null,
      endedAtUtc:
          status == MatchStatus.completed || status == MatchStatus.abandoned
          ? started.add(const Duration(hours: 26))
          : null,
      recoveredAtUtc: status == MatchStatus.interrupted
          ? started.add(const Duration(days: 1))
          : null,
      metrics:
          status == MatchStatus.completed || status == MatchStatus.abandoned
          ? MatchMetrics(
              elapsedMs: 90061000,
              dispatchCount: 7,
              forcesSent: 12345,
              captures: 22,
            )
          : null,
    ),
  );
}

typedef HistoryCall = ({
  String profileId,
  MatchHistoryFilter filter,
  MatchHistoryCursor? before,
  int limit,
});

class HistoryRepository implements PlayerProfileRepository {
  HistoryRepository(this.entries);
  final List<MatchHistoryEntry> entries;
  final changes = StreamController<void>.broadcast(sync: true);
  final calls = <HistoryCall>[];
  final detailCalls = <(String, String)>[];
  Completer<void>? gate;
  Object? nextError;
  Object? detailError;
  Completer<void>? detailGate;

  List<MatchHistoryEntry> matching(
    String profileId,
    MatchHistoryFilter filter,
  ) =>
      entries.where((e) {
        final r = e.record;
        return r.start.profileId == profileId &&
            (filter.difficulty == null ||
                filter.difficulty == r.start.configuration.cpuDifficulty) &&
            (filter.islandCount == null ||
                filter.islandCount == r.start.configuration.totalIslandCount) &&
            (filter.status == null || filter.status == r.status) &&
            (filter.outcome == null || filter.outcome == r.outcome);
      }).toList()..sort(
        (a, b) => b.record.start.matchId.compareTo(a.record.start.matchId),
      );

  @override
  Future<MatchHistoryPage> loadHistory(
    String profileId, {
    MatchHistoryFilter? filter,
    MatchHistoryCursor? before,
    int limit = 20,
  }) async {
    final effective = filter ?? MatchHistoryFilter();
    before?.requireScope(profileId, effective);
    calls.add((
      profileId: profileId,
      filter: effective,
      before: before,
      limit: limit,
    ));
    final rows = matching(profileId, effective)
        .where(
          (e) =>
              before == null ||
              e.record.start.matchId.compareTo(before.matchId) < 0,
        )
        .toList();
    final page = rows.take(limit).toList();
    final result = MatchHistoryPage(
      entries: page,
      nextCursor: rows.length > limit
          ? MatchHistoryCursor(
              profileId: profileId,
              filter: effective,
              startedAtUtc: started,
              matchId: page.last.record.start.matchId,
            )
          : null,
    );
    final pending = gate;
    gate = null;
    final error = nextError;
    nextError = null;
    await pending?.future;
    if (error != null) throw error;
    return result;
  }

  @override
  Stream<List<MatchHistoryEntry>> watchRecentMatches(String profileId) async* {
    yield matching(profileId, MatchHistoryFilter()).take(5).toList();
    yield* changes.stream.map(
      (_) => matching(profileId, MatchHistoryFilter()).take(5).toList(),
    );
  }

  @override
  Future<MatchHistoryEntry?> loadMatch(String profileId, String matchId) async {
    detailCalls.add((profileId, matchId));
    final matches = entries.where(
      (e) =>
          e.record.start.profileId == profileId &&
          e.record.start.matchId == matchId,
    );
    final snapshot = matches.isEmpty ? null : matches.single;
    final pending = detailGate;
    detailGate = null;
    final error = detailError;
    detailError = null;
    await pending?.future;
    if (error != null) throw error;
    return snapshot;
  }

  @override
  Stream<PlayerProfile> watchProfile(String profileId) => Stream.value(
    PlayerProfile(
      profileId: profileId,
      avatarKey: 'commander',
      createdAtUtc: started,
      updatedAtUtc: started,
      statsStartedAtUtc: started,
    ),
  );
  @override
  Future<PlayerProfile> editProfile(String profileId, ProfileEdit edit) =>
      throw UnsupportedError('History must never write');
  @override
  Stream<int> watchTotalXp(String profileId) => Stream.value(
    entries
        .where((e) => e.record.start.profileId == profileId)
        .fold(0, (total, e) => total + e.xpAwarded),
  );
  @override
  Stream<MatchStatistics> watchStatistics(
    String profileId, {
    MatchHistoryFilter? filter,
  }) => throw UnsupportedError('Use real SQLite for statistics assertions');
  @override
  Stream<Map<CpuDifficulty, MatchStatistics>> watchDifficultyStatistics(
    String profileId,
  ) => throw UnsupportedError('Unused');
  @override
  Future<int?> fastestVictoryMs(
    String profileId, {
    required CpuDifficulty difficulty,
    required int islandCount,
  }) => throw UnsupportedError('Unused');
}

Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump();
  }
}

Future<T> databaseOperation<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) async {
  late Future<T> result;
  var done = false;
  await tester.runAsync(() async {
    result = operation();
    result.then((_) => done = true, onError: (Object _) => done = true);
  });
  for (var i = 0; i < 100 && !done; i++) {
    await drain(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(
    done,
    isTrue,
    reason:
        'SQLite operation must complete while widget subscriptions are pumped',
  );
  return result;
}

Future<void> mount(
  WidgetTester tester,
  PlayerProfileRepository repository, {
  String? profileId,
  Widget? home,
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playerProfileRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home:
            home ??
            Scaffold(body: MyPageHistoryTab(profileId: profileId ?? id(99999))),
      ),
    ),
  );
  await drain(tester);
}

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MyPageHistoryTab)));
MatchHistoryState page(
  WidgetTester tester, {
  MatchHistoryFilter? filter,
  String? profileId,
}) => container(tester)
    .read(
      matchHistoryProvider((
        profileId: profileId ?? id(99999),
        filter: filter ?? MatchHistoryFilter(),
      )),
    )
    .requireValue;

Future<void> choose(WidgetTester tester, String key, String label) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.text(label).last);
  await tester.pump();
  await tester.tap(find.text(label).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await drain(tester);
}

Future<void> footer(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('history-load-more')),
    500,
    maxScrolls: 30,
  );
  await drain(tester);
}

void main() {
  for (final count in [0, 1, 20, 21, 10000]) {
    testWidgets(
      '$count records use bounded pages and a lazy list, including equal timestamps',
      (tester) async {
        final repo = HistoryRepository(
          List.generate(count, (i) => entry(i + 1)),
        );
        addTearDown(repo.changes.close);
        await mount(tester, repo);
        expect(page(tester).entries.length, count.clamp(0, 20));
        expect(
          repo.calls.every((c) => c.limit == 20 && c.before == null),
          isTrue,
        );
        expect(
          find.byType(MyPageRecentMatchRow).evaluate().length,
          lessThanOrEqualTo(10),
        );
        if (count == 0)
          expect(find.text('No matches recorded yet.'), findsOneWidget);
        if (count <= 20) expect(page(tester).nextCursor, isNull);
        if (count > 20) {
          await footer(tester);
          await tester.tap(find.byKey(const ValueKey('history-load-more')));
          await drain(tester);
          final rows = page(tester).entries;
          expect(rows.length, count.clamp(0, 40));
          expect(
            rows.map((e) => e.record.start.matchId).toSet().length,
            rows.length,
          );
          expect(repo.calls.last.before, isNotNull);
          expect(repo.calls.last.limit, 20);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'initial/loading-more errors retry without empty states or duplicate rows; repeated taps are ignored',
    (tester) async {
      final repo = HistoryRepository(List.generate(21, (i) => entry(i + 1)))
        ..nextError = StateError('first failure');
      addTearDown(repo.changes.close);
      await mount(tester, repo);
      expect(
        find.text(
          'Could not load saved data. Your records have not been cleared.',
        ),
        findsOneWidget,
      );
      expect(find.text('No matches recorded yet.'), findsNothing);
      await tester.tap(find.text('Retry'));
      await drain(tester);
      expect(page(tester).entries.length, 20);
      await footer(tester);
      repo.nextError = StateError('page failure');
      await tester.tap(find.byKey(const ValueKey('history-load-more')));
      await drain(tester);
      expect(page(tester).entries.length, 20);
      expect(
        find.text(
          'Could not load more matches. Displayed records are unchanged.',
        ),
        findsOneWidget,
      );
      final gate = Completer<void>();
      repo.gate = gate;
      final button = tester.widget<TextButton>(
        find.byKey(const ValueKey('history-load-more')),
      );
      final before = repo.calls.length;
      button.onPressed!();
      button.onPressed!();
      await drain(tester);
      expect(page(tester).loadingMore, isTrue);
      expect(repo.calls.length, before + 1);
      expect(find.bySemanticsLabel('Loading more matches…'), findsOneWidget);
      gate.complete();
      await drain(tester);
      expect(page(tester).entries.length, 21);
      expect(page(tester).loadMoreError, isNull);
      expect(page(tester).nextCursor, isNull);
    },
  );

  testWidgets(
    'combined filters, clear and stale initial/pagination responses stay scoped',
    (tester) async {
      final repo = HistoryRepository([
        for (var i = 1; i <= 25; i++) entry(i),
        entry(
          26,
          difficulty: CpuDifficulty.hard,
          islands: 16,
          status: MatchStatus.abandoned,
        ),
        entry(
          27,
          difficulty: CpuDifficulty.hard,
          islands: 16,
          status: MatchStatus.interrupted,
        ),
        entry(
          28,
          difficulty: CpuDifficulty.hard,
          islands: 16,
          outcome: MatchOutcome.draw,
        ),
      ]);
      addTearDown(repo.changes.close);
      final oldGate = Completer<void>();
      repo.gate = oldGate;
      await mount(tester, repo);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await choose(tester, 'history-difficulty', 'Hard');
      await choose(tester, 'history-islands', '16 islands');
      await choose(tester, 'history-result', 'Abandoned');
      final filter = MatchHistoryFilter(
        difficulty: CpuDifficulty.hard,
        islandCount: 16,
        status: MatchStatus.abandoned,
      );
      expect(
        page(tester, filter: filter).entries.single.record.start.matchId,
        id(26),
      );
      oldGate.complete();
      await drain(tester);
      expect(
        page(tester, filter: filter).entries.single.record.status,
        MatchStatus.abandoned,
      );
      await choose(tester, 'history-result', 'Result unknown');
      expect(repo.calls.last.filter.status, MatchStatus.interrupted);
      await choose(tester, 'history-result', 'Victory');
      expect(find.text('No matches match these filters.'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await drain(tester);
      expect(page(tester).entries.length, 20);
      expect(repo.calls.last.before, isNull);
      await footer(tester);
      final moreGate = Completer<void>();
      repo.gate = moreGate;
      await tester.tap(find.byKey(const ValueKey('history-load-more')));
      await drain(tester);
      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pump(const Duration(milliseconds: 400));
      await choose(tester, 'history-difficulty', 'Hard');
      moreGate.complete();
      await drain(tester);
      final hard = page(
        tester,
        filter: MatchHistoryFilter(difficulty: CpuDifficulty.hard),
      );
      expect(hard.entries.length, 3);
      expect(
        hard.entries.every(
          (e) =>
              e.record.start.configuration.cpuDifficulty == CpuDifficulty.hard,
        ),
        isTrue,
      );
      expect(repo.calls.last.before, isNull);
    },
  );

  testWidgets(
    'new commits refresh cursor and reject overlapping old pagination and detail responses',
    (tester) async {
      final repo = HistoryRepository(List.generate(21, (i) => entry(i + 1)));
      addTearDown(repo.changes.close);
      await mount(tester, repo);
      await footer(tester);
      final gate = Completer<void>();
      repo.gate = gate;
      await tester.tap(find.byKey(const ValueKey('history-load-more')));
      await drain(tester);
      repo.entries.add(entry(22));
      repo.changes.add(null);
      await drain(tester);
      expect(page(tester).entries.first.record.start.matchId, id(22));
      expect(page(tester).entries.length, 20);
      expect(repo.calls.last.before, isNull);
      gate.complete();
      await drain(tester);
      expect(page(tester).entries.length, 20);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      final detailGate = Completer<void>();
      repo.detailGate = detailGate;
      repo.entries.add(entry(30, status: MatchStatus.inProgress));
      await mount(
        tester,
        repo,
        home: MyPageMatchDetailScreen(profileId: id(99999), matchId: id(30)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.entries.removeLast();
      repo.entries.add(entry(30));
      repo.changes.add(null);
      await drain(tester);
      expect(find.text('Victory'), findsOneWidget);
      detailGate.complete();
      await drain(tester);
      expect(find.text('In progress'), findsNothing);
    },
  );

  testWidgets(
    'details/back retain filters and position, display stored XP/versions and local dates',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repo = HistoryRepository(
        List.generate(25, (i) => entry(i + 1, difficulty: CpuDifficulty.hard)),
      );
      addTearDown(repo.changes.close);
      await mount(tester, repo);
      await choose(tester, 'history-difficulty', 'Hard');
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offset = scrollable.position.pixels;
      final row = find.byType(MyPageRecentMatchRow).hitTestable().first;
      final matchId = tester
          .widget<MyPageRecentMatchRow>(row)
          .entry
          .record
          .start
          .matchId;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(repo.detailCalls.last, (id(99999), matchId));
      await tester.ensureVisible(find.text('25:01:01'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Game time (h:mm:ss): 25:01:01'),
        findsOneWidget,
      );
      expect(
        find.text(DateFormat.yMd('en').add_Hm().format(started.toLocal())),
        findsOneWidget,
      );
      expect(find.text('777'), findsOneWidget);
      expect(find.text('historical-rules'), findsOneWidget);
      expect(find.text('historical-app'), findsOneWidget);
      await tester.ensureVisible(find.text('7'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Dispatches: 7'), findsOneWidget);
      await tester.ensureVisible(find.text('12,345'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Forces sent: 12,345'), findsOneWidget);
      await tester.ensureVisible(find.text('22'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Captures: 22'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, offset);
      expect(
        page(
          tester,
          filter: MatchHistoryFilter(difficulty: CpuDifficulty.hard),
        ).entries.length,
        20,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(find.text('Hard'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      final reads = repo.calls.length;
      Focus.of(tester.element(find.text('Refresh'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await drain(tester);
      expect(repo.calls.length, reads + 1);
      expect(repo.calls.last.before, isNull);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'pending initial reads and pagination may finish after the tab is disposed',
    (tester) async {
      final repo = HistoryRepository(List.generate(21, (i) => entry(i + 1)));
      addTearDown(repo.changes.close);
      final firstGate = Completer<void>();
      repo.gate = firstGate;
      await mount(tester, repo);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      firstGate.complete();
      await drain(tester);
      expect(tester.takeException(), isNull);
      await mount(tester, repo);
      await footer(tester);
      final moreGate = Completer<void>();
      repo.gate = moreGate;
      await tester.tap(find.byKey(const ValueKey('history-load-more')));
      await drain(tester);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      moreGate.complete();
      await drain(tester);
      expect(tester.takeException(), isNull);
      await mount(tester, repo);
      expect(page(tester).entries.length, 20);
      expect(repo.calls.last.before, isNull);
    },
  );

  testWidgets(
    'unknown/null, missing and detail errors differ; locale and scaled layouts remain usable',
    (tester) async {
      final repo = HistoryRepository([
        entry(1, status: MatchStatus.interrupted),
      ]);
      addTearDown(repo.changes.close);
      for (final size in [
        const Size(320, 568),
        const Size(1024, 768),
        const Size(768, 1024),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final locale in [const Locale('en'), const Locale('ja')]) {
          await mount(tester, repo, locale: locale, scale: 2);
          await choose(
            tester,
            'history-result',
            locale.languageCode == 'ja' ? '結果不明' : 'Result unknown',
          );
          await tester.scrollUntilVisible(
            find.byType(MyPageRecentMatchRow),
            250,
          );
          await tester.ensureVisible(find.byType(MyPageRecentMatchRow));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(MyPageRecentMatchRow));
          await tester.pumpAndSettle();
          expect(find.text('—'), findsNWidgets(4));
          expect(
            find.text(locale.languageCode == 'ja' ? '不明' : 'Unknown'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
          await drain(tester);
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await mount(
        tester,
        repo,
        home: MyPageMatchDetailScreen(profileId: id(123), matchId: id(1)),
      );
      expect(
        find.text('This match was not found in this profile.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      repo.detailError = StateError('detail read failure');
      await mount(
        tester,
        repo,
        home: MyPageMatchDetailScreen(profileId: id(99999), matchId: id(1)),
      );
      expect(
        find.text(
          'Could not load saved data. Your records have not been cleared.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('This match was not found in this profile.'),
        findsNothing,
      );
      await tester.tap(find.text('Retry'));
      await drain(tester);
      expect(find.text('Result unknown'), findsOneWidget);
    },
  );

  testWidgets(
    'real SQLite commit updates history/detail and the same cumulative counts without UI writes',
    (tester) async {
      final fixture = (await tester.runAsync(() async {
        final f = ProfileFixture(xp: 1234);
        await f.ready();
        return f;
      }))!;
      final profileId = fixture.runtime.profile!.profileId;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(fixture.runtime.close);
      });
      await mount(tester, fixture.repository, profileId: profileId);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await drain(tester);
      expect(page(tester, profileId: profileId).entries, isEmpty);
      final persisted = entry(
        1,
        profileId: profileId,
        executionId: fixture.store.executionId,
      ).record;
      await databaseOperation(tester, () async {
        await fixture.recordStart(persisted.start);
        await fixture.complete(
          MatchCompletion.fromGame(
            start: persisted.start,
            result: GameResult(
              type: GameResultType.victory,
              winner: Faction.player,
              elapsedMs: 90061000,
            ),
            summary: MatchSummary(
              elapsedMs: 90061000,
              playerDispatchCount: 7,
              playerDispatchedForces: 12345,
              playerCaptureCount: 22,
            ),
            endedAtUtc: persisted.endedAtUtc!,
          ),
        );
      });
      await drain(tester);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await drain(tester);
      final history = page(tester, profileId: profileId).entries.single;
      final stats = await databaseOperation(
        tester,
        () => fixture.repository.watchStatistics(profileId).first,
      );
      expect(stats.completed, 1);
      expect(stats.wins, 1);
      expect(stats.dispatchCount, history.record.metrics.dispatchCount);
      expect(history.xpAwarded, 1500);
      await tester.ensureVisible(find.byType(MyPageRecentMatchRow));
      await tester.tap(find.byType(MyPageRecentMatchRow));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await drain(tester);
      expect(find.text('1,500'), findsOneWidget);
      expect(
        await databaseOperation(
          tester,
          () => fixture.repository.watchTotalXp(profileId).first,
        ),
        2734,
      );
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(fixture.runtime.close);
    },
  );
}
