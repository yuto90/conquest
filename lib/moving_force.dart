import 'package:flutter/material.dart';

import 'game/game_rules.dart';
import 'game/game_state.dart';

/// Renders one immutable in-flight troop group.
///
/// The marker is deliberately not a button.  [IgnorePointer] keeps a moving
/// troop from intercepting taps intended for an island underneath it, while
/// the semantics node still exposes its faction and current strength.
class MovingForceWidget extends StatelessWidget {
  const MovingForceWidget({required this.force, this.semanticsKey, super.key});

  static const size = GameRules.movingForceWidgetSize;

  final MovingForce force;
  final Key? semanticsKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticsKey,
      container: true,
      excludeSemantics: true,
      enabled: false,
      label: _semanticLabel,
      child: IgnorePointer(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _backgroundColor,
              shape: force.faction == Faction.cpu
                  ? BoxShape.rectangle
                  : BoxShape.circle,
              border: Border.all(color: _outlineColor, width: 2.5),
              borderRadius: force.faction == Faction.cpu
                  ? BorderRadius.circular(5)
                  : null,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _marker,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Text(
                    force.currentValue.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    return switch (force.faction) {
      Faction.player => Colors.green.shade800,
      Faction.cpu => Colors.red.shade800,
      Faction.neutral => Colors.grey.shade800,
    };
  }

  Color get _outlineColor {
    return switch (force.faction) {
      Faction.player => Colors.lightGreenAccent,
      Faction.cpu => Colors.orangeAccent,
      Faction.neutral => Colors.white,
    };
  }

  String get _marker {
    return switch (force.faction) {
      Faction.player => 'P',
      Faction.cpu => 'C',
      Faction.neutral => 'N',
    };
  }

  String get _factionName {
    return switch (force.faction) {
      Faction.player => 'Player',
      Faction.cpu => 'CPU',
      Faction.neutral => 'Neutral',
    };
  }

  String get _semanticLabel {
    return '$_factionName moving troop, strength ${force.currentValue}, '
        'current value ${force.currentValue}, '
        'from island ${force.sourceIslandId} to island '
        '${force.destinationIslandId}, action unavailable, not tappable';
  }
}

/// Alternate name for code that calls an in-flight group a moving force view.
typedef MovingForceView = MovingForceWidget;
