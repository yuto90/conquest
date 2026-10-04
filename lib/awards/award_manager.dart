import 'package:flutter/foundation.dart';

import 'award_progress.dart';
import 'award_storage.dart';

enum AwardSavePhase { saving, unsaved, saved }

class AwardMatchState {
  AwardMatchState(this.profileId);
  final Future<String> Function() profileId;
  Set<String>? eligible;
  AwardMatch? match;
  AwardEvaluation? evaluation;
  AwardSavePhase phase = AwardSavePhase.saving;
  Object? error;
}

/// A single writer owns the whole award snapshot, independently of XP storage.
class AwardManager extends ChangeNotifier {
  AwardManager(this.storage);
  final AwardStorage storage;
  AwardProfile? _profile;
  String? _profileId;
  Future<void> _queue = Future.value();
  final Map<String, AwardMatchState> _matches = {};
  Object? error;
  bool dirty = false;
  bool _disposed = false;

  AwardProfile? get profile => _profile;
  AwardMatchState? stateFor(String? id) => _matches[id];

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _queue.then((_) async {
      try {
        await action();
        error = null;
      } catch (failure) {
        error = failure;
      }
      _changed();
    });
    _queue = operation;
    return operation;
  }

  Future<void> _load(String profileId) async {
    if (_profile != null) {
      if (_profileId != profileId) throw StateError('Award profile changed');
      return;
    }
    final raw = await storage.read();
    _profile = raw == null
        ? AwardProfile()
        : AwardProfileCodec.decode(raw, profileId);
    _profileId = profileId;
  }

  Future<void> initialize(String profileId) => _enqueue(() => _load(profileId));

  void begin(String id, Future<String> Function() profileId) {
    if (_matches.containsKey(id)) return;
    final entry = AwardMatchState(profileId);
    _matches[id] = entry;
    _enqueue(() async {
      await _load(await entry.profileId());
      entry.eligible = Set.unmodifiable(_profile!.eligibleAssignments);
    });
  }

  Future<void> complete(AwardMatch match) {
    final entry = _matches[match.id]!;
    if (entry.phase == AwardSavePhase.saved) return Future.value();
    entry.match ??= match;
    entry.phase = AwardSavePhase.saving;
    _changed();
    return _enqueue(() => _apply(entry));
  }

  void abandon(String id) {
    _enqueue(() async {
      _matches.remove(id);
    });
  }

  Future<void> _apply(AwardMatchState entry) async {
    try {
      await _load(await entry.profileId());
      // Starts blocked by a failed read share the last known profile. Never
      // unlock a later tier retroactively using another pending completion.
      for (final pending in _matches.values) {
        pending.eligible ??= Set.unmodifiable(_profile!.eligibleAssignments);
      }
      if (entry.evaluation == null) {
        entry.evaluation = AwardEvaluator.evaluate(
          _profile!,
          entry.match!,
          entry.eligible!,
        );
        _profile = entry.evaluation!.profile;
        dirty = true;
      }
      await storage.write(AwardProfileCodec.encode(_profileId!, _profile!));
      dirty = false;
      for (final pending in _matches.values) {
        if (pending.evaluation != null) {
          pending.phase = AwardSavePhase.saved;
          pending.error = null;
        }
      }
      final saved = _matches.entries
          .where((e) => e.value.phase == AwardSavePhase.saved)
          .toList();
      for (final old in saved.take((saved.length - 8).clamp(0, saved.length))) {
        if (old.value != entry) _matches.remove(old.key);
      }
    } catch (failure) {
      entry.phase = AwardSavePhase.unsaved;
      entry.error = failure;
      rethrow;
    }
  }

  Future<void> retry([String? id]) => _enqueue(() async {
    for (final entry in _matches.entries.toList()) {
      if (entry.value.match != null &&
          entry.value.phase == AwardSavePhase.unsaved &&
          (id == null || id == entry.key)) {
        entry.value.phase = AwardSavePhase.saving;
        _changed();
        await _apply(entry.value);
      }
    }
  });

  Future<void> drain() async {
    Future<void> current;
    do {
      current = _queue;
      await current;
    } while (current != _queue);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
