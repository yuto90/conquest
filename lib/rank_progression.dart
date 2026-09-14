import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game_state.dart';

/// One row from the BF4 rank table. [requiredXp] is the XP for this stage.
final class RankTier {
  const RankTier(this.rank, this.title, this.requiredXp);

  final int rank;
  final String title;
  final int requiredXp;

  @override
  bool operator ==(Object other) =>
      other is RankTier &&
      other.rank == rank &&
      other.title == title &&
      other.requiredXp == requiredXp;

  @override
  int get hashCode => Object.hash(rank, title, requiredXp);
}

/// The complete BF4 rank table used by Conquest.
abstract final class RankCatalog {
  static const tiers = <RankTier>[
    RankTier(0, '新兵', 0),
    RankTier(1, '一等兵', 3000),
    RankTier(2, '一等兵Ⅱ', 8000),
    RankTier(3, '一等兵Ⅲ', 11000),
    RankTier(4, '一等兵Ⅳ', 13000),
    RankTier(5, '一等兵Ⅴ', 17000),
    RankTier(6, '上等兵', 18000),
    RankTier(7, '上等兵Ⅱ', 21000),
    RankTier(8, '上等兵Ⅲ', 24000),
    RankTier(9, '上等兵Ⅳ', 25000),
    RankTier(10, '上等兵Ⅴ', 28000),
    RankTier(11, '伍長', 29000),
    RankTier(12, '伍長Ⅱ', 32000),
    RankTier(13, '伍長Ⅲ', 33000),
    RankTier(14, '伍長Ⅳ', 35000),
    RankTier(15, '伍長Ⅴ', 37000),
    RankTier(16, '軍曹', 39000),
    RankTier(17, '軍曹Ⅱ', 40000),
    RankTier(18, '軍曹Ⅲ', 42000),
    RankTier(19, '軍曹Ⅳ', 44000),
    RankTier(20, '軍曹Ⅴ', 46000),
    RankTier(21, '二等軍曹', 47000),
    RankTier(22, '二等軍曹Ⅱ', 48000),
    RankTier(23, '二等軍曹Ⅲ', 51000),
    RankTier(24, '二等軍曹Ⅳ', 51000),
    RankTier(25, '二等軍曹Ⅴ', 54000),
    RankTier(26, '一等軍曹', 55000),
    RankTier(27, '一等軍曹Ⅱ', 56000),
    RankTier(28, '一等軍曹Ⅲ', 58000),
    RankTier(29, '一等軍曹Ⅳ', 58000),
    RankTier(30, '一等軍曹Ⅴ', 58000),
    RankTier(31, '曹長', 69000),
    RankTier(32, '曹長Ⅱ', 65000),
    RankTier(33, '曹長Ⅲ', 65000),
    RankTier(34, '曹長Ⅳ', 65000),
    RankTier(35, '曹長Ⅴ', 65000),
    RankTier(36, '専任曹長', 70000),
    RankTier(37, '専任曹長Ⅱ', 70000),
    RankTier(38, '専任曹長Ⅲ', 70000),
    RankTier(39, '専任曹長Ⅳ', 70000),
    RankTier(40, '専任曹長Ⅴ', 80000),
    RankTier(41, '上級曹長', 80000),
    RankTier(42, '上級曹長Ⅱ', 75000),
    RankTier(43, '上級曹長Ⅲ', 75000),
    RankTier(44, '上級曹長Ⅳ', 80000),
    RankTier(45, '上級曹長Ⅴ', 80000),
    RankTier(46, '最先任上級曹長', 80000),
    RankTier(47, '最先任上級曹長Ⅱ', 90000),
    RankTier(48, '最先任上級曹長Ⅲ', 80000),
    RankTier(49, '最先任上級曹長Ⅳ', 90000),
    RankTier(50, '最先任上級曹長Ⅴ', 90000),
    RankTier(51, '准尉', 90000),
    RankTier(52, '准尉Ⅱ', 100000),
    RankTier(53, '准尉Ⅲ', 100000),
    RankTier(54, '准尉Ⅳ', 90000),
    RankTier(55, '准尉Ⅴ', 90000),
    RankTier(56, '准尉2級', 90000),
    RankTier(57, '准尉2級Ⅱ', 90000),
    RankTier(58, '准尉2級Ⅲ', 100000),
    RankTier(59, '准尉2級Ⅳ', 100000),
    RankTier(60, '准尉2級Ⅴ', 90000),
    RankTier(61, '准尉3級', 110000),
    RankTier(62, '准尉3級Ⅱ', 100000),
    RankTier(63, '准尉3級Ⅲ', 100000),
    RankTier(64, '准尉3級Ⅳ', 110000),
    RankTier(65, '准尉3級Ⅴ', 110000),
    RankTier(66, '准尉4級', 90000),
    RankTier(67, '准尉4級Ⅱ', 110000),
    RankTier(68, '准尉4級Ⅲ', 110000),
    RankTier(69, '准尉4級Ⅳ', 120000),
    RankTier(70, '准尉4級Ⅴ', 120000),
    RankTier(71, '准尉5級', 110000),
    RankTier(72, '准尉5級Ⅱ', 110000),
    RankTier(73, '准尉5級Ⅲ', 110000),
    RankTier(74, '准尉5級Ⅳ', 110000),
    RankTier(75, '准尉5級Ⅴ', 120000),
    RankTier(76, '少尉', 120000),
    RankTier(77, '少尉Ⅱ', 120000),
    RankTier(78, '少尉Ⅲ', 120000),
    RankTier(79, '少尉Ⅳ', 120000),
    RankTier(80, '少尉Ⅴ', 120000),
    RankTier(81, '中尉', 130000),
    RankTier(82, '中尉Ⅱ', 120000),
    RankTier(83, '中尉Ⅲ', 120000),
    RankTier(84, '中尉Ⅳ', 130000),
    RankTier(85, '中尉Ⅴ', 130000),
    RankTier(86, '大尉', 130000),
    RankTier(87, '大尉Ⅱ', 130000),
    RankTier(88, '大尉Ⅲ', 120000),
    RankTier(89, '大尉Ⅳ', 130000),
    RankTier(90, '大尉Ⅴ', 130000),
    RankTier(91, '少佐', 140000),
    RankTier(92, '少佐Ⅱ', 130000),
    RankTier(93, '少佐Ⅲ', 140000),
    RankTier(94, '少佐Ⅳ', 130000),
    RankTier(95, '少佐Ⅴ', 140000),
    RankTier(96, '中佐Ⅰ', 150000),
    RankTier(97, '中佐Ⅱ', 140000),
    RankTier(98, '中佐Ⅲ', 140000),
    RankTier(99, '中佐Ⅳ', 130000),
    RankTier(100, '大佐', 140000),
    RankTier(101, '大佐Ⅱ', 200000),
    RankTier(102, '大佐Ⅲ', 200000),
    RankTier(103, '大佐Ⅳ', 200000),
    RankTier(104, '大佐Ⅴ', 200000),
    RankTier(105, '大佐Ⅵ', 200000),
    RankTier(106, '大佐Ⅶ', 200000),
    RankTier(107, '大佐Ⅷ', 200000),
    RankTier(108, '大佐Ⅸ', 200000),
    RankTier(109, '大佐Ⅹ', 200000),
    RankTier(110, '准将', 200000),
    RankTier(111, '准将Ⅱ', 300000),
    RankTier(112, '准将Ⅲ', 470000),
    RankTier(113, '准将Ⅳ', 480000),
    RankTier(114, '准将Ⅴ', 500000),
    RankTier(115, '准将Ⅵ', 510000),
    RankTier(116, '准将Ⅶ', 530000),
    RankTier(117, '准将Ⅷ', 550000),
    RankTier(118, '准将Ⅸ', 560000),
    RankTier(119, '准将Ⅹ', 590000),
    RankTier(120, '少将', 600000),
    RankTier(121, '少将Ⅱ', 620000),
    RankTier(122, '少将Ⅲ', 640000),
    RankTier(123, '少将Ⅳ', 660000),
    RankTier(124, '少将Ⅴ', 680000),
    RankTier(125, '少将Ⅵ', 700000),
    RankTier(126, '少将Ⅶ', 730000),
    RankTier(127, '少将Ⅷ', 740000),
    RankTier(128, '少将Ⅸ', 770000),
    RankTier(129, '少将Ⅹ', 790000),
    RankTier(130, '中将', 810000),
    RankTier(131, '中将Ⅱ', 840000),
    RankTier(132, '中将Ⅲ', 860000),
    RankTier(133, '中将Ⅳ', 890000),
    RankTier(134, '中将Ⅴ', 910000),
    RankTier(135, '中将Ⅵ', 940000),
    RankTier(136, '中将Ⅶ', 960000),
    RankTier(137, '中将Ⅷ', 990000),
    RankTier(138, '中将Ⅸ', 1020000),
    RankTier(139, '中将Ⅹ', 1050000),
    RankTier(140, '大将', 1070000),
  ];

  static const stageXpTotal = 32180000;

  static final cumulativeXp = _buildCumulativeXp();

  static List<int> _buildCumulativeXp() {
    var total = 0;
    final result = <int>[];
    for (final tier in tiers) {
      total += tier.requiredXp;
      result.add(total);
    }
    return List<int>.unmodifiable(result);
  }

  static RankProgress progressForXp(int totalXp) {
    return RankProgress.fromTotalXp(totalXp);
  }
}

/// The saved player rank state derived from one cumulative XP value.
final class RankProgress {
  const RankProgress({
    required this.totalXp,
    required this.rank,
    required this.title,
    required this.currentRankXp,
    required this.nextRankXp,
    required this.xpToNextRank,
    required this.progressRatio,
  });

  static const zero = RankProgress(
    totalXp: 0,
    rank: 0,
    title: '新兵',
    currentRankXp: 0,
    nextRankXp: 3000,
    xpToNextRank: 3000,
    progressRatio: 0,
  );

  factory RankProgress.fromTotalXp(int totalXp) {
    final safeTotalXp = totalXp < 0 ? 0 : totalXp;
    var rank = 0;
    for (var index = 1; index < RankCatalog.tiers.length; index++) {
      if (safeTotalXp < RankCatalog.cumulativeXp[index]) break;
      rank = index;
    }

    final rankStartXp = RankCatalog.cumulativeXp[rank];
    final isMax = rank == RankCatalog.tiers.length - 1;
    final nextRankXp = isMax ? null : RankCatalog.tiers[rank + 1].requiredXp;
    final currentRankXp = safeTotalXp - rankStartXp;
    final progressRatio = isMax
        ? 1.0
        : (currentRankXp / nextRankXp!).clamp(0.0, 1.0).toDouble();
    return RankProgress(
      totalXp: safeTotalXp,
      rank: rank,
      title: RankCatalog.tiers[rank].title,
      currentRankXp: currentRankXp,
      nextRankXp: nextRankXp,
      xpToNextRank: isMax ? 0 : nextRankXp! - currentRankXp,
      progressRatio: progressRatio,
    );
  }

  final int totalXp;
  final int rank;
  final String title;
  final int currentRankXp;
  final int? nextRankXp;
  final int xpToNextRank;
  final double progressRatio;

  bool get isMax => rank == RankCatalog.tiers.length - 1;

  @override
  bool operator ==(Object other) =>
      other is RankProgress &&
      other.totalXp == totalXp &&
      other.rank == rank &&
      other.title == title &&
      other.currentRankXp == currentRankXp &&
      other.nextRankXp == nextRankXp &&
      other.xpToNextRank == xpToNextRank &&
      other.progressRatio == progressRatio;

  @override
  int get hashCode => Object.hash(
    totalXp,
    rank,
    title,
    currentRankXp,
    nextRankXp,
    xpToNextRank,
    progressRatio,
  );
}

/// Returns the result-screen bar value for an award animation.
///
/// Awards in the same rank interpolate directly between their saved
/// before/after snapshots. A rank-up fills the old rank first, then starts the
/// new rank at zero. MAX remains full while additional XP is accumulated.
double rankProgressBarValue({
  required RankProgress before,
  required RankProgress after,
  required double animation,
}) {
  final progress = animation.clamp(0.0, 1.0).toDouble();
  if (before.isMax && after.isMax) {
    return _lerp(before.progressRatio, after.progressRatio, progress);
  }
  if (after.rank > before.rank) {
    if (progress <= 0.5) {
      return _lerp(before.progressRatio, 1, progress * 2);
    }
    return _lerp(0, after.progressRatio, (progress - 0.5) * 2);
  }
  return _lerp(before.progressRatio, after.progressRatio, progress);
}

double _lerp(double start, double end, double progress) {
  return start + (end - start) * progress;
}

final class RankAward {
  const RankAward({
    required this.before,
    required this.after,
    required this.xpAwarded,
  });

  factory RankAward.none(RankProgress progress) {
    return RankAward(before: progress, after: progress, xpAwarded: 0);
  }

  final RankProgress before;
  final RankProgress after;
  final int xpAwarded;

  bool get didRankUp => after.rank > before.rank;
}

/// XP reward for one eligible player victory.
int victoryXpFor(CpuDifficulty difficulty) => switch (difficulty) {
  CpuDifficulty.veryEasy => 500,
  CpuDifficulty.easy => 1000,
  CpuDifficulty.normal => 1500,
  CpuDifficulty.hard => 3000,
};

abstract interface class RankProgressStore {
  Future<int?> loadTotalXp();
  Future<void> saveTotalXp(int totalXp);
}

final class SharedPreferencesRankProgressStore implements RankProgressStore {
  SharedPreferencesRankProgressStore({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  static const storageKey = 'conquest.rank.totalXp';

  final Future<SharedPreferences> _preferences;

  @override
  Future<int?> loadTotalXp() async {
    final preferences = await _preferences;
    return preferences.getInt(storageKey);
  }

  @override
  Future<void> saveTotalXp(int totalXp) async {
    final preferences = await _preferences;
    final saved = await preferences.setInt(storageKey, totalXp);
    if (!saved) {
      throw StateError('Unable to save rank XP');
    }
  }
}

/// The local rank account. Mutations are serialized behind the load and each
/// match id can be awarded at most once.
final class RankProgressManager {
  RankProgressManager({required this.store});

  final RankProgressStore store;

  Future<RankProgress>? _loadFuture;
  Future<void> _mutationQueue = Future<void>.value();
  RankProgress? _current;
  final Set<String> _awardedMatchIds = <String>{};

  Object? storageError;

  RankProgress get current => _current ?? RankProgress.zero;

  Future<RankProgress> load() {
    final current = _current;
    if (current != null) return Future<RankProgress>.value(current);
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadFromStorage();
    _loadFuture = future;
    return future;
  }

  Future<RankProgress> _loadFromStorage() async {
    try {
      final storedXp = await store.loadTotalXp();
      _current = RankProgress.fromTotalXp(storedXp ?? 0);
      storageError = null;
    } catch (error) {
      storageError = error;
      _current = RankProgress.zero;
    }
    return _current!;
  }

  Future<RankAward> recordVictory({
    required String matchId,
    required CpuDifficulty difficulty,
  }) {
    late final Future<RankAward> operation;
    operation = _mutationQueue.then((_) async {
      final before = await load();
      if (_awardedMatchIds.contains(matchId)) {
        return RankAward.none(before);
      }

      final after = RankProgress.fromTotalXp(
        before.totalXp + victoryXpFor(difficulty),
      );
      try {
        await store.saveTotalXp(after.totalXp);
      } catch (error) {
        storageError = error;
        rethrow;
      }
      storageError = null;
      _current = after;
      _awardedMatchIds.add(matchId);
      return RankAward(
        before: before,
        after: after,
        xpAwarded: victoryXpFor(difficulty),
      );
    });
    _mutationQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}

final rankProgressStoreProvider = Provider<RankProgressStore>(
  (ref) => SharedPreferencesRankProgressStore(),
);

final rankProgressProvider =
    AsyncNotifierProvider<RankProgressNotifier, RankProgress>(
      RankProgressNotifier.new,
    );

final class RankProgressNotifier extends AsyncNotifier<RankProgress> {
  late RankProgressManager _manager;

  @override
  Future<RankProgress> build() async {
    _manager = RankProgressManager(store: ref.read(rankProgressStoreProvider));
    return _manager.load();
  }

  Object? get storageError => _manager.storageError;

  Future<RankAward> recordVictory({
    required String matchId,
    required CpuDifficulty difficulty,
  }) async {
    await future;
    final award = await _manager.recordVictory(
      matchId: matchId,
      difficulty: difficulty,
    );
    state = AsyncData(award.after);
    return award;
  }
}
