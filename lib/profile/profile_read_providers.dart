import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_state.dart';
import 'match_contracts.dart';
import 'match_persistence.dart';
import 'profile_repository.dart';

typedef ProfileQuery = ({String profileId, MatchHistoryFilter filter});
typedef MatchDetailQuery = ({String profileId, String matchId});
typedef FastestVictoryQuery = ({
  String profileId,
  CpuDifficulty difficulty,
  int islandCount,
});

final playerProfileRepositoryProvider = FutureProvider<PlayerProfileRepository>(
  (ref) async {
    final runtime = ref.watch(matchPersistenceProvider);
    if (runtime == null)
      throw StateError('Profile persistence is not injected');
    var initializing = true;
    ref.listen(
      profilePersistenceStateProvider.select(
        (_) => (runtime.profile?.profileId, runtime.initializationError),
      ),
      (_, _) {
        if (!initializing) ref.invalidateSelf();
      },
    );
    try {
      if (runtime.initializationError case final error?) throw error;
      await runtime.initialize();
      return runtime.backend!.repository;
    } finally {
      initializing = false;
    }
  },
  retry: (_, _) => null,
);

final activeProfileIdProvider = FutureProvider<String>((ref) async {
  final runtime = ref.watch(matchPersistenceProvider);
  await ref.watch(playerProfileRepositoryProvider.future);
  return runtime!.profile!.profileId;
}, retry: (_, _) => null);

final playerProfileProvider = StreamProvider.autoDispose
    .family<PlayerProfile, String>((ref, profileId) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchProfile(profileId);
    }, retry: (_, _) => null);

final profileStatisticsProvider = StreamProvider.autoDispose
    .family<MatchStatistics, ProfileQuery>((ref, query) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchStatistics(query.profileId, filter: query.filter);
    }, retry: (_, _) => null);

final difficultyStatisticsProvider = StreamProvider.autoDispose
    .family<Map<CpuDifficulty, MatchStatistics>, String>((
      ref,
      profileId,
    ) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchDifficultyStatistics(profileId);
    }, retry: (_, _) => null);

final recentMatchesProvider = StreamProvider.autoDispose
    .family<List<MatchHistoryEntry>, String>((ref, profileId) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchRecentMatches(profileId);
    }, retry: (_, _) => null);

final fastestVictoryProvider = StreamProvider.autoDispose
    .family<int?, FastestVictoryQuery>((ref, query) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository
          .watchStatistics(
            query.profileId,
            filter: MatchHistoryFilter(
              difficulty: query.difficulty,
              islandCount: query.islandCount,
              outcome: MatchOutcome.win,
            ),
          )
          .asyncMap(
            (_) => repository.fastestVictoryMs(
              query.profileId,
              difficulty: query.difficulty,
              islandCount: query.islandCount,
            ),
          );
    }, retry: (_, _) => null);

final matchDetailProvider = FutureProvider.autoDispose
    .family<MatchHistoryEntry?, MatchDetailQuery>((ref, query) async {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      return repository.loadMatch(query.profileId, query.matchId);
    }, retry: (_, _) => null);

final class MatchHistoryState {
  MatchHistoryState({
    required Iterable<MatchHistoryEntry> entries,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  }) : entries = List.unmodifiable(entries);

  final List<MatchHistoryEntry> entries;
  final MatchHistoryCursor? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;
}

final matchHistoryProvider = NotifierProvider.autoDispose
    .family<
      MatchHistoryController,
      AsyncValue<MatchHistoryState>,
      ProfileQuery
    >(MatchHistoryController.new);

final class MatchHistoryController
    extends Notifier<AsyncValue<MatchHistoryState>> {
  MatchHistoryController(this.query);
  final ProfileQuery query;
  int _generation = 0;
  Completer<MatchHistoryState>? _firstPage;

  Future<MatchHistoryState> get firstPage => _firstPage!.future;

  @override
  AsyncValue<MatchHistoryState> build() {
    _generation++;
    ref.onDispose(() {
      _generation++;
      if (_firstPage case final pending? when !pending.isCompleted) {
        pending.completeError(StateError('History reader disposed'));
      }
    });
    _prepareFirstPage();
    unawaited(
      _loadFirst(
        ref.watch(playerProfileRepositoryProvider.future),
        _generation,
      ),
    );
    return const AsyncLoading();
  }

  void _prepareFirstPage() {
    if (_firstPage == null || _firstPage!.isCompleted) {
      _firstPage = Completer<MatchHistoryState>();
      _firstPage!.future.ignore();
    }
  }

  Future<void> _loadFirst(
    Future<PlayerProfileRepository> repositoryFuture,
    int generation,
  ) async {
    final keepAlive = ref.keepAlive();
    try {
      final repository = await repositoryFuture;
      final page = await repository.loadHistory(
        query.profileId,
        filter: query.filter,
      );
      if (!ref.mounted || generation != _generation) return;
      final result = MatchHistoryState(
        entries: page.entries,
        nextCursor: page.nextCursor,
      );
      _firstPage!.complete(result);
      state = AsyncData(result);
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      _firstPage!.completeError(error, stack);
      state = AsyncError(error, stack);
    } finally {
      keepAlive.close();
    }
  }

  /// Drops all loaded pages. A new first page never shares an old cursor.
  void refresh() {
    _generation++;
    _prepareFirstPage();
    state = const AsyncLoading();
    unawaited(
      _loadFirst(ref.read(playerProfileRepositoryProvider.future), _generation),
    );
  }

  Future<void> loadMore() async {
    final previous = state.asData?.value;
    if (previous == null || previous.loadingMore || previous.nextCursor == null)
      return;
    final generation = _generation;
    state = AsyncData(
      MatchHistoryState(
        entries: previous.entries,
        nextCursor: previous.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final repository = await ref.read(playerProfileRepositoryProvider.future);
      final page = await repository.loadHistory(
        query.profileId,
        filter: query.filter,
        before: previous.nextCursor,
      );
      if (!ref.mounted || generation != _generation) return;
      final ids = previous.entries
          .map((entry) => entry.record.start.matchId)
          .toSet();
      state = AsyncData(
        MatchHistoryState(
          entries: [
            ...previous.entries,
            ...page.entries.where(
              (entry) => ids.add(entry.record.start.matchId),
            ),
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        MatchHistoryState(
          entries: previous.entries,
          nextCursor: previous.nextCursor,
          loadMoreError: error,
        ),
      );
    }
  }
}
