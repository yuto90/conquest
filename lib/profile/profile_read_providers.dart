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
    ref.watch(
      profilePersistenceStateProvider.select(
        (_) => (
          runtime.profile?.profileId,
          runtime.initializationError,
          runtime.checkingOwnership,
        ),
      ),
    );
    await runtime.initialize();
    return runtime.backend!.repository;
  },
);

final activeProfileIdProvider = FutureProvider<String>((ref) async {
  await ref.watch(playerProfileRepositoryProvider.future);
  return ref.watch(matchPersistenceProvider)!.profile!.profileId;
});

final playerProfileProvider = StreamProvider.autoDispose
    .family<PlayerProfile, String>((ref, profileId) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchProfile(profileId);
    });

final profileStatisticsProvider = StreamProvider.autoDispose
    .family<MatchStatistics, ProfileQuery>((ref, query) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchStatistics(query.profileId, filter: query.filter);
    });

final difficultyStatisticsProvider = StreamProvider.autoDispose
    .family<Map<CpuDifficulty, MatchStatistics>, String>((
      ref,
      profileId,
    ) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchDifficultyStatistics(profileId);
    });

final recentMatchesProvider = StreamProvider.autoDispose
    .family<List<MatchHistoryEntry>, String>((ref, profileId) async* {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      yield* repository.watchRecentMatches(profileId);
    });

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
    });

final matchDetailProvider = FutureProvider.autoDispose
    .family<MatchHistoryEntry?, MatchDetailQuery>((ref, query) async {
      final repository = await ref.watch(
        playerProfileRepositoryProvider.future,
      );
      return repository.loadMatch(query.profileId, query.matchId);
    });

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

final matchHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<MatchHistoryController, MatchHistoryState, ProfileQuery>(
      MatchHistoryController.new,
    );

final class MatchHistoryController extends AsyncNotifier<MatchHistoryState> {
  MatchHistoryController(this.query);
  final ProfileQuery query;
  int _generation = 0;

  @override
  Future<MatchHistoryState> build() async {
    _generation++;
    ref.onDispose(() => _generation++);
    final repository = await ref.watch(playerProfileRepositoryProvider.future);
    final page = await repository.loadHistory(
      query.profileId,
      filter: query.filter,
    );
    return MatchHistoryState(
      entries: page.entries,
      nextCursor: page.nextCursor,
    );
  }

  /// Drops all loaded pages. A new first page never shares an old cursor.
  void refresh() {
    _generation++;
    ref.invalidateSelf();
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
