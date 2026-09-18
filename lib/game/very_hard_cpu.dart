import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'cpu_strategy.dart';
import 'game_rules.dart';
import 'game_state.dart';

export 'cpu_strategy.dart' show VeryHardCpuConfig;

/// The only actions Jev can return for a Very Hard CPU.
enum VeryHardAction { dispatch, wait }

/// A candidate generated locally from a current, legal game state.
///
/// Candidate IDs are opaque to the API consumer: they are valid only for the
/// request that contains them. The server may return an ID but can never
/// invent a source, destination, or force count.
final class VeryHardCandidate {
  const VeryHardCandidate._({
    required this.id,
    required this.faction,
    required this.action,
    this.decision,
    this.sourceIslandId,
    this.destinationIslandId,
    this.sourceForcesBefore,
    this.strength,
    this.travelTimeMs,
  });

  factory VeryHardCandidate.dispatch({
    required String id,
    required Faction faction,
    required CpuDecision decision,
    required int sourceForcesBefore,
    required int travelTimeMs,
  }) {
    return VeryHardCandidate._(
      id: id,
      faction: faction,
      action: VeryHardAction.dispatch,
      decision: decision,
      sourceIslandId: decision.sourceIslandId,
      destinationIslandId: decision.destinationIslandId,
      sourceForcesBefore: sourceForcesBefore,
      strength: decision.strength,
      travelTimeMs: travelTimeMs,
    );
  }

  factory VeryHardCandidate.wait({
    required String id,
    required Faction faction,
  }) {
    return VeryHardCandidate._(
      id: id,
      faction: faction,
      action: VeryHardAction.wait,
    );
  }

  final String id;
  final Faction faction;
  final VeryHardAction action;
  final CpuDecision? decision;
  final int? sourceIslandId;
  final int? destinationIslandId;
  final int? sourceForcesBefore;
  final int? strength;
  final int? travelTimeMs;

  bool get isDispatch => action == VeryHardAction.dispatch;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'action': action.name,
      if (sourceIslandId != null) 'sourceIslandId': sourceIslandId,
      if (destinationIslandId != null)
        'destinationIslandId': destinationIslandId,
      if (sourceForcesBefore != null) 'sourceForcesBefore': sourceForcesBefore,
      if (strength != null) 'strength': strength,
      if (travelTimeMs != null) 'travelTimeMs': travelTimeMs,
    };
  }
}

/// Produces all legal source × destination choices, plus explicit wait.
final class VeryHardCandidateGenerator {
  const VeryHardCandidateGenerator({
    this.rules = const GameRules(),
    this.viewport = GameRules.defaultMapViewport,
  });

  final GameRules rules;
  final IslandMapViewport viewport;

  List<VeryHardCandidate> generate(
    GameState state, {
    required Faction faction,
  }) {
    if (state.phase != GamePhase.playing || faction == Faction.neutral) {
      return const <VeryHardCandidate>[];
    }

    final candidates = <VeryHardCandidate>[];
    final islands = state.islands;
    for (final source in islands) {
      if (source.faction != faction || source.currentForces <= 1) continue;
      final strength = source.currentForces ~/ 2;
      if (strength <= 0) continue;

      for (final destination in islands) {
        if (destination.id == source.id) continue;
        final force = rules.createMovingForce(
          id: 0,
          faction: faction,
          source: source,
          destination: destination,
          strength: strength,
          departureTimeMs: state.elapsedMs,
          viewport: viewport,
        );
        final candidateId = '${faction.name}-c${candidates.length}';
        candidates.add(
          VeryHardCandidate.dispatch(
            id: candidateId,
            faction: faction,
            decision: CpuDecision(
              kind: destination.faction == faction
                  ? CpuDecisionKind.defense
                  : CpuDecisionKind.attack,
              sourceIslandId: source.id,
              destinationIslandId: destination.id,
              strength: strength,
            ),
            sourceForcesBefore: source.currentForces,
            travelTimeMs: force.durationMs,
          ),
        );
      }
    }

    // 12 islands produce at most 12 * 11 dispatches. Keep this assertion
    // close to candidate creation so a future rule change cannot silently
    // exceed the Jev choice cardinality.
    if (candidates.length >= VeryHardCpuConfig.maxCandidatesPerFaction) {
      throw StateError(
        'Very Hard candidate count exceeded ${VeryHardCpuConfig.maxCandidatesPerFaction - 1}',
      );
    }
    candidates.add(
      VeryHardCandidate.wait(id: '${faction.name}-wait', faction: faction),
    );
    return List<VeryHardCandidate>.unmodifiable(candidates);
  }
}

final class VeryHardDecisionSubject {
  const VeryHardDecisionSubject({
    required this.faction,
    required this.candidates,
  });

  final Faction faction;
  final List<VeryHardCandidate> candidates;

  Map<String, Object?> toJson() => <String, Object?>{
    'faction': faction.name,
    'candidates': [for (final candidate in candidates) candidate.toJson()],
  };
}

/// JSON-safe view of all state information Jev needs for candidate comparison.
final class VeryHardBoardSnapshot {
  const VeryHardBoardSnapshot({
    required this.elapsedMs,
    required this.islands,
    required this.movingForces,
  });

  final int elapsedMs;
  final List<Map<String, Object?>> islands;
  final List<Map<String, Object?>> movingForces;

  factory VeryHardBoardSnapshot.fromState(GameState state) {
    return VeryHardBoardSnapshot(
      elapsedMs: state.elapsedMs,
      islands: [
        for (final island in state.islands)
          <String, Object?>{
            'id': island.id,
            'x': island.x,
            'y': island.y,
            'size': island.size.name,
            'faction': island.faction.name,
            'currentForces': island.currentForces,
            'durability': island.durability,
            'capacity': island.capacity,
          },
      ],
      movingForces: [
        for (final force in state.movingForces)
          <String, Object?>{
            'faction': force.faction.name,
            'sourceIslandId': force.sourceIslandId,
            'destinationIslandId': force.destinationIslandId,
            'strength': force.strength,
            'remainingMs': math.max(0, force.arrivalTimeMs - state.elapsedMs),
          },
      ],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'elapsedMs': elapsedMs,
    'islands': islands,
    'movingForces': movingForces,
  };
}

/// A request shared by the Flutter client, test doubles, and Vercel Function.
final class VeryHardDecisionRequest {
  VeryHardDecisionRequest({
    required this.matchId,
    required this.requestId,
    required this.elapsedMs,
    required this.board,
    required Iterable<VeryHardDecisionSubject> subjects,
  }) : subjects = List<VeryHardDecisionSubject>.unmodifiable(subjects) {
    if (this.subjects.isEmpty ||
        this.subjects.length > VeryHardCpuConfig.maxSubjects) {
      throw ArgumentError.value(
        this.subjects.length,
        'subjects',
        'must contain one or two factions',
      );
    }
    if (this.subjects.map((subject) => subject.faction).toSet().length !=
        this.subjects.length) {
      throw ArgumentError.value(
        subjects,
        'subjects',
        'factions must be unique',
      );
    }
    for (final subject in this.subjects) {
      if (subject.candidates.isEmpty ||
          subject.candidates.length >
              VeryHardCpuConfig.maxCandidatesPerFaction) {
        throw ArgumentError.value(
          subject.candidates.length,
          'subjects.candidates',
          'must contain one to 133 candidates',
        );
      }
    }
  }

  factory VeryHardDecisionRequest.fromState(
    GameState state, {
    required String matchId,
    required String requestId,
    required Iterable<Faction> factions,
    IslandMapViewport viewport = GameRules.defaultMapViewport,
  }) {
    final generator = VeryHardCandidateGenerator(viewport: viewport);
    return VeryHardDecisionRequest(
      matchId: matchId,
      requestId: requestId,
      elapsedMs: state.elapsedMs,
      board: VeryHardBoardSnapshot.fromState(state),
      subjects: [
        for (final faction in factions)
          VeryHardDecisionSubject(
            faction: faction,
            candidates: generator.generate(state, faction: faction),
          ),
      ],
    );
  }

  final String matchId;
  final String requestId;
  final int elapsedMs;
  final VeryHardBoardSnapshot board;
  final List<VeryHardDecisionSubject> subjects;

  VeryHardDecisionSubject subjectFor(Faction faction) {
    for (final subject in subjects) {
      if (subject.faction == faction) return subject;
    }
    throw VeryHardCpuProtocolException(
      'faction is not included in the request subjects',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': VeryHardCpuConfig.schemaVersion,
    'kind': 'decision',
    'matchId': matchId,
    'requestId': requestId,
    'elapsedMs': elapsedMs,
    'board': board.toJson(),
    'subjects': [for (final subject in subjects) subject.toJson()],
  };

  String encode() => jsonEncode(toJson());
}

final class VeryHardDecisionResponse {
  const VeryHardDecisionResponse({
    required this.requestId,
    required this.candidateIdsByFaction,
    this.model,
    this.promptVersion,
    this.latencyMs,
  });

  final String requestId;
  final Map<Faction, String> candidateIdsByFaction;
  final String? model;
  final String? promptVersion;
  final int? latencyMs;

  factory VeryHardDecisionResponse.fromJson(
    Object? raw, {
    required VeryHardDecisionRequest request,
  }) {
    final map = _asMap(raw, 'response');
    if (map['schemaVersion'] != VeryHardCpuConfig.schemaVersion) {
      throw VeryHardCpuProtocolException('unsupported response schema');
    }
    if (map['requestId'] != request.requestId) {
      throw VeryHardCpuProtocolException('response requestId does not match');
    }
    final rawDecisions = map['decisions'];
    if (rawDecisions is! List) {
      throw VeryHardCpuProtocolException('response decisions must be an array');
    }
    final result = <Faction, String>{};
    for (final rawDecision in rawDecisions) {
      final decision = _asMap(rawDecision, 'decision');
      final faction = _parseFaction(decision['faction']);
      final candidateId = decision['candidateId'];
      if (candidateId is! String || candidateId.isEmpty) {
        throw VeryHardCpuProtocolException('candidateId must be a string');
      }
      if (result.containsKey(faction)) {
        throw VeryHardCpuProtocolException('duplicate faction decision');
      }
      final subject = request.subjectFor(faction);
      if (!subject.candidates.any((candidate) => candidate.id == candidateId)) {
        throw VeryHardCpuProtocolException('candidateId is not in the request');
      }
      result[faction] = candidateId;
    }
    if (result.length != request.subjects.length) {
      throw VeryHardCpuProtocolException('response omitted a faction decision');
    }
    final diagnostics = map['diagnostics'];
    final diagnosticsMap = diagnostics is Map ? diagnostics : null;
    final model = diagnosticsMap?['model'];
    final promptVersion = diagnosticsMap?['promptVersion'];
    final latencyMs = diagnosticsMap?['latencyMs'];
    if (model != null && model is! String ||
        promptVersion != null && promptVersion is! String ||
        latencyMs != null && latencyMs is! int) {
      throw VeryHardCpuProtocolException('invalid response diagnostics');
    }
    return VeryHardDecisionResponse(
      requestId: request.requestId,
      candidateIdsByFaction: Map.unmodifiable(result),
      model: model as String?,
      promptVersion: promptVersion as String?,
      latencyMs: latencyMs as int?,
    );
  }
}

final class VeryHardPreflightResult {
  const VeryHardPreflightResult({required this.available, this.reason});

  const VeryHardPreflightResult.available() : this(available: true);

  const VeryHardPreflightResult.unavailable(String reason)
    : this(available: false, reason: reason);

  final bool available;
  final String? reason;
}

abstract interface class VeryHardCpuGateway {
  Future<VeryHardPreflightResult> preflight({required String matchId});

  Future<VeryHardDecisionResponse> decide(VeryHardDecisionRequest request);
}

final class VeryHardCpuHttpException implements Exception {
  const VeryHardCpuHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'VeryHardCpuHttpException($statusCode, $message)';
}

final class VeryHardCpuProtocolException extends FormatException {
  VeryHardCpuProtocolException(super.message);
}

/// Browser/native HTTP client for the same-origin Vercel Function.
final class HttpVeryHardCpuGateway implements VeryHardCpuGateway {
  HttpVeryHardCpuGateway({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      endpoint = endpoint ?? VeryHardCpuConfig.defaultEndpoint;

  final http.Client _client;
  final Uri endpoint;

  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) async {
    final requestId = 'preflight-$matchId';
    try {
      final response = await _post(<String, Object?>{
        'schemaVersion': VeryHardCpuConfig.schemaVersion,
        'kind': 'preflight',
        'matchId': matchId,
        'requestId': requestId,
      }).timeout(VeryHardCpuConfig.preflightTimeout);
      final map = _asMap(jsonDecode(response.body), 'preflight response');
      if (map['schemaVersion'] != VeryHardCpuConfig.schemaVersion ||
          map['requestId'] != requestId ||
          map['kind'] != 'preflight') {
        throw VeryHardCpuProtocolException('invalid preflight response');
      }
      if (map['available'] != true) {
        return VeryHardPreflightResult.unavailable(
          map['reason'] is String ? map['reason'] as String : 'unavailable',
        );
      }
      return const VeryHardPreflightResult.available();
    } on VeryHardCpuHttpException catch (error) {
      return VeryHardPreflightResult.unavailable(error.message);
    } on Object catch (error) {
      return VeryHardPreflightResult.unavailable(error.toString());
    }
  }

  @override
  Future<VeryHardDecisionResponse> decide(
    VeryHardDecisionRequest request,
  ) async {
    final response = await _post(
      request.toJson(),
    ).timeout(VeryHardCpuConfig.decisionTimeout);
    return VeryHardDecisionResponse.fromJson(
      jsonDecode(response.body),
      request: request,
    );
  }

  Future<http.Response> _post(Map<String, Object?> body) async {
    final response = await _client.post(
      endpoint,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VeryHardCpuHttpException(
        response.statusCode,
        'Very Hard API request failed',
      );
    }
    return response;
  }

  void close() => _client.close();
}

final class VeryHardDecisionOutcome {
  const VeryHardDecisionOutcome({
    required this.decisions,
    required this.usedFallback,
    this.timedOut = false,
    this.skipped = false,
  });

  const VeryHardDecisionOutcome.skipped()
    : decisions = const {},
      usedFallback = false,
      timedOut = false,
      skipped = true;

  final Map<Faction, CpuDecision?> decisions;
  final bool usedFallback;
  final bool timedOut;
  final bool skipped;
}

/// Owns the single in-flight request rule and turns failures into local
/// Hard-equivalent decisions. The controller remains free to tick while this
/// asynchronous operation is pending.
final class VeryHardCpuCoordinator {
  VeryHardCpuCoordinator({
    required this.gateway,
    this.candidateGenerator = const VeryHardCandidateGenerator(),
    Duration timeout = VeryHardCpuConfig.decisionTimeout,
  }) : timeout = timeout;

  final VeryHardCpuGateway gateway;
  VeryHardCandidateGenerator candidateGenerator;
  final Duration timeout;
  Future<VeryHardDecisionOutcome>? _inFlight;

  bool get hasInFlightRequest => _inFlight != null;

  /// Keeps the request gate alive when the controller rebuilds for a viewport
  /// change. An already-running request continues with its original snapshot;
  /// the next request uses the latest geometry.
  void updateViewport(IslandMapViewport viewport) {
    candidateGenerator = VeryHardCandidateGenerator(
      rules: candidateGenerator.rules,
      viewport: viewport,
    );
  }

  Future<VeryHardDecisionOutcome> decide({
    required GameState state,
    required String matchId,
    required Iterable<Faction> factions,
    required CpuDecision? Function(Faction faction) fallback,
  }) {
    if (_inFlight != null)
      return Future.value(const VeryHardDecisionOutcome.skipped());
    final request = VeryHardDecisionRequest.fromState(
      state,
      matchId: matchId,
      requestId: 'decision-${DateTime.now().microsecondsSinceEpoch}',
      factions: factions,
      viewport: candidateGenerator.viewport,
    );
    final operation = _perform(
      request: request,
      factions: request.subjects.map((subject) => subject.faction),
      fallback: fallback,
    );
    late final Future<VeryHardDecisionOutcome> tracked;
    tracked = operation.whenComplete(() {
      if (identical(_inFlight, tracked)) _inFlight = null;
    });
    _inFlight = tracked;
    return tracked;
  }

  Future<VeryHardDecisionOutcome> _perform({
    required VeryHardDecisionRequest request,
    required Iterable<Faction> factions,
    required CpuDecision? Function(Faction faction) fallback,
  }) async {
    try {
      final response = await gateway.decide(request).timeout(timeout);
      final decisions = <Faction, CpuDecision?>{};
      for (final faction in factions) {
        final candidateId = response.candidateIdsByFaction[faction];
        final candidate = request
            .subjectFor(faction)
            .candidates
            .firstWhere((candidate) => candidate.id == candidateId);
        decisions[faction] = candidate.decision;
      }
      return VeryHardDecisionOutcome(
        decisions: Map.unmodifiable(decisions),
        usedFallback: false,
      );
    } on TimeoutException {
      return _fallback(factions, fallback, timedOut: true);
    } on Object {
      return _fallback(factions, fallback);
    }
  }

  VeryHardDecisionOutcome _fallback(
    Iterable<Faction> factions,
    CpuDecision? Function(Faction faction) fallback, {
    bool timedOut = false,
  }) {
    final decisions = <Faction, CpuDecision?>{
      for (final faction in factions) faction: fallback(faction),
    };
    return VeryHardDecisionOutcome(
      decisions: Map.unmodifiable(decisions),
      usedFallback: true,
      timedOut: timedOut,
    );
  }
}

Map<String, Object?> _asMap(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  throw VeryHardCpuProtocolException('$field must be an object');
}

Faction _parseFaction(Object? raw) {
  return switch (raw) {
    'player' => Faction.player,
    'cpu' => Faction.cpu,
    _ => throw VeryHardCpuProtocolException('invalid faction'),
  };
}
