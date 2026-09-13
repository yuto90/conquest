import 'package:conquest/game/game_state.dart';
import 'package:conquest/ui/island_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps stable island ids to the same variant for every faction', () {
    expect(
      islandAssetPath(islandId: 0, faction: Faction.player),
      'assets/islands/ally/island_01.png',
    );
    expect(
      islandAssetPath(islandId: 4, faction: Faction.cpu),
      'assets/islands/enemy/island_05.png',
    );
    expect(
      islandAssetPath(islandId: 11, faction: Faction.neutral),
      'assets/islands/neutral/island_12.png',
    );
    expect(
      islandAssetPath(islandId: 12, faction: Faction.player),
      'assets/islands/ally/island_01.png',
    );
    expect(
      islandAssetPath(islandId: 101, faction: Faction.neutral),
      'assets/islands/neutral/island_06.png',
    );
  });

  test('preload list contains each of the 12 variants once per faction', () {
    expect(islandAssetPaths, hasLength(36));
    expect(islandAssetPaths.toSet(), hasLength(36));
    for (final faction in Faction.values) {
      for (var variant = 1; variant <= 12; variant++) {
        expect(
          islandAssetPaths,
          contains(islandAssetPath(islandId: variant - 1, faction: faction)),
        );
      }
    }
  });
}
