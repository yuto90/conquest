import 'package:flutter/foundation.dart';

import 'award_progress.dart';

enum AwardSavePhase { saving, unsaved, saved }

class AwardMatchState {
  AwardEvaluation? evaluation;
  AwardSavePhase phase = AwardSavePhase.saving;
  Object? error;
}

/// Presentation cache only. MatchPersistence owns the durable commit and retry.
class AwardManager extends ChangeNotifier {
  AwardProfile? _profile;
  final Map<String, AwardMatchState> _matches = {};
  Object? error;
  bool _disposed = false;
  AwardProfile? get profile => _profile;
  bool get dirty =>
      _matches.values.any((s) => s.phase == AwardSavePhase.unsaved);
  AwardMatchState? stateFor(String? id) => _matches[id];

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void load(AwardProfile profile) {
    _profile = profile;
    error = null;
    _changed();
  }

  void begin(String id) => _matches.putIfAbsent(id, AwardMatchState.new);

  void preview(String id, AwardMatch match, AwardEligibility eligibility) {
    _matches[id]!.evaluation ??= AwardEvaluator.evaluate(
      _profile!,
      match,
      eligibility.assignments,
    );
  }

  void phase(String id, AwardSavePhase phase, [Object? failure]) {
    final state = _matches[id];
    if (state == null) return;
    state.phase = phase;
    state.error = failure;
    error = failure;
    _changed();
  }

  void committed(String id, AwardEvaluation evaluation, AwardProfile profile) {
    _matches[id]!.evaluation = evaluation;
    _profile = profile;
    phase(id, AwardSavePhase.saved);
  }

  void forget(String id) => _matches.remove(id);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
