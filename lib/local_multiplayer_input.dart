import 'package:flutter/painting.dart';

import 'game/game_rules.dart';
import 'game/game_state.dart';

/// One in-progress drag session owned by a single pointer.
final class LocalDispatchSession {
  const LocalDispatchSession({
    required this.pointerId,
    required this.actor,
    required this.sourceIslandId,
    required this.startedOnSelectedSource,
  });

  final int pointerId;
  final Faction actor;
  final int sourceIslandId;
  final bool startedOnSelectedSource;
}

/// Returns the closest island whose widget rect contains [local], or null.
IslandState? hitTestIsland({
  required GameState state,
  required IslandMapViewport viewport,
  required Offset local,
}) {
  IslandState? best;
  var bestDistance = double.infinity;
  for (final island in state.islands) {
    final rect = viewport.rectFor(island);
    if (!rect.containsPoint(local.dx, local.dy)) {
      continue;
    }
    final centerX = (rect.left + rect.right) / 2;
    final centerY = (rect.top + rect.bottom) / 2;
    final dx = local.dx - centerX;
    final dy = local.dy - centerY;
    final distance = dx * dx + dy * dy;
    if (distance < bestDistance) {
      best = island;
      bestDistance = distance;
    }
  }
  return best;
}
