import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game_state.dart';
import 'l10n/generated/app_localizations.dart';

/// The localized name key shared by every rank in one BF4 title group.
enum RankTitleKey {
  recruit(0),
  privateFirstClass(1),
  lanceCorporal(6),
  corporal(11),
  sergeant(16),
  staffSergeant(21),
  gunnerySergeant(26),
  masterSergeant(31),
  firstSergeant(36),
  masterGunnerySergeant(41),
  sergeantMajor(46),
  warrantOfficerOne(51),
  chiefWarrantOfficerTwo(56),
  chiefWarrantOfficerThree(61),
  chiefWarrantOfficerFour(66),
  chiefWarrantOfficerFive(71),
  secondLieutenant(76),
  firstLieutenant(81),
  captain(86),
  major(91),
  lieutenantColonel(96, japaneseInitialNumeral: true),
  colonel(100),
  brigadierGeneral(110),
  majorGeneral(120),
  lieutenantGeneral(130),
  general(140);

  const RankTitleKey(this.firstRank, {this.japaneseInitialNumeral = false});

  final int firstRank;

  // The existing Japanese table includes 中佐Ⅰ at rank 96. Keep that
  // established display while English follows the requested no-suffix rule.
  final bool japaneseInitialNumeral;
}

/// One row from the language-independent BF4 rank table.
final class RankTier {
  const RankTier(this.rank, this.titleKey, this.requiredXp);

  final int rank;
  final RankTitleKey titleKey;
  final int requiredXp;

  String localizedTitle(AppLocalizations l10n) {
    final baseTitle = switch (titleKey) {
      RankTitleKey.recruit => l10n.rankTitleRecruit,
      RankTitleKey.privateFirstClass => l10n.rankTitlePrivateFirstClass,
      RankTitleKey.lanceCorporal => l10n.rankTitleLanceCorporal,
      RankTitleKey.corporal => l10n.rankTitleCorporal,
      RankTitleKey.sergeant => l10n.rankTitleSergeant,
      RankTitleKey.staffSergeant => l10n.rankTitleStaffSergeant,
      RankTitleKey.gunnerySergeant => l10n.rankTitleGunnerySergeant,
      RankTitleKey.masterSergeant => l10n.rankTitleMasterSergeant,
      RankTitleKey.firstSergeant => l10n.rankTitleFirstSergeant,
      RankTitleKey.masterGunnerySergeant => l10n.rankTitleMasterGunnerySergeant,
      RankTitleKey.sergeantMajor => l10n.rankTitleSergeantMajor,
      RankTitleKey.warrantOfficerOne => l10n.rankTitleWarrantOfficerOne,
      RankTitleKey.chiefWarrantOfficerTwo =>
        l10n.rankTitleChiefWarrantOfficerTwo,
      RankTitleKey.chiefWarrantOfficerThree =>
        l10n.rankTitleChiefWarrantOfficerThree,
      RankTitleKey.chiefWarrantOfficerFour =>
        l10n.rankTitleChiefWarrantOfficerFour,
      RankTitleKey.chiefWarrantOfficerFive =>
        l10n.rankTitleChiefWarrantOfficerFive,
      RankTitleKey.secondLieutenant => l10n.rankTitleSecondLieutenant,
      RankTitleKey.firstLieutenant => l10n.rankTitleFirstLieutenant,
      RankTitleKey.captain => l10n.rankTitleCaptain,
      RankTitleKey.major => l10n.rankTitleMajor,
      RankTitleKey.lieutenantColonel => l10n.rankTitleLieutenantColonel,
      RankTitleKey.colonel => l10n.rankTitleColonel,
      RankTitleKey.brigadierGeneral => l10n.rankTitleBrigadierGeneral,
      RankTitleKey.majorGeneral => l10n.rankTitleMajorGeneral,
      RankTitleKey.lieutenantGeneral => l10n.rankTitleLieutenantGeneral,
      RankTitleKey.general => l10n.rankTitleGeneral,
    };
    final stage = rank - titleKey.firstRank;
    final isJapanese = l10n.localeName.toLowerCase().startsWith('ja');
    if (isJapanese) {
      final numeral = stage == 0
          ? (titleKey.japaneseInitialNumeral ? 1 : 0)
          : stage + 1;
      return numeral == 0
          ? baseTitle
          : baseTitle + _japaneseRankNumerals[numeral];
    }
    if (stage == 0) return baseTitle;
    return baseTitle + ' ' + _englishRankNumerals[stage + 1];
  }

  @override
  bool operator ==(Object other) =>
      other is RankTier &&
      other.rank == rank &&
      other.titleKey == titleKey &&
      other.requiredXp == requiredXp;

  @override
  int get hashCode => Object.hash(rank, titleKey, requiredXp);
}

const _japaneseRankNumerals = <String>[
  '',
  'Ⅰ',
  'Ⅱ',
  'Ⅲ',
  'Ⅳ',
  'Ⅴ',
  'Ⅵ',
  'Ⅶ',
  'Ⅷ',
  'Ⅸ',
  'Ⅹ',
];

const _englishRankNumerals = <String>[
  '',
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
  'VIII',
  'IX',
  'X',
];

/// The complete BF4 rank table used by Conquest.
abstract final class RankCatalog {
  static const _titleKeyRuns = <MapEntry<RankTitleKey, int>>[
    MapEntry(RankTitleKey.recruit, 1),
    MapEntry(RankTitleKey.privateFirstClass, 5),
    MapEntry(RankTitleKey.lanceCorporal, 5),
    MapEntry(RankTitleKey.corporal, 5),
    MapEntry(RankTitleKey.sergeant, 5),
    MapEntry(RankTitleKey.staffSergeant, 5),
    MapEntry(RankTitleKey.gunnerySergeant, 5),
    MapEntry(RankTitleKey.masterSergeant, 5),
    MapEntry(RankTitleKey.firstSergeant, 5),
    MapEntry(RankTitleKey.masterGunnerySergeant, 5),
    MapEntry(RankTitleKey.sergeantMajor, 5),
    MapEntry(RankTitleKey.warrantOfficerOne, 5),
    MapEntry(RankTitleKey.chiefWarrantOfficerTwo, 5),
    MapEntry(RankTitleKey.chiefWarrantOfficerThree, 5),
    MapEntry(RankTitleKey.chiefWarrantOfficerFour, 5),
    MapEntry(RankTitleKey.chiefWarrantOfficerFive, 5),
    MapEntry(RankTitleKey.secondLieutenant, 5),
    MapEntry(RankTitleKey.firstLieutenant, 5),
    MapEntry(RankTitleKey.captain, 5),
    MapEntry(RankTitleKey.major, 5),
    MapEntry(RankTitleKey.lieutenantColonel, 4),
    MapEntry(RankTitleKey.colonel, 10),
    MapEntry(RankTitleKey.brigadierGeneral, 10),
    MapEntry(RankTitleKey.majorGeneral, 10),
    MapEntry(RankTitleKey.lieutenantGeneral, 10),
    MapEntry(RankTitleKey.general, 1),
  ];

  static const _requiredXp = <int>[
    0,
    3000,
    8000,
    11000,
    13000,
    17000,
    18000,
    21000,
    24000,
    25000,
    28000,
    29000,
    32000,
    33000,
    35000,
    37000,
    39000,
    40000,
    42000,
    44000,
    46000,
    47000,
    48000,
    51000,
    51000,
    54000,
    55000,
    56000,
    58000,
    58000,
    58000,
    69000,
    65000,
    65000,
    65000,
    65000,
    70000,
    70000,
    70000,
    70000,
    80000,
    80000,
    75000,
    75000,
    80000,
    80000,
    80000,
    90000,
    80000,
    90000,
    90000,
    90000,
    100000,
    100000,
    90000,
    90000,
    90000,
    90000,
    100000,
    100000,
    90000,
    110000,
    100000,
    100000,
    110000,
    110000,
    90000,
    110000,
    110000,
    120000,
    120000,
    110000,
    110000,
    110000,
    110000,
    120000,
    120000,
    120000,
    120000,
    120000,
    120000,
    130000,
    120000,
    120000,
    130000,
    130000,
    130000,
    130000,
    120000,
    130000,
    130000,
    140000,
    130000,
    140000,
    130000,
    140000,
    150000,
    140000,
    140000,
    130000,
    140000,
    200000,
    200000,
    200000,
    200000,
    200000,
    200000,
    200000,
    200000,
    200000,
    200000,
    300000,
    470000,
    480000,
    500000,
    510000,
    530000,
    550000,
    560000,
    590000,
    600000,
    620000,
    640000,
    660000,
    680000,
    700000,
    730000,
    740000,
    770000,
    790000,
    810000,
    840000,
    860000,
    890000,
    910000,
    940000,
    960000,
    990000,
    1020000,
    1050000,
    1070000,
  ];

  static final tiers = _buildTiers();

  static const stageXpTotal = 32180000;

  static final cumulativeXp = _buildCumulativeXp();

  static List<RankTier> _buildTiers() {
    final titleKeys = <RankTitleKey>[];
    for (final run in _titleKeyRuns) {
      titleKeys.addAll(List<RankTitleKey>.filled(run.value, run.key));
    }
    if (titleKeys.length != _requiredXp.length) {
      throw StateError('Rank title and XP tables must have the same length');
    }
    return List<RankTier>.unmodifiable([
      for (var rank = 0; rank < _requiredXp.length; rank++)
        RankTier(rank, titleKeys[rank], _requiredXp[rank]),
    ]);
  }

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
    required this.currentRankXp,
    required this.nextRankXp,
    required this.xpToNextRank,
    required this.progressRatio,
  });

  static const zero = RankProgress(
    totalXp: 0,
    rank: 0,
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
      currentRankXp: currentRankXp,
      nextRankXp: nextRankXp,
      xpToNextRank: isMax ? 0 : nextRankXp! - currentRankXp,
      progressRatio: progressRatio,
    );
  }

  final int totalXp;
  final int rank;
  final int currentRankXp;
  final int? nextRankXp;
  final int xpToNextRank;
  final double progressRatio;

  RankTier get tier => RankCatalog.tiers[rank];

  String localizedTitle(AppLocalizations l10n) => tier.localizedTitle(l10n);

  bool get isMax => rank == RankCatalog.tiers.length - 1;

  @override
  bool operator ==(Object other) =>
      other is RankProgress &&
      other.totalXp == totalXp &&
      other.rank == rank &&
      other.currentRankXp == currentRankXp &&
      other.nextRankXp == nextRankXp &&
      other.xpToNextRank == xpToNextRank &&
      other.progressRatio == progressRatio;

  @override
  int get hashCode => Object.hash(
    totalXp,
    rank,
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
  CpuDifficulty.veryHard => 5000,
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
