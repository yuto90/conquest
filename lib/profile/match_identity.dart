import 'dart:math';

import '../game/game_state.dart';
import 'match_contracts.dart';

abstract interface class UuidGenerator {
  String next();
}

final class SecureUuidGenerator implements UuidGenerator {
  final Random _random = Random.secure();

  @override
  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

abstract interface class UtcClock {
  DateTime now();
}

final class SystemUtcClock implements UtcClock {
  @override
  DateTime now() => DateTime.now().toUtc();
}

/// One root-owned instance per application execution, outside Widget.build.
final class MatchContextFactory {
  MatchContextFactory({
    required this.ids,
    required this.clock,
    required this.appVersion,
    required this.rulesVersion,
    this.metricsVersion = MatchStartContext.currentMetricsVersion,
  }) : executionId = ids.next() {
    requireUuid(executionId, 'executionId');
  }

  final UuidGenerator ids;
  final UtcClock clock;
  final String executionId;
  final String appVersion;
  final String rulesVersion;
  final int metricsVersion;

  /// Called once at the first playing boundary for every new match/rematch.
  /// The caller retains this context through pause, resize and rebuild.
  MatchStartContext? newMatch({
    required String profileId,
    required GameConfiguration configuration,
    required SessionOrigin origin,
    SessionKind kind = SessionKind.normal,
  }) {
    if (!isRecordableSession(
      configuration: configuration,
      origin: origin,
      kind: kind,
    )) {
      return null;
    }
    return MatchStartContext(
      matchId: ids.next(),
      profileId: profileId,
      executionId: executionId,
      configuration: configuration,
      sessionKind: kind,
      origin: origin,
      startedAtUtc: clock.now(),
      appVersion: appVersion,
      rulesVersion: rulesVersion,
      metricsVersion: metricsVersion,
    );
  }
}
