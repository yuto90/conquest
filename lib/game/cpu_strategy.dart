import 'dart:math' as math;

import 'game_rules.dart';
import 'game_state.dart';

/// The kind of action selected by the standard CPU.
enum CpuDecisionKind { defense, attack }

/// One deterministic CPU dispatch.  A decision never contains hidden
/// strength or speed adjustments: [strength] is always the floor half of the
/// selected source island's current forces.
final class CpuDecision {
  const CpuDecision({
    required this.kind,
    required this.sourceIslandId,
    required this.destinationIslandId,
    required this.strength,
  });

  final CpuDecisionKind kind;
  final int sourceIslandId;
  final int destinationIslandId;
  final int strength;

  @override
  bool operator ==(Object other) {
    return other is CpuDecision &&
        other.kind == kind &&
        other.sourceIslandId == sourceIslandId &&
        other.destinationIslandId == destinationIslandId &&
        other.strength == strength;
  }

  @override
  int get hashCode =>
      Object.hash(kind, sourceIslandId, destinationIslandId, strength);

  @override
  String toString() {
    return 'CpuDecision(kind: $kind, source: $sourceIslandId, '
        'destination: $destinationIslandId, strength: $strength)';
  }
}

/// Standard, deterministic CPU strategy.
///
/// The strategy only reads the supplied [GameState].  In particular, it does
/// not inspect future player actions or retain a hidden board model.  The
/// random source is used solely for the next decision interval; all choices
/// for one state are ordered by explicit, stable tie-breakers.
final class CpuStrategy {
  CpuStrategy({
    math.Random? random,
    GameRules? rules,
    IslandMapViewport viewport = GameRules.defaultMapViewport,
  }) : this._(
         random: random ?? math.Random(),
         rules: rules ?? const GameRules(),
         viewport: viewport,
       );

  /// Creates an inert strategy for engine clients that want to exercise the
  /// player-only loop.  Production uses the default enabled constructor; the
  /// explicit mode keeps controller tests independent from CPU decisions.
  CpuStrategy.noop({
    GameRules? rules,
    IslandMapViewport viewport = GameRules.defaultMapViewport,
  }) : this._(
         random: math.Random(0),
         rules: rules ?? const GameRules(),
         viewport: viewport,
         enabled: false,
       );

  CpuStrategy._({
    required this.random,
    required this.rules,
    required this.viewport,
    this.enabled = true,
  });

  static const minDecisionIntervalMs = 1500;
  static const maxDecisionIntervalMs = 3000;

  final math.Random random;
  final GameRules rules;
  final IslandMapViewport viewport;
  final bool enabled;

  /// Returns the next interval in the inclusive [1.5, 3] second range.
  int nextDecisionDelayMs() {
    return minDecisionIntervalMs +
        random.nextInt(maxDecisionIntervalMs - minDecisionIntervalMs + 1);
  }

  /// Compatibility alias for callers that describe a CPU turn as a choice.
  CpuDecision? choose(GameState state) => decide(state);

  /// Selects at most one dispatch for [state].
  ///
  /// Defense threats are considered first.  When no defense can arrive in
  /// time, attack candidates follow the priority from the game rules.
  CpuDecision? decide(GameState state) {
    if (!enabled || state.phase != GamePhase.playing) {
      return null;
    }

    final defense = _chooseDefense(state);
    if (defense != null) {
      return defense;
    }
    return _chooseAttack(state);
  }

  /// Applies one previously selected decision using the same dispatch and
  /// movement rules as the player.  Invalid or stale decisions are ignored.
  GameState applyDecision(
    GameState state,
    CpuDecision decision, {
    int? movingForceId,
  }) {
    if (state.phase != GamePhase.playing || decision.strength <= 0) {
      return state;
    }
    final sourceIndex = state.islands.indexWhere(
      (island) => island.id == decision.sourceIslandId,
    );
    final destinationIndex = state.islands.indexWhere(
      (island) => island.id == decision.destinationIslandId,
    );
    if (sourceIndex < 0 ||
        destinationIndex < 0 ||
        sourceIndex == destinationIndex) {
      return state;
    }

    final source = state.islands[sourceIndex];
    final destination = state.islands[destinationIndex];
    final expectedStrength = source.currentForces ~/ 2;
    if (source.faction != Faction.cpu ||
        expectedStrength <= 0 ||
        decision.strength != expectedStrength) {
      return state;
    }

    final islands = [...state.islands];
    islands[sourceIndex] = source.copyWith(
      currentForces: source.currentForces - expectedStrength,
    );
    final force = rules.createMovingForce(
      id: movingForceId ?? _nextMovingForceId(state),
      faction: Faction.cpu,
      source: source,
      destination: destination,
      strength: expectedStrength,
      departureTimeMs: state.elapsedMs,
      viewport: viewport,
    );
    return state.copyWith(
      islands: islands,
      movingForces: [...state.movingForces, force],
    );
  }

  /// Compatibility alias for dispatch-oriented callers.
  GameState dispatch(
    GameState state,
    CpuDecision decision, {
    int? movingForceId,
  }) {
    return applyDecision(state, decision, movingForceId: movingForceId);
  }

  /// Predicts the state at a known future timestamp using only already-known
  /// moving forces and the optional candidate force.
  GameState forecast(
    GameState state, {
    required int atMs,
    MovingForce? additionalForce,
  }) {
    if (atMs < state.elapsedMs) {
      return state;
    }
    final movingForces = additionalForce == null
        ? state.movingForces
        : [...state.movingForces, additionalForce];
    return rules.tick(
      state.copyWith(movingForces: movingForces),
      deltaMs: atMs - state.elapsedMs,
    );
  }

  CpuDecision? _chooseDefense(GameState state) {
    final threats = <_Threat>[];
    for (final force in state.movingForces) {
      if (force.faction != Faction.player ||
          force.strength <= 0 ||
          force.arrivalTimeMs <= state.elapsedMs) {
        continue;
      }
      final target = _findIsland(state.islands, force.destinationIslandId);
      if (target?.faction != Faction.cpu) {
        continue;
      }
      final predicted = forecast(state, atMs: force.arrivalTimeMs);
      final predictedTarget = _findIsland(
        predicted.islands,
        force.destinationIslandId,
      );
      if (predictedTarget?.faction != Faction.cpu) {
        threats.add(
          _Threat(
            arrivalTimeMs: force.arrivalTimeMs,
            destinationIslandId: force.destinationIslandId,
            forceId: force.id,
          ),
        );
      }
    }

    threats.sort((first, second) {
      final arrival = first.arrivalTimeMs.compareTo(second.arrivalTimeMs);
      if (arrival != 0) {
        return arrival;
      }
      final target = first.destinationIslandId.compareTo(
        second.destinationIslandId,
      );
      if (target != 0) {
        return target;
      }
      return first.forceId.compareTo(second.forceId);
    });

    final cpuIslands = state.islands
        .where(
          (island) => island.faction == Faction.cpu && island.currentForces > 1,
        )
        .toList();
    for (final threat in threats) {
      final target = _findIsland(state.islands, threat.destinationIslandId);
      if (target == null) {
        continue;
      }
      final sources = cpuIslands
          .where((island) => island.id != target.id)
          .toList();
      sources.sort((first, second) {
        final firstDistance = _distance(first, target);
        final secondDistance = _distance(second, target);
        final distance = firstDistance.compareTo(secondDistance);
        if (distance != 0) {
          return distance;
        }
        final forces = first.currentForces.compareTo(second.currentForces);
        if (forces != 0) {
          return forces;
        }
        return first.id.compareTo(second.id);
      });

      for (final source in sources) {
        final strength = source.currentForces ~/ 2;
        if (strength <= 0) {
          continue;
        }
        final candidate = _candidateForce(
          state,
          source: source,
          destination: target,
          strength: strength,
        );
        if (candidate.arrivalTimeMs > threat.arrivalTimeMs) {
          continue;
        }
        final predicted = _forecastWithCandidate(
          state,
          source: source,
          candidate: candidate,
          atMs: threat.arrivalTimeMs,
        );
        final predictedTarget = _findIsland(predicted.islands, target.id);
        if (predictedTarget?.faction == Faction.cpu) {
          return CpuDecision(
            kind: CpuDecisionKind.defense,
            sourceIslandId: source.id,
            destinationIslandId: target.id,
            strength: strength,
          );
        }
      }
    }
    return null;
  }

  CpuDecision? _chooseAttack(GameState state) {
    final sources = state.islands
        .where(
          (island) => island.faction == Faction.cpu && island.currentForces > 1,
        )
        .toList();
    if (sources.isEmpty) {
      return null;
    }

    final enemies = state.islands
        .where((island) => island.faction == Faction.player)
        .toList();
    final neutrals = state.islands
        .where((island) => island.faction == Faction.neutral)
        .toList();

    final enemyCandidates = _capturableCandidates(
      state,
      sources: sources,
      targets: enemies,
    );
    if (enemyCandidates.isNotEmpty) {
      return _selectAttackCandidate(enemyCandidates);
    }

    final neutralCandidates = _capturableCandidates(
      state,
      sources: sources,
      targets: neutrals,
    );
    if (neutralCandidates.isNotEmpty) {
      return _selectAttackCandidate(neutralCandidates);
    }

    if (enemies.isEmpty) {
      return null;
    }
    final strongestForce = sources
        .map((source) => source.currentForces)
        .reduce(math.max);
    final weakestForce = enemies
        .map((enemy) => enemy.currentForces)
        .reduce(math.min);
    final fallbackCandidates =
        [
          for (final source in sources)
            if (source.currentForces == strongestForce)
              for (final target in enemies)
                if (target.currentForces == weakestForce)
                  _AttackCandidate(
                    source: source,
                    target: target,
                    strength: source.currentForces ~/ 2,
                    distance: _distance(source, target),
                  ),
        ]..sort((first, second) {
          final distance = first.distance.compareTo(second.distance);
          if (distance != 0) {
            return distance;
          }
          final target = first.target.id.compareTo(second.target.id);
          if (target != 0) {
            return target;
          }
          return first.source.id.compareTo(second.source.id);
        });
    final fallback = fallbackCandidates.first;
    return CpuDecision(
      kind: CpuDecisionKind.attack,
      sourceIslandId: fallback.source.id,
      destinationIslandId: fallback.target.id,
      strength: fallback.strength,
    );
  }

  List<_AttackCandidate> _capturableCandidates(
    GameState state, {
    required List<IslandState> sources,
    required List<IslandState> targets,
  }) {
    final candidates = <_AttackCandidate>[];
    for (final target in targets) {
      final sourceCandidates = <_AttackCandidate>[];
      for (final source in sources) {
        if (source.id == target.id) {
          continue;
        }
        final strength = source.currentForces ~/ 2;
        if (strength <= 0) {
          continue;
        }
        final candidate = _candidateForce(
          state,
          source: source,
          destination: target,
          strength: strength,
        );
        // Do not spend a fresh troop on a target that known CPU arrivals
        // already capture by this time.  A candidate remains eligible when
        // those arrivals alone leave the target uncaptured, so simultaneous
        // forces are still evaluated as one arrival-time combat.
        final predictedWithoutCandidate = forecast(
          state,
          atMs: candidate.arrivalTimeMs,
        );
        final targetWithoutCandidate = _findIsland(
          predictedWithoutCandidate.islands,
          target.id,
        );
        if (targetWithoutCandidate?.faction == Faction.cpu) {
          continue;
        }
        final predicted = _forecastWithCandidate(
          state,
          source: source,
          candidate: candidate,
          atMs: candidate.arrivalTimeMs,
        );
        final predictedTarget = _findIsland(predicted.islands, target.id);
        if (predictedTarget?.faction == Faction.cpu) {
          sourceCandidates.add(
            _AttackCandidate(
              source: source,
              target: target,
              strength: strength,
              distance: _distance(source, target),
            ),
          );
        }
      }
      if (sourceCandidates.isNotEmpty) {
        sourceCandidates.sort(_compareSourcePriority);
        candidates.add(sourceCandidates.first);
      }
    }
    return candidates;
  }

  CpuDecision _selectAttackCandidate(List<_AttackCandidate> candidates) {
    candidates.sort((first, second) {
      final distance = first.distance.compareTo(second.distance);
      if (distance != 0) {
        return distance;
      }
      final target = first.target.id.compareTo(second.target.id);
      if (target != 0) {
        return target;
      }
      return _compareSourcePriority(first, second);
    });
    final selected = candidates.first;
    return CpuDecision(
      kind: CpuDecisionKind.attack,
      sourceIslandId: selected.source.id,
      destinationIslandId: selected.target.id,
      strength: selected.strength,
    );
  }

  int _compareSourcePriority(_AttackCandidate first, _AttackCandidate second) {
    final forces = first.source.currentForces.compareTo(
      second.source.currentForces,
    );
    if (forces != 0) {
      return forces;
    }
    final distance = first.distance.compareTo(second.distance);
    if (distance != 0) {
      return distance;
    }
    return first.source.id.compareTo(second.source.id);
  }

  MovingForce _candidateForce(
    GameState state, {
    required IslandState source,
    required IslandState destination,
    required int strength,
  }) {
    return rules.createMovingForce(
      id: _nextMovingForceId(state),
      faction: Faction.cpu,
      source: source,
      destination: destination,
      strength: strength,
      departureTimeMs: state.elapsedMs,
      viewport: viewport,
    );
  }

  GameState _forecastWithCandidate(
    GameState state, {
    required IslandState source,
    required MovingForce candidate,
    required int atMs,
  }) {
    final sourceIndex = state.islands.indexWhere(
      (island) => island.id == source.id,
    );
    if (sourceIndex < 0) {
      return state;
    }
    final islands = [...state.islands];
    islands[sourceIndex] = source.copyWith(
      currentForces: source.currentForces - candidate.strength,
    );
    return forecast(
      state.copyWith(islands: islands),
      atMs: atMs,
      additionalForce: candidate,
    );
  }

  double _distance(IslandState first, IslandState second) {
    return viewport.movingForceDistance(first.position, second.position);
  }

  static IslandState? _findIsland(List<IslandState> islands, int id) {
    for (final island in islands) {
      if (island.id == id) {
        return island;
      }
    }
    return null;
  }

  static int _nextMovingForceId(GameState state) {
    var maxId = -1;
    for (final force in state.movingForces) {
      maxId = math.max(maxId, force.id);
    }
    return maxId + 1;
  }
}

final class _Threat {
  const _Threat({
    required this.arrivalTimeMs,
    required this.destinationIslandId,
    required this.forceId,
  });

  final int arrivalTimeMs;
  final int destinationIslandId;
  final int forceId;
}

final class _AttackCandidate {
  const _AttackCandidate({
    required this.source,
    required this.target,
    required this.strength,
    required this.distance,
  });

  final IslandState source;
  final IslandState target;
  final int strength;
  final double distance;
}
