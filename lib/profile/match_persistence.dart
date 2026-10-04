import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../awards/award_manager.dart';
import '../awards/award_progress.dart';
import '../game/game_state.dart';
import '../game/match_summary.dart';
import 'drift_profile_store.dart';
import 'drift_profile_repository.dart';
import 'legacy_xp.dart';
import 'match_contracts.dart';
import 'match_identity.dart';
import 'profile_repository.dart';
import 'profile_storage.dart';
import 'storage_lease.dart';

abstract interface class ProfileBackend implements MatchCompletionService {
  PlayerProfileRepository get repository;
  Future<PlayerProfile> initializeAndRecover(LegacyXpSource source);
  Stream<int> watchTotalXp(String profileId);
  Future<void> close();
}

final class DurableProfileBackend implements ProfileBackend {
  DurableProfileBackend(this.storage);
  final ProfileStorage storage;
  DriftProfileStore get store => storage.store;
  @override
  late final PlayerProfileRepository repository = DriftPlayerProfileRepository(
    store,
  );

  static Future<ProfileBackend> open(String executionId) async =>
      DurableProfileBackend(
        await ProfileStorage.open(executionId: executionId),
      );

  @override
  Future<PlayerProfile> initializeAndRecover(LegacyXpSource source) =>
      store.initializeAndRecover(source);
  @override
  Stream<int> watchTotalXp(String profileId) => store.watchTotalXp(profileId);
  @override
  Future<void> recordStart(MatchStartContext start) => store.recordStart(start);
  @override
  Future<MatchCommitReceipt> complete(MatchCompletion completion) =>
      store.complete(completion);
  @override
  Future<MatchCommitReceipt> abandon(MatchRecord abandoned) =>
      store.abandon(abandoned);
  @override
  Future<void> recoverInterrupted({
    required String profileId,
    required String executionId,
    required DateTime recoveredAtUtc,
  }) => store.recoverInterrupted(
    profileId: profileId,
    executionId: executionId,
    recoveredAtUtc: recoveredAtUtc,
  );
  @override
  Future<void> close() => storage.close();
}

enum MatchSavePhase { saving, unsaved, saved }

final class MatchSaveState {
  const MatchSaveState(this.phase, {this.receipt, this.error});
  final MatchSavePhase phase;
  final MatchCommitReceipt? receipt;
  final Object? error;
}

// Captured before profile initialization may finish. Binding the durable
// profile later never changes the match identity, start or terminal snapshot.
final class _PendingMatch {
  _PendingMatch(this.id, this.configuration, this.startedAt);
  final String id;
  final GameConfiguration configuration;
  final DateTime startedAt;
  MatchStartContext? start;
  GameResult? result;
  MatchSummary? summary;
  DateTime? endedAt;
  bool abandoned = false;
  MatchSaveState save = const MatchSaveState(MatchSavePhase.saving);
  Future<void>? operation;
}

/// One composition-root owner for storage, migration and failed frozen DTOs.
/// It outlives controllers, result routes and viewport ProviderScopes.
final class MatchPersistence extends ChangeNotifier {
  static const savedReceiptLimit = 8;

  MatchPersistence({
    required this.factory,
    required this.openBackend,
    required this.legacyXp,
    this.awards,
  }) {
    awards?.addListener(_changed);
  }

  final AwardManager? awards;

  final MatchContextFactory factory;
  final Future<ProfileBackend> Function(String executionId) openBackend;
  final LegacyXpSource legacyXp;
  ProfileBackend? _backend;
  PlayerProfile? _profile;
  Future<void>? _initializing;
  Future<void> _queue = Future<void>.value();
  final Map<String, _PendingMatch> _matches = {};
  String? _activeMatchId;
  bool _closing = false;
  Future<void>? _closingOperation;
  bool _disposed = false;
  bool checkingOwnership = true;
  Object? initializationError;

  bool get canStart =>
      !checkingOwnership &&
      initializationError is! StorageAlreadyOwned &&
      !_closing;
  PlayerProfile? get profile => _profile;
  ProfileBackend? get backend => _backend;
  Map<String, MatchSaveState> get saves => Map.unmodifiable({
    for (final entry in _matches.entries) entry.key: entry.value.save,
  });
  MatchSaveState? saveFor(String? id) => _matches[id]?.save;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() {
    if (_profile != null) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    checkingOwnership =
        initializationError == null ||
        initializationError is StorageAlreadyOwned;
    _changed();
    try {
      _backend ??= await openBackend(factory.executionId);
      _profile = await _backend!.initializeAndRecover(legacyXp);
      unawaited(awards?.initialize(_profile!.profileId));
      initializationError = null;
    } catch (error) {
      initializationError = error;
      rethrow;
    } finally {
      checkingOwnership = false;
      _changed();
    }
  }

  /// The application uses this for eager initialization without hiding errors.
  Future<void> prepare() async {
    try {
      await initialize();
    } catch (_) {
      /* Exposed through initializationError. */
    }
  }

  String? begin(
    GameConfiguration configuration, {
    SessionOrigin origin = SessionOrigin.gameplay,
  }) {
    if (!isRecordableSession(
      configuration: configuration,
      origin: origin,
      kind: SessionKind.normal,
    ))
      return null;
    if (!canStart) return null;
    final id = factory.ids.next();
    requireUuid(id, 'matchId');
    _activeMatchId = id;
    _matches[id] = _PendingMatch(
      id,
      configuration,
      storageUtc(factory.clock.now()),
    );
    awards?.begin(id, () async {
      await initialize();
      return _profile!.profileId;
    });
    unawaited(_attempt(_matches[id]!));
    return id;
  }

  Future<void> finish(
    String id, {
    required GameResult result,
    required MatchSummary summary,
  }) {
    final match = _matches[id]!;
    if (match.endedAt != null) {
      if (match.abandoned || match.result != result || match.summary != summary)
        throw MatchCommitConflict(id);
      return match.operation ?? Future.value();
    }
    match.result = result;
    match.summary = summary;
    match.endedAt = storageUtc(factory.clock.now());
    unawaited(
      awards?.complete(
        AwardMatch(
          id: id,
          difficulty: match.configuration.cpuDifficulty,
          won: result.winner == Faction.player,
          elapsedMs: result.elapsedMs,
          summary: summary,
          endedAtUtc: match.endedAt!,
        ),
      ),
    );
    return _attempt(match);
  }

  Future<void> abandon(String id, MatchSummary summary) {
    final match = _matches[id]!;
    if (match.endedAt != null) {
      if (!match.abandoned || match.summary != summary)
        throw MatchCommitConflict(id);
      return match.operation ?? Future.value();
    }
    match.abandoned = true;
    awards?.abandon(id);
    match.summary = summary;
    match.endedAt = storageUtc(factory.clock.now());
    return _attempt(match);
  }

  Future<void> _attempt(_PendingMatch match) {
    if (match.save.receipt != null) return Future.value();
    // A completion arriving during a start save is read from the same frozen
    // entry when that serialized operation reaches the finalization boundary.
    if (match.operation != null) return match.operation!;
    match.save = const MatchSaveState(MatchSavePhase.saving);
    _changed();
    final operation = _queue.then((_) async {
      try {
        await initialize();
        match.start ??= MatchStartContext(
          matchId: match.id,
          profileId: _profile!.profileId,
          executionId: factory.executionId,
          configuration: match.configuration,
          sessionKind: SessionKind.normal,
          origin: SessionOrigin.gameplay,
          startedAtUtc: match.startedAt,
          appVersion: factory.appVersion,
          rulesVersion: factory.rulesVersion,
          metricsVersion: factory.metricsVersion,
        );
        await _backend!.recordStart(match.start!);
        MatchCommitReceipt? receipt;
        if (match.endedAt != null) {
          receipt = match.abandoned
              ? await _backend!.abandon(
                  MatchRecord(
                    start: match.start!,
                    status: MatchStatus.abandoned,
                    endedAtUtc: match.endedAt,
                    metrics: MatchMetrics.fromSummary(match.summary!),
                  ),
                )
              : await _backend!.complete(
                  MatchCompletion.fromGame(
                    start: match.start!,
                    result: match.result!,
                    summary: match.summary!,
                    endedAtUtc: match.endedAt!,
                  ),
                );
        }
        match.save = MatchSaveState(MatchSavePhase.saved, receipt: receipt);
      } catch (error) {
        match.save = MatchSaveState(MatchSavePhase.unsaved, error: error);
      }
      match.operation = null;
      _trimSavedReceipts();
      _changed();
    });
    match.operation = operation;
    _queue = operation;
    return operation;
  }

  void _trimSavedReceipts() {
    final saved = _matches.values
        .where((match) => match.save.receipt != null)
        .toList();
    var excess = saved.length - savedReceiptLimit;
    for (final match in saved) {
      if (excess <= 0) break;
      if (match.id == _activeMatchId || match.operation != null) continue;
      _matches.remove(match.id);
      excess--;
    }
  }

  Future<void> retry([String? id]) async {
    final pending = _matches.values
        .where(
          (m) =>
              m.save.phase == MatchSavePhase.unsaved &&
              (id == null || m.id == id),
        )
        .toList();
    if (pending.isEmpty) {
      await prepare();
      return;
    }
    await Future.wait(pending.map(_attempt));
  }

  Future<void> drain() async {
    Future<void> draining;
    do {
      draining = _queue;
      await draining;
    } while (draining != _queue);
    await awards?.drain();
  }

  Future<void> retryAwards([String? id]) async {
    try {
      await initialize();
      await awards?.initialize(_profile!.profileId);
      await awards?.retry(id);
    } catch (_) {
      // The profile and award owners expose errors independently.
    }
  }

  Future<void> close() {
    _closing = true;
    return _closingOperation ??= _close();
  }

  Future<void> _close() async {
    await drain();
    try {
      await _initializing;
    } catch (_) {
      // Initialization already exposes its failure; still release the lease.
    }
    await _backend?.close();
  }

  @override
  void dispose() {
    _disposed = true;
    awards?.removeListener(_changed);
    unawaited(close());
    super.dispose();
  }
}

/// Standalone engine clients have no persistence; main supplies the mandatory
/// durable owner. Tests inject this same boundary, never a legacy XP writer.
final matchPersistenceProvider = Provider<MatchPersistence?>((ref) => null);

final profilePersistenceStateProvider =
    NotifierProvider<ProfilePersistenceState, int>(ProfilePersistenceState.new);

final class ProfilePersistenceState extends Notifier<int> {
  @override
  int build() {
    final persistence = ref.watch(matchPersistenceProvider);
    void changed() => state++;
    persistence?.addListener(changed);
    ref.onDispose(() => persistence?.removeListener(changed));
    return 0;
  }
}
