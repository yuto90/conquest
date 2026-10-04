import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../profile/match_contracts.dart';
import 'award_catalog.dart';
import 'award_progress.dart';

abstract interface class AwardStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesAwardStorage implements AwardStorage {
  static const key = 'conquest.awards.profile.v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final value = preferences.get(key);
    if (value != null && value is! String) {
      throw const FormatException('Invalid award storage type');
    }
    return value as String?;
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, value)) {
      throw StateError('Award storage write failed');
    }
  }
}

abstract final class AwardProfileCodec {
  static String encode(String profileId, AwardProfile profile) => jsonEncode({
    'schemaVersion': 1,
    'catalogVersion': AwardCatalog.version,
    'profileId': profileId,
    'totals': _metrics(profile.totals),
    'ribbons': profile.ribbons,
    'completed': {
      for (final entry in profile.completed.entries)
        entry.key: {
          'matchId': entry.value.matchId,
          'atUtc': entry.value.completedAtUtc.toUtc().toIso8601String(),
        },
    },
    'singleMatchProgress': {
      for (final entry in profile.singleMatchProgress.entries)
        entry.key: _metrics(entry.value),
    },
    'appliedMatches': profile.appliedMatches.toList()..sort(),
  });

  static Map<String, int> _metrics(Map<AwardMetric, int> values) => {
    for (final entry in values.entries) entry.key.name: entry.value,
  };

  static AwardProfile decode(String raw, String profileId) {
    final root = _map(jsonDecode(raw));
    if (root['schemaVersion'] != 1 ||
        root['catalogVersion'] != AwardCatalog.version ||
        root['profileId'] != profileId) {
      throw const FormatException('Unknown award schema, catalog or profile');
    }
    final totals = _readMetrics(root['totals']);
    if (totals.containsKey(AwardMetric.elapsedMs)) {
      throw const FormatException(
        'Elapsed time is not a cumulative award metric',
      );
    }
    final ribbons = _counts(
      root['ribbons'],
      AwardCatalog.ribbons.map((r) => r.id).toSet(),
    );
    if ((totals[AwardMetric.captureRibbons] ?? 0) !=
        (ribbons['capture'] ?? 0)) {
      throw const FormatException('Inconsistent capture ribbon count');
    }
    final ids = root['appliedMatches'];
    if (ids is! List || ids.any((id) => id is! String)) {
      throw const FormatException('Invalid applied match IDs');
    }
    final applied = ids.cast<String>().toSet();
    if (ids.length != applied.length)
      throw const FormatException('Duplicate match IDs');
    for (final id in applied) {
      requireUuid(id, 'matchId');
    }
    final definitions = {for (final a in AwardCatalog.assignments) a.id: a};
    final completed = <String, AssignmentCompletion>{};
    for (final entry in _map(root['completed']).entries) {
      if (!definitions.containsKey(entry.key))
        throw const FormatException('Unknown assignment');
      final record = _map(entry.value);
      final matchId = record['matchId'];
      final at = record['atUtc'];
      if (matchId is! String || !applied.contains(matchId) || at is! String) {
        throw const FormatException('Invalid assignment completion');
      }
      final date = DateTime.parse(at);
      if (!date.isUtc) throw const FormatException('Completion must be UTC');
      completed[entry.key] = AssignmentCompletion(matchId, date);
    }
    for (final id in completed.keys) {
      final prerequisite = definitions[id]!.prerequisite;
      if (prerequisite != null && !completed.containsKey(prerequisite)) {
        throw const FormatException('Missing completed prerequisite');
      }
    }
    final progress = <String, Map<AwardMetric, int>>{};
    for (final entry in _map(root['singleMatchProgress']).entries) {
      if (definitions[entry.key]?.singleMatch != true) {
        throw const FormatException('Unknown single-match assignment');
      }
      progress[entry.key] = _readMetrics(entry.value);
    }
    return AwardProfile(
      totals: totals,
      ribbons: ribbons,
      completed: completed,
      singleMatchProgress: progress,
      appliedMatches: applied,
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>)
      throw const FormatException('Expected award object');
    return value;
  }

  static Map<String, int> _counts(Object? value, Set<String> known) => {
    for (final entry in _map(value).entries) entry.key: _count(entry, known),
  };

  static int _count(MapEntry<String, dynamic> entry, Set<String> known) {
    if (!known.contains(entry.key) ||
        entry.value is! int ||
        (entry.value as int) < 0) {
      throw const FormatException('Invalid award counter');
    }
    return entry.value as int;
  }

  static Map<AwardMetric, int> _readMetrics(Object? value) => {
    for (final entry in _counts(
      value,
      AwardMetric.values.map((m) => m.name).toSet(),
    ).entries)
      AwardMetric.values.byName(entry.key): entry.value,
  };
}
