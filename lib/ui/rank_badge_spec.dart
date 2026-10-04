import 'package:flutter/foundation.dart';

import '../rank_progression.dart';

enum RankBadgeFamily { recruit, enlisted, warrant, officer, command, general }

@immutable
final class RankBadgeSpec {
  const RankBadgeSpec._(
    this.tier,
    this.groupIndex,
    this.stage,
    this.stageCount,
  );

  factory RankBadgeSpec.fromRank(int rank) {
    final tier = RankCatalog.tiers[rank];
    final group = RankTitleKey.values.indexOf(tier.titleKey);
    final end = group + 1 < RankTitleKey.values.length
        ? RankTitleKey.values[group + 1].firstRank
        : RankCatalog.tiers.length;
    return RankBadgeSpec._(
      tier,
      group,
      rank - tier.titleKey.firstRank,
      end - tier.titleKey.firstRank,
    );
  }

  final RankTier tier;
  final int groupIndex;
  final int stage;
  final int stageCount;

  RankBadgeFamily get family => switch (groupIndex) {
    0 => RankBadgeFamily.recruit,
    <= 10 => RankBadgeFamily.enlisted,
    <= 15 => RankBadgeFamily.warrant,
    <= 18 => RankBadgeFamily.officer,
    <= 21 => RankBadgeFamily.command,
    _ => RankBadgeFamily.general,
  };

  bool get usesCrest =>
      family == RankBadgeFamily.command || family == RankBadgeFamily.general;

  // Five marks fit one row; the rail denotes the second band of a ten-stage group.
  int get pips => stageCount == 1 ? 0 : stage % 5 + 1;
  bool get secondBand => stageCount == 10 && stage >= 5;
}
