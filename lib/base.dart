import 'package:flutter/material.dart';

import 'game/game_state.dart';

/// The renderer for one island on the board.
///
/// Ownership is intentionally communicated through three independent cues:
/// the color, the marker (P/C/N), and the outline shape.  The semantic label
/// repeats the faction and numeric values so the board remains usable without
/// relying on color or visual inspection.
class Base extends StatelessWidget {
  const Base({required this.base, required this.onPressed, super.key});

  final IslandState base;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isNeutral = base.faction == Faction.neutral;
    final label = _semanticLabel;

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(3),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: _shape,
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _marker,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            if (isNeutral)
              Text(
                base.currentDurability.toString(),
                key: ValueKey('island-${base.id}-value'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              )
            else ...[
              Text(
                base.currentForces.toString(),
                key: ValueKey('island-${base.id}-current'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              Text(
                '/${base.capacity}',
                key: ValueKey('island-${base.id}-capacity'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _backgroundColor {
    return switch (base.faction) {
      Faction.player => Colors.green.shade700,
      Faction.cpu => Colors.red.shade700,
      Faction.neutral => Colors.grey.shade700,
    };
  }

  OutlinedBorder get _shape {
    return switch (base.faction) {
      Faction.player => const CircleBorder(
        side: BorderSide(color: Colors.white, width: 3),
      ),
      Faction.cpu => const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
        side: BorderSide(color: Colors.white, width: 3),
      ),
      Faction.neutral => const CircleBorder(
        side: BorderSide(color: Colors.black, width: 2),
      ),
    };
  }

  String get _marker {
    return switch (base.faction) {
      Faction.player => 'P',
      Faction.cpu => 'C',
      Faction.neutral => 'N',
    };
  }

  String get _factionName {
    return switch (base.faction) {
      Faction.player => 'Player',
      Faction.cpu => 'CPU',
      Faction.neutral => 'Neutral',
    };
  }

  String get _sizeName {
    return switch (base.size) {
      IslandSize.small => 'small island',
      IslandSize.medium => 'medium island',
      IslandSize.large => 'large island',
      IslandSize.headquarters => 'headquarters',
    };
  }

  String get _semanticLabel {
    final value = base.faction == Faction.neutral
        ? 'durability ${base.currentDurability}'
        : 'forces ${base.currentForces} of ${base.capacity}';
    return '$_factionName $_sizeName, $value';
  }
}
