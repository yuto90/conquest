/// Canonical movement timing shared by player and CPU dispatch.
final class MovementTiming {
  const MovementTiming._();

  /// Time for a force to cross the full screen diagonal, in milliseconds.
  static const int screenDiagonalDurationMs = 10000;
}
