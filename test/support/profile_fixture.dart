import 'dart:async';

import 'package:conquest/awards/award_manager.dart';
import 'package:conquest/awards/award_storage.dart';
import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/profile/drift_profile_store.dart';
import 'package:conquest/profile/drift_profile_repository.dart';
import 'package:conquest/profile/legacy_xp.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_identity.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/profile/profile_database.dart'
    hide MatchRecord, AwardProfile;
import 'package:conquest/profile/profile_repository.dart';
import 'package:conquest/profile/storage_lease.dart';
import 'package:drift/native.dart';

final class FixtureIds implements UuidGenerator {
  int _id = 100;
  @override
  String next() =>
      '00000000-0000-4000-8000-${(_id++).toString().padLeft(12, '0')}';
}

final class FixtureClock implements UtcClock {
  DateTime time = DateTime.utc(2026, 10, 2);
  @override
  DateTime now() => time;
}

final class FixtureLease implements StorageLease {
  @override
  bool isHeld = true;
  @override
  Future<void> release() async => isHeld = false;
}

final class FixtureLegacy implements LegacyXpSource {
  FixtureLegacy(this.value);
  Object? value;
  Object? error;
  Completer<void>? gate;
  int reads = 0;
  @override
  Future<Object?> read() async {
    reads++;
    await gate?.future;
    if (error != null) throw error!;
    return value;
  }
}

/// Real SQLite transactions and receipts, with timing/failure controls at the
/// existing transaction hook rather than a mock XP writer.
final class ProfileFixture implements ProfileBackend {
  ProfileFixture({
    int? xp,
    ProfileDatabase? database,
    FixtureIds? ids,
    LegacyXpSource? legacySource,
    StorageLease? lease,
    StorageFaultHook? faultHook,
    AwardManager? awards,
    AwardStorage legacyAwards = const EmptyAwardStorage(),
  }) {
    final identities = ids ?? FixtureIds();
    clock = FixtureClock();
    legacy = FixtureLegacy(xp);
    final factory = MatchContextFactory(
      ids: identities,
      clock: clock,
      appVersion: 'test',
      rulesVersion: '1',
    );
    store = DriftProfileStore(
      database: database ?? ProfileDatabase(NativeDatabase.memory()),
      executionId: factory.executionId,
      lease: lease ?? FixtureLease(),
      legacyAwards: legacyAwards,
      ids: identities,
      clock: clock,
      faultHook: (point) async {
        await faultHook?.call(point);
        if (point != StorageFaultPoint.afterMatch) return;
        final index = saveCount++;
        if (saveError != null) throw saveError!;
        if (index < saveGates.length) await saveGates[index].future;
      },
    );
    runtime = MatchPersistence(
      factory: factory,
      openBackend: (_) async {
        if (openError != null) throw openError!;
        return this;
      },
      legacyXp: legacySource ?? legacy,
      awards: awards,
    );
  }

  late final FixtureClock clock;
  late final FixtureLegacy legacy;
  late final DriftProfileStore store;
  @override
  late final PlayerProfileRepository repository = DriftPlayerProfileRepository(
    store,
  );
  late final MatchPersistence runtime;
  Object? saveError;
  Object? openError;
  int saveCount = 0;
  List<Completer<void>> saveGates = [];
  Future<void> ready() => runtime.prepare();
  @override
  Future<PlayerProfile> initializeAndRecover(LegacyXpSource source) =>
      store.initializeAndRecover(source);
  @override
  Stream<int> watchTotalXp(String profileId) => store.watchTotalXp(profileId);
  @override
  Future<void> recordStart(
    MatchStartContext start, {
    AwardEligibility? awardEligibility,
  }) => store.recordStart(start, awardEligibility: awardEligibility);
  @override
  Future<AwardProfile> loadAwards(String profileId) =>
      store.loadAwards(profileId);
  @override
  Future<MatchCommitReceipt> complete(MatchCompletion completion) =>
      store.complete(completion);
  @override
  Future<MatchCommitReceipt> abandon(MatchRecord abandoned) =>
      store.abandon(abandoned);
  @override
  Future<void> recoverInterrupted({
    required String profileId,
    required String executionId,
    required DateTime recoveredAtUtc,
  }) => store.recoverInterrupted(
    profileId: profileId,
    executionId: executionId,
    recoveredAtUtc: recoveredAtUtc,
  );
  @override
  Future<void> close() => store.close();
}
