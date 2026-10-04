enum AwardMetric {
  captures,
  dispatches,
  forces,
  wins,
  normalWins,
  hardWins,
  captureRibbons,
  elapsedMs,
}

enum AssignmentTrack { capture, command, tactics }

enum AssignmentTier { bronze, silver, gold }

class AwardCondition {
  const AwardCondition(this.metric, this.target, {this.maximum = false});
  final AwardMetric metric;
  final int target;
  final bool maximum;

  bool satisfied(Map<AwardMetric, int> values) =>
      values.containsKey(metric) &&
      (maximum ? values[metric]! <= target : values[metric]! >= target);
}

class AssignmentDefinition {
  const AssignmentDefinition(
    this.id,
    this.track,
    this.tier,
    this.conditions, {
    this.prerequisite,
    this.singleMatch = false,
  });
  final String id;
  final AssignmentTrack track;
  final AssignmentTier tier;
  final List<AwardCondition> conditions;
  final String? prerequisite;
  final bool singleMatch;
}

class RibbonDefinition {
  const RibbonDefinition(this.id, this.metric, this.threshold);
  final String id;
  final AwardMetric metric;
  final int threshold;
  String get medalId => '${id}_medal';
}

abstract final class AwardCatalog {
  static const version = 1;
  static const ribbonsPerMedal = 10;
  static const swiftVictoryMs = 180000;
  static const ribbons = [
    RibbonDefinition('capture', AwardMetric.captures, 3),
    RibbonDefinition('maneuver', AwardMetric.dispatches, 10),
    RibbonDefinition('deployment', AwardMetric.forces, 500),
    RibbonDefinition('victory', AwardMetric.wins, 1),
    RibbonDefinition('hard_victory', AwardMetric.hardWins, 1),
    RibbonDefinition('swift_victory', AwardMetric.elapsedMs, swiftVictoryMs),
  ];
  static const assignments = [
    AssignmentDefinition(
      'capture_bronze',
      AssignmentTrack.capture,
      AssignmentTier.bronze,
      [
        AwardCondition(AwardMetric.captures, 5),
        AwardCondition(AwardMetric.dispatches, 10),
      ],
    ),
    AssignmentDefinition(
      'capture_silver',
      AssignmentTrack.capture,
      AssignmentTier.silver,
      [
        AwardCondition(AwardMetric.captures, 25),
        AwardCondition(AwardMetric.captureRibbons, 5),
      ],
      prerequisite: 'capture_bronze',
    ),
    AssignmentDefinition(
      'capture_gold',
      AssignmentTrack.capture,
      AssignmentTier.gold,
      [
        AwardCondition(AwardMetric.captures, 100),
        AwardCondition(AwardMetric.captureRibbons, 20),
      ],
      prerequisite: 'capture_silver',
    ),
    AssignmentDefinition(
      'command_bronze',
      AssignmentTrack.command,
      AssignmentTier.bronze,
      [
        AwardCondition(AwardMetric.wins, 1),
        AwardCondition(AwardMetric.forces, 500),
      ],
    ),
    AssignmentDefinition(
      'command_silver',
      AssignmentTrack.command,
      AssignmentTier.silver,
      [
        AwardCondition(AwardMetric.normalWins, 3),
        AwardCondition(AwardMetric.forces, 2500),
      ],
      prerequisite: 'command_bronze',
    ),
    AssignmentDefinition(
      'command_gold',
      AssignmentTrack.command,
      AssignmentTier.gold,
      [
        AwardCondition(AwardMetric.hardWins, 10),
        AwardCondition(AwardMetric.forces, 10000),
      ],
      prerequisite: 'command_silver',
    ),
    AssignmentDefinition(
      'tactics_bronze',
      AssignmentTrack.tactics,
      AssignmentTier.bronze,
      [
        AwardCondition(AwardMetric.captures, 3),
        AwardCondition(AwardMetric.dispatches, 5),
      ],
      singleMatch: true,
    ),
    AssignmentDefinition(
      'tactics_silver',
      AssignmentTrack.tactics,
      AssignmentTier.silver,
      [
        AwardCondition(AwardMetric.normalWins, 1),
        AwardCondition(AwardMetric.captures, 5),
      ],
      prerequisite: 'tactics_bronze',
      singleMatch: true,
    ),
    AssignmentDefinition(
      'tactics_gold',
      AssignmentTrack.tactics,
      AssignmentTier.gold,
      [
        AwardCondition(AwardMetric.hardWins, 1),
        AwardCondition(AwardMetric.elapsedMs, swiftVictoryMs, maximum: true),
      ],
      prerequisite: 'tactics_silver',
      singleMatch: true,
    ),
  ];
}
