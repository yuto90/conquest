import 'game/game_state.dart';

/// UI-only faction labels. Internal rules continue to use [Faction.player]
/// and [Faction.cpu], while spectator matches expose the player slots as 1P
/// and 2P without changing the domain model.
final class FactionPresentation {
  const FactionPresentation({required this.marker, required this.semanticName});

  factory FactionPresentation.forMode(GameMode mode, Faction faction) {
    return switch ((mode, faction)) {
      (GameMode.playerVsCpu, Faction.player) => const FactionPresentation(
        marker: 'P',
        semanticName: 'Player',
      ),
      (GameMode.playerVsCpu, Faction.cpu) => const FactionPresentation(
        marker: 'C',
        semanticName: 'CPU',
      ),
      (_, Faction.player) => const FactionPresentation(
        marker: '1P',
        semanticName: '1P',
      ),
      (_, Faction.cpu) => const FactionPresentation(
        marker: '2P',
        semanticName: '2P',
      ),
      (_, Faction.neutral) => const FactionPresentation(
        marker: 'N',
        semanticName: 'Neutral',
      ),
    };
  }

  final String marker;
  final String semanticName;
}
