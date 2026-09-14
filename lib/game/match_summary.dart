/// The non-persistent metrics shown after a player-versus-CPU match.
///
/// Match settings and the outcome remain owned by the existing game state and
/// result models. This value only records what the player did during the
/// current match.
final class MatchSummary {
  const MatchSummary({
    this.elapsedMs = 0,
    this.playerDispatchCount = 0,
    this.playerDispatchedForces = 0,
    this.playerCaptureCount = 0,
  })  : assert(elapsedMs >= 0),
        assert(playerDispatchCount >= 0),
        assert(playerDispatchedForces >= 0),
        assert(playerCaptureCount >= 0);

  static const empty = MatchSummary();

  final int elapsedMs;
  final int playerDispatchCount;
  final int playerDispatchedForces;
  final int playerCaptureCount;

  MatchSummary copyWith({
    int? elapsedMs,
    int? playerDispatchCount,
    int? playerDispatchedForces,
    int? playerCaptureCount,
  }) {
    return MatchSummary(
      elapsedMs: elapsedMs ?? this.elapsedMs,
      playerDispatchCount: playerDispatchCount ?? this.playerDispatchCount,
      playerDispatchedForces:
          playerDispatchedForces ?? this.playerDispatchedForces,
      playerCaptureCount: playerCaptureCount ?? this.playerCaptureCount,
    );
  }

  /// Records one established player dispatch. A non-positive force value is
  /// not a valid dispatch and therefore leaves the summary unchanged.
  MatchSummary recordDispatch(int forces) {
    if (forces <= 0) {
      return this;
    }
    return copyWith(
      playerDispatchCount: playerDispatchCount + 1,
      playerDispatchedForces: playerDispatchedForces + forces,
    );
  }

  /// Records a single transition from neutral or CPU ownership to player.
  MatchSummary recordPlayerCapture() {
    return copyWith(playerCaptureCount: playerCaptureCount + 1);
  }

  /// Updates only the game-time portion of the summary.
  MatchSummary withElapsedMs(int elapsedMs) {
    return copyWith(elapsedMs: elapsedMs);
  }

  @override
  bool operator ==(Object other) {
    return other is MatchSummary &&
        other.elapsedMs == elapsedMs &&
        other.playerDispatchCount == playerDispatchCount &&
        other.playerDispatchedForces == playerDispatchedForces &&
        other.playerCaptureCount == playerCaptureCount;
  }

  @override
  int get hashCode => Object.hash(
    elapsedMs,
    playerDispatchCount,
    playerDispatchedForces,
    playerCaptureCount,
  );
}

/// Formats game time by discarding sub-second precision. Matches longer than
/// one hour use an hours component so the minute field never overflows.
String formatMatchDuration(int elapsedMs) {
  final totalSeconds = elapsedMs < 0 ? 0 : elapsedMs ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = hours == 0
      ? totalSeconds ~/ 60
      : (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  String padTwo(int value) => value.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${padTwo(minutes)}:${padTwo(seconds)}';
  }
  return '${minutes.toString()}:${padTwo(seconds)}';
}
