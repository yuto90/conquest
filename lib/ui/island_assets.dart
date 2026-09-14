import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'tactical_theme.dart';

const int islandAssetVariantCount = 12;

/// Returns the stable visual variant for a game island ID.
///
/// The visual variant is deliberately derived from the persistent island ID,
/// rather than list order or runtime randomness. This keeps an island's shape
/// unchanged while its faction changes during combat.
int islandVariantForId(int islandId) {
  return ((islandId % islandAssetVariantCount) + islandAssetVariantCount) %
          islandAssetVariantCount +
      1;
}

String islandFactionAssetDirectory(Faction faction) => switch (faction) {
  Faction.player => 'ally',
  Faction.cpu => 'enemy',
  Faction.neutral => 'neutral',
};

/// Resolves the local PNG used to render one island.
String islandAssetPath({required int islandId, required Faction faction}) {
  final variant = islandVariantForId(islandId).toString().padLeft(2, '0');
  return 'assets/islands/${islandFactionAssetDirectory(faction)}/'
      'island_$variant.png';
}

/// All local island assets in deterministic preload order.
final List<String> islandAssetPaths = List.unmodifiable([
  for (final faction in Faction.values)
    for (var islandId = 0; islandId < islandAssetVariantCount; islandId++)
      islandAssetPath(islandId: islandId, faction: faction),
]);

final Set<String> _reportedAssetErrors = <String>{};

void _reportAssetError(String assetPath, Object error, StackTrace? _) {
  if (_reportedAssetErrors.add(assetPath)) {
    debugPrint('Island asset failed to load: $assetPath ($error)');
  }
}

/// Preloads all faction variants once for the lifetime of this widget.
///
/// The widget does not gate the game loop on image loading. Flutter's image
/// cache handles successful decodes, while [IslandAssetImage] supplies a
/// current-faction fallback during a delay or an error.
class IslandAssetPreloader extends StatefulWidget {
  const IslandAssetPreloader({required this.child, super.key});

  final Widget child;

  @override
  State<IslandAssetPreloader> createState() => _IslandAssetPreloaderState();
}

class _IslandAssetPreloaderState extends State<IslandAssetPreloader> {
  final Set<String> _requestedPaths = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadMissingAssets();
  }

  void _preloadMissingAssets() {
    for (final assetPath in islandAssetPaths) {
      if (!_requestedPaths.add(assetPath)) continue;
      unawaited(_precache(assetPath));
    }
  }

  Future<void> _precache(String assetPath) async {
    try {
      await precacheImage(
        AssetImage(assetPath),
        context,
        onError: (error, stackTrace) {
          _reportAssetError(assetPath, error, stackTrace);
        },
      );
    } catch (error, stackTrace) {
      _reportAssetError(assetPath, error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Displays one island image with a fallback that reflects the latest faction.
class IslandAssetImage extends StatelessWidget {
  const IslandAssetImage({
    required this.assetPath,
    required this.faction,
    required this.isHeadquarters,
    super.key,
  });

  final String assetPath;
  final Faction faction;
  final bool isHeadquarters;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      key: ValueKey(assetPath),
      assetPath,
      excludeFromSemantics: true,
      fit: BoxFit.contain,
      gaplessPlayback: false,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null && !wasSynchronouslyLoaded) {
          return IslandAssetFallback(
            faction: faction,
            isHeadquarters: isHeadquarters,
          );
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        _reportAssetError(assetPath, error, stackTrace);
        return IslandAssetFallback(
          faction: faction,
          isHeadquarters: isHeadquarters,
        );
      },
    );
  }
}

/// Small synchronous fallback used while a faction-specific asset is not ready.
class IslandAssetFallback extends StatelessWidget {
  const IslandAssetFallback({
    required this.faction,
    required this.isHeadquarters,
    super.key,
  });

  final Faction faction;
  final bool isHeadquarters;

  @override
  Widget build(BuildContext context) {
    final color = switch (faction) {
      Faction.player => TacticalPalette.player,
      Faction.cpu => TacticalPalette.cpu,
      Faction.neutral => TacticalPalette.neutral,
    };
    final deepColor = switch (faction) {
      Faction.player => TacticalPalette.playerDeep,
      Faction.cpu => TacticalPalette.cpuDeep,
      Faction.neutral => TacticalPalette.foreground,
    };

    return DecoratedBox(
      key: ValueKey('island-fallback-${faction.name}'),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.68),
        border: Border.all(color: deepColor.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(isHeadquarters ? 20 : 16),
      ),
      child: Center(
        child: Icon(
          isHeadquarters ? Icons.fort_rounded : Icons.terrain_rounded,
          size: isHeadquarters ? 22 : 16,
          color: TacticalPalette.paper.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
