import 'dart:async';

import 'package:characters/characters.dart';
import 'package:drift/drift.dart';

import '../game/game_state.dart';
import '../rank_progression.dart';
import 'legacy_xp.dart';
import 'match_contracts.dart';
import 'match_identity.dart';
import 'profile_database.dart' as db;
import 'profile_repository.dart';
import 'storage_lease.dart';

enum StorageFaultPoint { afterProfile, afterLegacyEntry, afterMatch, afterXp }

typedef StorageFaultHook = Future<void> Function(StorageFaultPoint point);

final class ProfileAvatars {
  static const assets = <String, String>{
    'island_01': 'assets/islands/ally/island_01.png',
    'island_02': 'assets/islands/ally/island_02.png',
    'island_03': 'assets/islands/ally/island_03.png',
    'island_04': 'assets/islands/ally/island_04.png',
  };
  static const defaultKey = 'island_01';
}

final class DriftProfileStore implements MatchCompletionService {
  DriftProfileStore({
    required this.database,
    required this.executionId,
    required this.lease,
    UuidGenerator? ids,
    UtcClock? clock,
    this.faultHook,
  }) : ids = ids ?? SecureUuidGenerator(),
       clock = clock ?? SystemUtcClock() {
    requireUuid(executionId, 'executionId');
  }

  static const legacyMarker = 'legacy_xp_v1';
  static const activeProfileKey = 'active_profile_id';
  static const rewardVersion = '1';

  final db.ProfileDatabase database;
  final String executionId;
  final StorageLease lease;
  final UuidGenerator ids;
  final UtcClock clock;
  final StorageFaultHook? faultHook;
  Future<void> _queue = Future<void>.value();
  bool _closing = false;
  bool _accepting = true;
  Future<void>? _closeFuture;

  void requireOwnership() {
    if (_closing || !lease.isHeld) {
      throw const StorageUnavailable('Writer ownership was released');
    }
  }

  Future<T> _write<T>(Future<T> Function() action) {
    if (!_accepting) throw const StorageUnavailable('Storage is closing');
    requireOwnership();
    final operation = _queue.then((_) {
      requireOwnership();
      return database.transaction(action);
    });
    _queue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> _fault(StorageFaultPoint point) async {
    await faultHook?.call(point);
  }

  Future<String?> _meta(String key) async => (await (database.select(
    database.storageMeta,
  )..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _putMeta(String key, String value) => database
      .into(database.storageMeta)
      .insertOnConflictUpdate(
        db.StorageMetaCompanion.insert(key: key, value: value),
      );

  /// Activated only when #129 replaces the legacy writer.
  Future<PlayerProfile> initialize(LegacyXpSource source) => _write(() async {
    final marker = await _meta(legacyMarker);
    if (marker != null) {
      if (marker != 'done') throw StateError('Unknown legacy migration marker');
      final profileId = await _meta(activeProfileKey);
      if (profileId == null)
        throw StateError('Missing migrated profile identity');
      final legacy = await (database.select(
        database.xpEntries,
      )..where((e) => e.entryId.equals('legacy:$profileId'))).getSingleOrNull();
      if (legacy == null) throw StateError('Missing legacy migration ledger');
      await _putMeta('execution_id', executionId);
      return loadProfile(profileId);
    }
    final raw = await source.read();
    if (raw != null && (raw is! int || raw < 0)) {
      throw const StorageUnavailable(
        'Invalid legacy XP; migration not committed',
      );
    }
    final amount = raw == null ? 0 : raw as int;
    if (await _meta(activeProfileKey) != null ||
        (await database.select(database.profiles).get()).isNotEmpty ||
        (await database.select(database.xpEntries).get()).isNotEmpty) {
      throw StateError(
        'Unmarked profile data; refusing a second legacy import',
      );
    }
    final profileId = ids.next();
    requireUuid(profileId, 'profileId');
    final now = storageUtc(clock.now()).millisecondsSinceEpoch;
    await database
        .into(database.profiles)
        .insert(
          db.ProfilesCompanion.insert(
            profileId: profileId,
            avatarKey: ProfileAvatars.defaultKey,
            createdAtUtc: now,
            updatedAtUtc: now,
            statsStartedAtUtc: now,
          ),
        );
    await _fault(StorageFaultPoint.afterProfile);
    await database
        .into(database.xpEntries)
        .insert(
          db.XpEntriesCompanion.insert(
            entryId: 'legacy:$profileId',
            profileId: profileId,
            reason: 'legacy_import',
            amount: amount,
            rewardVersion: 'legacy_v1',
            totalXpBefore: 0,
            totalXpAfter: amount,
            createdAtUtc: now,
          ),
        );
    await _fault(StorageFaultPoint.afterLegacyEntry);
    await _putMeta(activeProfileKey, profileId);
    await _putMeta(legacyMarker, 'done');
    await _putMeta(
      'legacy_source',
      SharedPreferencesRankProgressStore.storageKey,
    );
    await _putMeta('execution_id', executionId);
    return loadProfile(profileId);
  });

  PlayerProfile _profile(db.Profile row) => PlayerProfile(
    profileId: row.profileId,
    displayName: row.displayName,
    avatarKey: row.avatarKey,
    createdAtUtc: _utc(row.createdAtUtc),
    updatedAtUtc: _utc(row.updatedAtUtc),
    statsStartedAtUtc: _utc(row.statsStartedAtUtc),
  );

  Future<PlayerProfile> loadProfile(String profileId) async => _profile(
    await (database.select(
      database.profiles,
    )..where((p) => p.profileId.equals(profileId))).getSingle(),
  );

  Stream<PlayerProfile> watchProfile(String profileId) => (database.select(
    database.profiles,
  )..where((p) => p.profileId.equals(profileId))).watchSingle().map(_profile);

  Future<PlayerProfile> editProfile(String profileId, ProfileEdit edit) =>
      _write(() async {
        final name = edit.displayName;
        if (!ProfileAvatars.assets.containsKey(edit.avatarKey) ||
            (name != null &&
                (name.characters.isEmpty ||
                    name.characters.length > 20 ||
                    RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(name)))) {
          throw ArgumentError('Invalid profile edit');
        }
        final changed =
            await (database.update(
              database.profiles,
            )..where((p) => p.profileId.equals(profileId))).write(
              db.ProfilesCompanion(
                displayName: Value(name),
                avatarKey: Value(edit.avatarKey),
                updatedAtUtc: Value(
                  storageUtc(clock.now()).millisecondsSinceEpoch,
                ),
              ),
            );
        if (changed != 1) throw StateError('Profile not found');
        return loadProfile(profileId);
      });

  Selectable<QueryRow> _xpQuery(String profileId) => database.customSelect(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM xp_entries WHERE profile_id = ?',
    variables: [Variable(profileId)],
    readsFrom: {database.xpEntries},
  );

  Future<int> totalXp(String profileId) async =>
      (await _xpQuery(profileId).getSingle()).read<int>('total');

  Stream<int> watchTotalXp(String profileId) =>
      _xpQuery(profileId).watchSingle().map((r) => r.read<int>('total'));

  Future<db.MatchRecord?> _row(String matchId) => (database.select(
    database.matchRecords,
  )..where((m) => m.matchId.equals(matchId))).getSingleOrNull();

  Future<MatchRecord?> loadRecord(String matchId) async {
    final row = await _row(matchId);
    return row == null ? null : decodeRecord(row);
  }

  @override
  Future<void> recordStart(MatchStartContext start) => _write(() async {
    if (start.executionId != executionId)
      throw const StorageUnavailable('Foreign execution');
    final record = MatchRecord(start: start, status: MatchStatus.inProgress);
    final existing = await _row(start.matchId);
    if (existing != null) {
      if (decodeRecord(existing).start != start)
        throw MatchCommitConflict(start.matchId);
      return;
    }
    await database.into(database.matchRecords).insert(_encode(record));
  });

  @override
  Future<MatchCommitReceipt> complete(MatchCompletion completion) =>
      _write(() => _finalize(completion.record));

  @override
  Future<MatchCommitReceipt> abandon(MatchRecord abandoned) => _write(() {
    if (abandoned.status != MatchStatus.abandoned)
      throw ArgumentError('Expected abandoned record');
    return _finalize(abandoned);
  });

  Future<MatchCommitReceipt> _finalize(
    MatchRecord record, {
    bool recovery = false,
  }) async {
    if (!recovery && record.start.executionId != executionId) {
      throw const StorageUnavailable('Foreign execution');
    }
    final row = await _row(record.start.matchId);
    if (row == null || decodeRecord(row).start != record.start) {
      throw MatchCommitConflict(record.start.matchId);
    }
    final existing = decodeRecord(row);
    if (existing.isTerminal) {
      requireSameFinalization(existing, record);
      return _receipt(row);
    }
    final before = await totalXp(record.start.profileId);
    final award = record.outcome == MatchOutcome.win
        ? victoryXpFor(record.start.configuration.cpuDifficulty)
        : 0;
    final receipt = MatchCommitReceipt(
      record: record,
      xpAwarded: award,
      totalXpBefore: before,
      totalXpAfter: before + award,
      rewardVersion: rewardVersion,
    );
    await (database.update(database.matchRecords)
          ..where((m) => m.matchId.equals(record.start.matchId)))
        .write(_encode(record, receipt: receipt));
    await _fault(StorageFaultPoint.afterMatch);
    if (award > 0) {
      await database
          .into(database.xpEntries)
          .insert(
            db.XpEntriesCompanion.insert(
              entryId: 'victory:${record.start.matchId}',
              profileId: record.start.profileId,
              matchId: Value(record.start.matchId),
              reason: 'match_victory',
              amount: award,
              rewardVersion: rewardVersion,
              totalXpBefore: before,
              totalXpAfter: before + award,
              createdAtUtc: record.endedAtUtc!.millisecondsSinceEpoch,
            ),
          );
    }
    await _fault(StorageFaultPoint.afterXp);
    return receipt;
  }

  @override
  Future<void> recoverInterrupted({
    required String profileId,
    required String executionId,
    required DateTime recoveredAtUtc,
  }) => _write(() async {
    requireUuid(executionId, 'executionId');
    if (executionId == this.executionId)
      throw const StorageUnavailable('Cannot recover live execution');
    final rows =
        await (database.select(database.matchRecords)..where(
              (m) =>
                  m.profileId.equals(profileId) &
                  m.executionId.equals(executionId) &
                  m.status.equals('in_progress'),
            ))
            .get();
    for (final row in rows) {
      await _finalize(
        MatchRecord(
          start: decodeRecord(row).start,
          status: MatchStatus.interrupted,
          recoveredAtUtc: recoveredAtUtc,
        ),
        recovery: true,
      );
    }
  });

  Future<void> close() {
    _accepting = false;
    return _closeFuture ??= _close();
  }

  Future<void> _close() async {
    await _queue;
    _closing = true;
    try {
      await database.close();
    } finally {
      await lease.release();
    }
  }

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static CpuDifficulty _difficulty(String key) =>
      CpuDifficulty.values.singleWhere((d) => difficultyStorageKey(d) == key);

  static MatchRecord decodeRecord(db.MatchRecord row) => MatchRecord(
    start: MatchStartContext(
      matchId: row.matchId,
      profileId: row.profileId,
      executionId: row.executionId,
      configuration: GameConfiguration(
        totalIslandCount: row.islandCount,
        gameMode: GameMode.playerVsCpu,
        cpuDifficulty: _difficulty(row.difficulty),
        playerCpuDifficulty: _difficulty(row.playerCpuDifficulty),
      ),
      sessionKind: SessionKind.values.singleWhere(
        (k) => k.storageKey == row.sessionKind,
      ),
      origin: SessionOrigin.values.singleWhere((o) => o.name == row.origin),
      startedAtUtc: _utc(row.startedAtUtc),
      appVersion: row.appVersion,
      rulesVersion: row.rulesVersion,
      metricsVersion: row.metricsVersion,
    ),
    status: MatchStatus.values.singleWhere((s) => s.storageKey == row.status),
    outcome: row.outcome == null
        ? null
        : MatchOutcome.values.singleWhere((o) => o.storageKey == row.outcome),
    endedAtUtc: row.endedAtUtc == null ? null : _utc(row.endedAtUtc!),
    recoveredAtUtc: row.recoveredAtUtc == null
        ? null
        : _utc(row.recoveredAtUtc!),
    metrics: MatchMetrics(
      elapsedMs: row.elapsedMs,
      dispatchCount: row.dispatchCount,
      forcesSent: row.forcesSent,
      captures: row.captures,
    ),
  );

  static MatchCommitReceipt _receipt(db.MatchRecord row) => MatchCommitReceipt(
    record: decodeRecord(row),
    xpAwarded: row.receiptXp!,
    totalXpBefore: row.receiptBefore!,
    totalXpAfter: row.receiptAfter!,
    rewardVersion: row.receiptRewardVersion!,
  );

  static db.MatchRecordsCompanion _encode(
    MatchRecord record, {
    MatchCommitReceipt? receipt,
  }) {
    final start = record.start;
    return db.MatchRecordsCompanion.insert(
      matchId: start.matchId,
      profileId: start.profileId,
      executionId: start.executionId,
      sessionKind: start.sessionKind.storageKey,
      origin: start.origin.name,
      gameMode: gameModeStorageKey(start.configuration.gameMode),
      difficulty: difficultyStorageKey(start.configuration.cpuDifficulty),
      playerCpuDifficulty: difficultyStorageKey(
        start.configuration.playerCpuDifficulty,
      ),
      islandCount: start.configuration.totalIslandCount,
      status: record.status.storageKey,
      outcome: Value(record.outcome?.storageKey),
      startedAtUtc: start.startedAtUtc.millisecondsSinceEpoch,
      endedAtUtc: Value(record.endedAtUtc?.millisecondsSinceEpoch),
      recoveredAtUtc: Value(record.recoveredAtUtc?.millisecondsSinceEpoch),
      elapsedMs: Value(record.metrics.elapsedMs),
      dispatchCount: Value(record.metrics.dispatchCount),
      forcesSent: Value(record.metrics.forcesSent),
      captures: Value(record.metrics.captures),
      appVersion: start.appVersion,
      rulesVersion: start.rulesVersion,
      metricsVersion: start.metricsVersion,
      receiptXp: Value(receipt?.xpAwarded),
      receiptBefore: Value(receipt?.totalXpBefore),
      receiptAfter: Value(receipt?.totalXpAfter),
      receiptRewardVersion: Value(receipt?.rewardVersion),
    );
  }
}
