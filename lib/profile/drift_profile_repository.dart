import 'package:drift/drift.dart';

import '../game/game_state.dart';
import 'drift_profile_store.dart';
import 'match_contracts.dart';
import 'profile_repository.dart';

final class DriftPlayerProfileRepository implements PlayerProfileRepository {
  DriftPlayerProfileRepository(this.store);

  final DriftProfileStore store;

  @override
  Stream<PlayerProfile> watchProfile(String profileId) {
    requireUuid(profileId, 'profileId');
    return store.watchProfile(profileId);
  }

  @override
  Future<PlayerProfile> editProfile(String profileId, ProfileEdit edit) {
    requireUuid(profileId, 'profileId');
    return store.editProfile(profileId, edit);
  }

  @override
  Stream<int> watchTotalXp(String profileId) {
    requireUuid(profileId, 'profileId');
    return store.watchTotalXp(profileId);
  }

  static const _totals = '''
    COUNT(CASE WHEN outcome = 'win' THEN 1 END) AS wins,
    COUNT(CASE WHEN outcome = 'loss' THEN 1 END) AS losses,
    COUNT(CASE WHEN outcome = 'draw' THEN 1 END) AS draws,
    COUNT(CASE WHEN status = 'abandoned' THEN 1 END) AS abandoned,
    COUNT(CASE WHEN status = 'interrupted' THEN 1 END) AS interrupted
  ''';

  static String _metricTotal(String column) =>
      '''
    CASE WHEN COUNT(CASE WHEN status = 'completed' THEN 1 END)
      = COUNT(CASE WHEN status = 'completed' THEN $column END)
    THEN COALESCE(SUM(CASE WHEN status = 'completed' THEN $column END), 0)
    ELSE NULL END AS $column
  ''';

  static final _aggregate = [
    _totals,
    for (final column in [
      'elapsed_ms',
      'dispatch_count',
      'forces_sent',
      'captures',
    ])
      _metricTotal(column),
  ].join(',');

  ({String sql, List<Variable> variables}) _scope(
    String profileId,
    MatchHistoryFilter filter,
  ) {
    requireUuid(profileId, 'profileId');
    final conditions = [
      'm.profile_id = ?',
      'm.session_kind = ?',
      "m.status != 'in_progress'",
    ];
    final variables = <Variable>[
      Variable(profileId),
      Variable(filter.sessionKind.storageKey),
    ];
    if (filter.difficulty != null) {
      conditions.add('m.difficulty = ?');
      variables.add(Variable(difficultyStorageKey(filter.difficulty!)));
    }
    if (filter.islandCount != null) {
      conditions.add('m.island_count = ?');
      variables.add(Variable(filter.islandCount!));
    }
    if (filter.status != null) {
      conditions.add('m.status = ?');
      variables.add(Variable(filter.status!.storageKey));
    }
    if (filter.outcome != null) {
      conditions.add('m.outcome = ?');
      variables.add(Variable(filter.outcome!.storageKey));
    }
    return (sql: conditions.join(' AND '), variables: variables);
  }

  MatchStatistics _statistics(QueryRow row) => MatchStatistics(
    wins: row.read<int>('wins'),
    losses: row.read<int>('losses'),
    draws: row.read<int>('draws'),
    abandoned: row.read<int>('abandoned'),
    interrupted: row.read<int>('interrupted'),
    elapsedMs: row.readNullable<int>('elapsed_ms'),
    dispatchCount: row.readNullable<int>('dispatch_count'),
    forcesSent: row.readNullable<int>('forces_sent'),
    captures: row.readNullable<int>('captures'),
  );

  @override
  Stream<MatchStatistics> watchStatistics(
    String profileId, {
    MatchHistoryFilter? filter,
  }) {
    final scope = _scope(profileId, filter ?? MatchHistoryFilter());
    return store.database
        .customSelect(
          'SELECT $_aggregate FROM match_records m WHERE ${scope.sql}',
          variables: scope.variables,
          readsFrom: {store.database.matchRecords},
        )
        .watchSingle()
        .map(_statistics);
  }

  @override
  Stream<Map<CpuDifficulty, MatchStatistics>> watchDifficultyStatistics(
    String profileId,
  ) {
    final scope = _scope(profileId, MatchHistoryFilter());
    return store.database
        .customSelect(
          'SELECT difficulty, $_aggregate FROM match_records m '
          'WHERE ${scope.sql} GROUP BY difficulty',
          variables: scope.variables,
          readsFrom: {store.database.matchRecords},
        )
        .watch()
        .map(
          (rows) => Map.unmodifiable({
            for (final difficulty in CpuDifficulty.values)
              difficulty: MatchStatistics(),
            for (final row in rows)
              CpuDifficulty.values.singleWhere(
                (d) =>
                    difficultyStorageKey(d) == row.read<String>('difficulty'),
              ): _statistics(
                row,
              ),
          }),
        );
  }

  @override
  Future<int?> fastestVictoryMs(
    String profileId, {
    required CpuDifficulty difficulty,
    required int islandCount,
  }) async {
    final scope = _scope(
      profileId,
      MatchHistoryFilter(
        difficulty: difficulty,
        islandCount: islandCount,
        outcome: MatchOutcome.win,
      ),
    );
    return (await store.database
            .customSelect(
              'SELECT MIN(elapsed_ms) AS fastest FROM match_records m WHERE ${scope.sql}',
              variables: scope.variables,
              readsFrom: {store.database.matchRecords},
            )
            .getSingle())
        .readNullable<int>('fastest');
  }

  static const _entryColumns = '''
    m.*, COALESCE((SELECT SUM(x.amount) FROM xp_entries x
      WHERE x.match_id = m.match_id AND x.profile_id = m.profile_id), 0)
      AS history_xp
  ''';
  static const _order = 'm.started_at_utc DESC, m.match_id DESC';

  Selectable<QueryRow> _historyQuery(
    String profileId,
    MatchHistoryFilter filter,
    MatchHistoryCursor? before,
    int limit,
  ) {
    before?.requireScope(profileId, filter);
    final scope = _scope(profileId, filter);
    final cursor = before == null
        ? ''
        : ' AND (m.started_at_utc, m.match_id) < (?, ?)';
    return store.database.customSelect(
      'SELECT $_entryColumns FROM match_records m WHERE ${scope.sql}$cursor '
      'ORDER BY $_order LIMIT ?',
      variables: [
        ...scope.variables,
        if (before != null) ...[
          Variable(before.startedAtUtc.millisecondsSinceEpoch),
          Variable(before.matchId),
        ],
        Variable(limit),
      ],
      readsFrom: {store.database.matchRecords, store.database.xpEntries},
    );
  }

  MatchHistoryEntry _entry(QueryRow row) => MatchHistoryEntry(
    record: DriftProfileStore.decodeRecord(
      store.database.matchRecords.map(row.data),
    ),
    xpAwarded: row.read<int>('history_xp'),
  );

  @override
  Future<MatchHistoryPage> loadHistory(
    String profileId, {
    MatchHistoryFilter? filter,
    MatchHistoryCursor? before,
    int limit = 20,
  }) async {
    final effectiveFilter = filter ?? MatchHistoryFilter();
    // One extra row distinguishes a full final page from a page with a successor.
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    final rows = await _historyQuery(
      profileId,
      effectiveFilter,
      before,
      limit + 1,
    ).get();
    final entries = rows.take(limit).map(_entry).toList();
    final last = entries.isEmpty ? null : entries.last.record.start;
    return MatchHistoryPage(
      entries: entries,
      nextCursor: rows.length <= limit || last == null
          ? null
          : MatchHistoryCursor(
              profileId: profileId,
              filter: effectiveFilter,
              startedAtUtc: last.startedAtUtc,
              matchId: last.matchId,
            ),
    );
  }

  @override
  Stream<List<MatchHistoryEntry>> watchRecentMatches(String profileId) =>
      _historyQuery(
        profileId,
        MatchHistoryFilter(),
        null,
        5,
      ).watch().map((rows) => List.unmodifiable(rows.map(_entry)));

  @override
  Future<MatchHistoryEntry?> loadMatch(String profileId, String matchId) async {
    requireUuid(matchId, 'matchId');
    final scope = _scope(profileId, MatchHistoryFilter());
    final row = await store.database
        .customSelect(
          'SELECT $_entryColumns FROM match_records m '
          'WHERE ${scope.sql} AND m.match_id = ?',
          variables: [...scope.variables, Variable(matchId)],
          readsFrom: {store.database.matchRecords, store.database.xpEntries},
        )
        .getSingleOrNull();
    return row == null ? null : _entry(row);
  }
}
