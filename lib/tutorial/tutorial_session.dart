import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/game_rules.dart';
import '../game/game_state.dart';

/// The four moments that make up the hands-on game tutorial.
enum TutorialStep {
  selectSource,
  selectDestination,
  watchCapture,
  explainVictory,
}

/// A short-lived practice match that owns no app-level match or rank state.
///
/// The session deliberately uses [GameRules] for dispatch, movement, growth,
/// and arrival resolution. It has no CPU loop and never awards a result.
final class TutorialSession extends ChangeNotifier {
  TutorialSession._({
    required GameState gameState,
    required IslandMapViewport viewport,
  }) : _gameState = gameState,
       _viewport = viewport;

  static const playerHeadquartersId = 0;
  static const targetIslandId = 2;

  static final _tutorialConfiguration = GameConfiguration(
    totalIslandCount: 6,
    gameMode: GameMode.playerVsCpu,
  );

  final GameRules _rules = const GameRules();
  GameState _gameState;
  IslandMapViewport _viewport;
  TutorialStep _step = TutorialStep.selectSource;
  TutorialStep? _retryPrompt;
  var _hasArrived = false;
  var _growthDemonstrated = 0;
  var _dispatchedStrength = 0;
  var _sourceForcesAfterDispatch = 0;
  var _lifecyclePaused = false;

  /// Creates the fixed six-island map used by every tutorial session.
  factory TutorialSession.create({
    IslandMapViewport viewport = GameRules.defaultMapViewport,
  }) {
    final islands = _layoutIslands(_fixedIslands(), viewport);
    return TutorialSession._(
      gameState: GameState(
        configuration: _tutorialConfiguration,
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: islands,
      ),
      viewport: viewport,
    );
  }

  GameState get gameState => _gameState;
  TutorialStep get step => _step;
  TutorialStep? get retryPrompt => _retryPrompt;
  bool get hasArrived => _hasArrived;
  int get growthDemonstrated => _growthDemonstrated;
  int get dispatchedStrength => _dispatchedStrength;
  int get sourceForcesAfterDispatch => _sourceForcesAfterDispatch;
  bool get lifecyclePaused => _lifecyclePaused;
  bool get canResumeAfterLifecycle =>
      !_lifecyclePaused || _isSafeLayout(_gameState.islands, _viewport);
  bool get canAdvanceAfterCapture =>
      _step == TutorialStep.watchCapture && _hasArrived;

  /// Updates the viewport used for movement rendering.
  ///
  /// A resize can happen while the demonstration aircraft is in flight. The
  /// board is repacked immediately, and the aircraft keeps its current
  /// progress along the new route. The lifecycle pause then prevents any
  /// further time from passing until the player explicitly resumes.
  void updateViewport(IslandMapViewport viewport) {
    if (!viewport.isValid) return;
    _viewport = viewport;
    final islands = _layoutIslands(_gameState.islands, viewport);
    if (_samePositions(_gameState.islands, islands)) return;
    final movingForces = [
      for (final force in _gameState.movingForces)
        _repositionMovingForce(force, islands),
    ];
    _gameState = _gameState.copyWith(
      islands: islands,
      movingForces: movingForces,
    );
  }

  /// Handles a tutorial island tap. Wrong taps only set a re-prompt state.
  void tapIsland(int islandId) {
    if (_lifecyclePaused) return;

    switch (_step) {
      case TutorialStep.selectSource:
        if (islandId != playerHeadquartersId) {
          _retryPrompt = TutorialStep.selectSource;
          notifyListeners();
          return;
        }
        _gameState = _gameState.copyWith(
          selectedIslandId: playerHeadquartersId,
        );
        _retryPrompt = null;
        _step = TutorialStep.selectDestination;
        notifyListeners();
      case TutorialStep.selectDestination:
        if (islandId == playerHeadquartersId) {
          _gameState = _gameState.clearSelection();
          _retryPrompt = TutorialStep.selectSource;
          _step = TutorialStep.selectSource;
          notifyListeners();
          return;
        }
        if (islandId != targetIslandId) {
          _retryPrompt = TutorialStep.selectDestination;
          notifyListeners();
          return;
        }
        _dispatchToTarget();
      case TutorialStep.watchCapture:
        if (!_hasArrived) {
          _retryPrompt = TutorialStep.watchCapture;
          notifyListeners();
        }
      case TutorialStep.explainVictory:
        // The final explanation is intentionally frozen.
        return;
    }
  }

  /// Advances the movement demonstration only. All explanatory phases stay
  /// frozen so a player can read the rule without the board changing.
  void tick(int deltaMs) {
    if (_lifecyclePaused ||
        deltaMs < 0 ||
        _step != TutorialStep.watchCapture ||
        _hasArrived) {
      return;
    }
    if (_gameState.movingForces.isEmpty) return;
    final movement = _gameState.movingForces.first;
    // GameRules applies growth boundaries after an arrival. A timer callback
    // can overshoot that event, so consume only the movement remainder and
    // freeze at the arrival instant until the player advances the next card.
    final remainingToArrival = movement.arrivalTimeMs - _gameState.elapsedMs;
    final movementDelta = math.min(deltaMs, math.max(0, remainingToArrival));
    if (movementDelta <= 0) return;
    _gameState = _rules.tick(_gameState, deltaMs: movementDelta);
    final target = _island(targetIslandId);
    _hasArrived =
        target?.faction == Faction.player && _gameState.movingForces.isEmpty;
    if (_hasArrived) _retryPrompt = null;
    notifyListeners();
  }

  /// Performs one real one-second growth tick before freezing the final card.
  void advanceAfterCapture() {
    if (!canAdvanceAfterCapture) return;
    final before = _island(targetIslandId)?.currentForces ?? 0;
    _gameState = _rules.tick(_gameState, deltaMs: 1000);
    final after = _island(targetIslandId)?.currentForces ?? before;
    _growthDemonstrated = after - before;
    _step = TutorialStep.explainVictory;
    _retryPrompt = null;
    notifyListeners();
  }

  /// Holds the movement demonstration after a lifecycle or page-visibility
  /// interruption. Resuming is always an explicit user action.
  void pauseForLifecycle() {
    if (_lifecyclePaused) return;
    _lifecyclePaused = true;
    notifyListeners();
  }

  void resumeAfterLifecycle() {
    if (!_lifecyclePaused || !canResumeAfterLifecycle) return;
    _lifecyclePaused = false;
    notifyListeners();
  }

  void _dispatchToTarget() {
    final source = _island(playerHeadquartersId);
    final destination = _island(targetIslandId);
    if (source == null || destination == null || !source.canDispatch) {
      _retryPrompt = TutorialStep.selectSource;
      _step = TutorialStep.selectSource;
      _gameState = _gameState.clearSelection();
      notifyListeners();
      return;
    }

    final strength = _rules.dispatchStrength(source);
    final sourceAfter = _rules.dispatchSource(source);
    final nextForce = _rules.createMovingForce(
      id: 0,
      faction: Faction.player,
      source: source,
      destination: destination,
      strength: strength,
      departureTimeMs: _gameState.elapsedMs,
      viewport: _viewport,
    );
    final islands = [
      for (final island in _gameState.islands)
        island.id == source.id ? sourceAfter : island,
    ];
    _gameState = _gameState
        .copyWith(islands: islands, movingForces: [nextForce])
        .clearSelection();
    _dispatchedStrength = strength;
    _sourceForcesAfterDispatch = sourceAfter.currentForces;
    _retryPrompt = null;
    _step = TutorialStep.watchCapture;
    notifyListeners();
  }

  IslandState? _island(int id) {
    for (final island in _gameState.islands) {
      if (island.id == id) return island;
    }
    return null;
  }

  static bool _samePositions(
    List<IslandState> first,
    List<IslandState> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id ||
          first[index].position != second[index].position) {
        return false;
      }
    }
    return true;
  }

  static List<IslandState> _layoutIslands(
    List<IslandState> islands,
    IslandMapViewport viewport,
  ) {
    // The original normalized anchors give the board more breathing room on
    // phones and tablets. Below 360 logical pixels, a pixel-packed layout is
    // needed because the 100px headquarters and 64px medium islands cannot
    // be made non-overlapping by normalized scaling alone.
    if (viewport.width >= 360 && _isSafeLayout(islands, viewport)) {
      return islands;
    }

    final rowGap = viewport.height >= 246 ? 16.0 : 4.0;
    final contentHeight = 100.0 + 64.0 + 50.0 + rowGap * 2;
    final double top = math.max(0.0, (viewport.height - contentHeight) / 2);
    final placements = <int, ({double left, double top})>{};

    void addRow(List<int> ids, double y) {
      const gap = 8.0;
      final rowWidth =
          ids.fold<double>(0, (total, id) {
            final island = islands.firstWhere(
              (candidate) => candidate.id == id,
            );
            return total + GameRules.islandWidgetSize(island.size);
          }) +
          gap * math.max(0, ids.length - 1);
      var left = math.max(0.0, (viewport.width - rowWidth) / 2);
      for (final id in ids) {
        final island = islands.firstWhere((candidate) => candidate.id == id);
        final size = GameRules.islandWidgetSize(island.size);
        placements[id] = (left: left, top: y);
        left += size + gap;
      }
    }

    addRow(const [playerHeadquartersId, 1], top);
    addRow(const [4, 5, targetIslandId], top + 100 + rowGap);
    addRow(const [3], top + 100 + rowGap + 64 + rowGap);

    return [
      for (final island in islands)
        island.copyWith(
          position: _normalizedPosition(
            left: placements[island.id]!.left,
            top: placements[island.id]!.top,
            size: GameRules.islandWidgetSize(island.size),
            viewport: viewport,
          ),
        ),
    ];
  }

  static MovingForce _repositionMovingForce(
    MovingForce force,
    List<IslandState> islands,
  ) {
    IslandState? findIsland(int id) {
      for (final island in islands) {
        if (island.id == id) return island;
      }
      return null;
    }

    final source = findIsland(force.sourceIslandId);
    final destination = findIsland(force.destinationIslandId);
    if (source == null || destination == null) return force;
    final progress = force.progress.clamp(0.0, 1.0);
    return force.copyWith(
      position: IslandPosition(
        x: source.x + (destination.x - source.x) * progress,
        y: source.y + (destination.y - source.y) * progress,
      ),
      deltaX: destination.x - source.x,
      deltaY: destination.y - source.y,
    );
  }

  static bool _isSafeLayout(
    List<IslandState> islands,
    IslandMapViewport viewport,
  ) {
    if (!viewport.isValid || islands.length != 6) return false;
    final rectangles = [for (final island in islands) viewport.rectFor(island)];
    for (var index = 0; index < rectangles.length; index++) {
      final rectangle = rectangles[index];
      if (!rectangle.isWithin(viewport)) return false;
      for (
        var otherIndex = index + 1;
        otherIndex < rectangles.length;
        otherIndex++
      ) {
        if (rectangle.overlaps(rectangles[otherIndex])) return false;
      }
    }
    return true;
  }

  static IslandPosition _normalizedPosition({
    required double left,
    required double top,
    required double size,
    required IslandMapViewport viewport,
  }) {
    final horizontalSpan = viewport.width - size;
    final verticalSpan = viewport.height - size;
    return IslandPosition(
      x: horizontalSpan <= 0 ? 0 : left * 2 / horizontalSpan - 1,
      y: verticalSpan <= 0 ? 0 : top * 2 / verticalSpan - 1,
    );
  }

  static List<IslandState> _fixedIslands() {
    return const [
      IslandState(
        id: playerHeadquartersId,
        position: IslandPosition(x: -0.72, y: -0.72),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 100,
        capacity: 200,
      ),
      IslandState(
        id: 1,
        position: IslandPosition(x: 0.72, y: 0.68),
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 100,
        capacity: 200,
      ),
      IslandState(
        id: targetIslandId,
        position: IslandPosition(x: 0.12, y: -0.10),
        faction: Faction.neutral,
        size: IslandSize.small,
        durability: 10,
        capacity: 50,
      ),
      IslandState(
        id: 3,
        position: IslandPosition(x: 0.70, y: -0.72),
        faction: Faction.neutral,
        size: IslandSize.small,
        durability: 10,
        capacity: 50,
      ),
      IslandState(
        id: 4,
        position: IslandPosition(x: -0.90, y: 0.68),
        faction: Faction.neutral,
        size: IslandSize.medium,
        durability: 30,
        capacity: 100,
      ),
      IslandState(
        id: 5,
        position: IslandPosition(x: -0.20, y: 0.68),
        faction: Faction.neutral,
        size: IslandSize.medium,
        durability: 30,
        capacity: 100,
      ),
    ];
  }
}
