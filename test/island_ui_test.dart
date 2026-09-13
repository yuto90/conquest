import 'package:conquest/base.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/ui/island_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

IslandState _island({
  required int id,
  required Faction faction,
  IslandSize size = IslandSize.medium,
}) {
  return IslandState(
    id: id,
    faction: faction,
    size: size,
    currentForces: faction == Faction.neutral ? 0 : 42,
    durability: faction == Faction.neutral ? 30 : 0,
    capacity: size.capacity,
  );
}

void main() {
  testWidgets('switches faction image without changing the island variant', (
    tester,
  ) async {
    final playerIsland = _island(id: 4, faction: Faction.player);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 64,
          child: Base(base: playerIsland, onPressed: null),
        ),
      ),
    );
    await tester.pump();

    Image image() => tester.widget<Image>(find.byType(Image));
    expect(
      (image().image as AssetImage).assetName,
      islandAssetPath(islandId: 4, faction: Faction.player),
    );
    expect(find.text('/100'), findsOneWidget);

    final enemyIsland = playerIsland.copyWith(faction: Faction.cpu);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 64,
          child: Base(base: enemyIsland, onPressed: null),
        ),
      ),
    );
    await tester.pump();

    expect(
      (image().image as AssetImage).assetName,
      islandAssetPath(islandId: 4, faction: Faction.cpu),
    );
    expect(find.text('/100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps headquarters marker and semantic contract over the image',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final headquarters = _island(
        id: 0,
        faction: Faction.player,
        size: IslandSize.headquarters,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 100,
            child: Base(
              key: const ValueKey('test-headquarters'),
              base: headquarters,
              onPressed: null,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('island-0-hq-marker')), findsOneWidget);
      expect(find.text('/200'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('test-headquarters')))
            .label,
        contains('headquarters'),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('uses a current-faction fallback when an image cannot load', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.square(
          dimension: 64,
          child: IslandAssetImage(
            assetPath: 'assets/islands/missing/island_01.png',
            faction: Faction.cpu,
            isHeadquarters: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(IslandAssetFallback), findsOneWidget);
    expect(find.byKey(const ValueKey('island-fallback-cpu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
