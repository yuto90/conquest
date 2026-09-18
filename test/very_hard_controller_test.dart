import 'dart:async';
import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/very_hard_cpu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

class _FailingGateway implements VeryHardCpuGateway {
  var preflightCalls = 0;
  var decisionCalls = 0;

  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) async {
    preflightCalls++;
    return const VeryHardPreflightResult.available();
  }

  @override
  Future<VeryHardDecisionResponse> decide(VeryHardDecisionRequest request) {
    decisionCalls++;
    return Future<VeryHardDecisionResponse>.error(StateError('offline'));
  }
}

final class _PreflightGateway extends _FailingGateway {
  _PreflightGateway(this.preflightResult);

  final VeryHardPreflightResult preflightResult;

  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) async {
    preflightCalls++;
    return preflightResult;
  }
}

final class _ThrowingPreflightGateway extends _FailingGateway {
  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) {
    preflightCalls++;
    return Future<VeryHardPreflightResult>.error(StateError('offline'));
  }
}

final class _DelayedGateway implements VeryHardCpuGateway {
  var decisionCalls = 0;
  late VeryHardDecisionRequest request;
  final response = Completer<VeryHardDecisionResponse>();

  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) async {
    return const VeryHardPreflightResult.available();
  }

  @override
  Future<VeryHardDecisionResponse> decide(VeryHardDecisionRequest request) {
    decisionCalls++;
    this.request = request;
    return response.future;
  }
}

final class _DelayedFailureGateway implements VeryHardCpuGateway {
  var decisionCalls = 0;
  final failure = Completer<VeryHardDecisionResponse>();

  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) async {
    return const VeryHardPreflightResult.available();
  }

  @override
  Future<VeryHardDecisionResponse> decide(VeryHardDecisionRequest request) {
    decisionCalls++;
    return failure.future;
  }
}

void _completeCountdown(ManualGameLoop loop) {
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
}

void main() {
  test('blocks Very Hard start when Jev preflight is unavailable', () async {
    final loop = ManualGameLoop();
    final gateway = _PreflightGateway(
      const VeryHardPreflightResult.unavailable('provider unavailable'),
    );
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        veryHardCpuGatewayProvider.overrideWithValue(gateway),
      ],
    );
    final subscription = container.listen(gameControllerProvider, (_, __) {});
    addTearDown(container.dispose);
    addTearDown(subscription.close);

    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.veryHard);
    final start = controller.startGame();
    await start;

    final state = container.read(gameControllerProvider);
    expect(gateway.preflightCalls, 1);
    expect(state.phase, GamePhase.configuration);
    expect(state.veryHardPreflightStatus, VeryHardPreflightStatus.unavailable);
    expect(loop.isRunning, isFalse);
  });

  test('starts Very Hard only after a successful preflight', () async {
    final loop = ManualGameLoop();
    final gateway = _PreflightGateway(
      const VeryHardPreflightResult.available(),
    );
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        veryHardCpuGatewayProvider.overrideWithValue(gateway),
      ],
    );
    final subscription = container.listen(gameControllerProvider, (_, __) {});
    addTearDown(container.dispose);
    addTearDown(subscription.close);

    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.veryHard);
    await controller.startGame();

    final state = container.read(gameControllerProvider);
    expect(gateway.preflightCalls, 1);
    expect(state.phase, GamePhase.startCountdown);
    expect(state.veryHardPreflightStatus, VeryHardPreflightStatus.available);
    expect(loop.isRunning, isTrue);
  });

  test('treats a preflight exception as unavailable', () async {
    final loop = ManualGameLoop();
    final gateway = _ThrowingPreflightGateway();
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        veryHardCpuGatewayProvider.overrideWithValue(gateway),
      ],
    );
    final subscription = container.listen(gameControllerProvider, (_, __) {});
    addTearDown(container.dispose);
    addTearDown(subscription.close);

    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.veryHard);
    await controller.startGame();

    final state = container.read(gameControllerProvider);
    expect(gateway.preflightCalls, 1);
    expect(state.phase, GamePhase.configuration);
    expect(state.veryHardPreflightStatus, VeryHardPreflightStatus.unavailable);
    expect(loop.isRunning, isFalse);
  });

  test('falls back to the latest Hard decision after a Jev error', () async {
    final loop = ManualGameLoop();
    final gateway = _FailingGateway();
    final strategy = CpuStrategy(
      timingRandom: _ZeroRandom(),
      qualityRandom: _ZeroRandom(),
      viewport: GameRules.defaultMapViewport,
    );
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        cpuStrategyProvider.overrideWithValue(strategy),
        veryHardCpuGatewayProvider.overrideWithValue(gateway),
      ],
    );
    final subscription = container.listen(gameControllerProvider, (_, __) {});
    addTearDown(container.dispose);
    addTearDown(subscription.close);

    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.veryHard);
    await controller.startGame();
    _completeCountdown(loop);
    controller.state = container
        .read(gameControllerProvider)
        .copyWith(
          islands: [
            for (final island in container.read(gameControllerProvider).islands)
              island.id == 0
                  ? island.copyWith(
                      faction: Faction.cpu,
                      currentForces: 40,
                      durability: 0,
                    )
                  : island.id == 1
                  ? island.copyWith(
                      faction: Faction.player,
                      currentForces: 40,
                      durability: 0,
                    )
                  : island,
          ],
        );

    // Minimum Very Hard/Hard deadline is 1,500ms = 30 engine ticks.
    for (var index = 0; index < 30; index++) {
      loop.tick();
    }
    await Future<void>.delayed(Duration.zero);

    final after = container.read(gameControllerProvider);
    expect(gateway.decisionCalls, 1);
    expect(
      after.movingForces.where((force) => force.faction == Faction.cpu),
      hasLength(1),
    );
    expect(after.movingForces.single.strength, 20);
  });

  test(
    'recomputes a Hard fallback from the latest state after Jev waits',
    () async {
      final loop = ManualGameLoop();
      final gateway = _DelayedFailureGateway();
      final strategy = CpuStrategy(
        timingRandom: _ZeroRandom(),
        qualityRandom: _ZeroRandom(),
        viewport: GameRules.defaultMapViewport,
      );
      final container = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          cpuStrategyProvider.overrideWithValue(strategy),
          veryHardCpuGatewayProvider.overrideWithValue(gateway),
        ],
      );
      final subscription = container.listen(gameControllerProvider, (_, __) {});
      addTearDown(container.dispose);
      addTearDown(subscription.close);

      final controller = container.read(gameControllerProvider.notifier);
      controller.selectCpuDifficulty(CpuDifficulty.veryHard);
      await controller.startGame();
      _completeCountdown(loop);
      controller.state = container
          .read(gameControllerProvider)
          .copyWith(
            islands: [
              for (final island
                  in container.read(gameControllerProvider).islands)
                island.id == 0
                    ? island.copyWith(
                        faction: Faction.cpu,
                        currentForces: 40,
                        durability: 0,
                      )
                    : island.id == 1
                    ? island.copyWith(
                        faction: Faction.player,
                        currentForces: 40,
                        durability: 0,
                      )
                    : island,
            ],
          );

      for (var index = 0; index < 30; index++) {
        loop.tick();
      }
      await Future<void>.delayed(Duration.zero);
      expect(gateway.decisionCalls, 1);

      // The board changes while Jev is pending. A fallback generated from the
      // request snapshot would still use strength 20 and be rejected as stale;
      // the current board should produce and apply strength 40.
      controller.state = controller.state.copyWith(
        islands: [
          for (final island in controller.state.islands)
            island.id == 0 ? island.copyWith(currentForces: 80) : island,
        ],
      );
      gateway.failure.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final after = container.read(gameControllerProvider);
      expect(
        after.movingForces.where((force) => force.faction == Faction.cpu),
        hasLength(1),
      );
      expect(after.movingForces.single.strength, 40);
    },
  );

  test(
    'holds a mixed spectator batch until the Very Hard response resolves',
    () async {
      final loop = ManualGameLoop();
      final gateway = _DelayedGateway();
      final playerStrategy = CpuStrategy(
        controlledFaction: Faction.player,
        timingRandom: _ZeroRandom(),
        qualityRandom: _ZeroRandom(),
        viewport: GameRules.defaultMapViewport,
      );
      final cpuStrategy = CpuStrategy(
        controlledFaction: Faction.cpu,
        timingRandom: _ZeroRandom(),
        qualityRandom: _ZeroRandom(),
        viewport: GameRules.defaultMapViewport,
      );
      final container = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          playerCpuStrategyProvider.overrideWithValue(playerStrategy),
          cpuStrategyProvider.overrideWithValue(cpuStrategy),
          veryHardCpuGatewayProvider.overrideWithValue(gateway),
        ],
      );
      final subscription = container.listen(gameControllerProvider, (_, __) {});
      addTearDown(container.dispose);
      addTearDown(subscription.close);

      final controller = container.read(gameControllerProvider.notifier);
      controller.selectGameMode(GameMode.cpuVsCpu);
      controller.selectPlayerCpuDifficulty(CpuDifficulty.veryHard);
      controller.selectCpuDifficulty(CpuDifficulty.hard);
      await controller.startGame();
      _completeCountdown(loop);

      final started = container.read(gameControllerProvider);
      controller.state = started.copyWith(
        islands: [
          for (final island in started.islands)
            switch (island.id) {
              0 => island.copyWith(
                faction: Faction.player,
                currentForces: 100,
                durability: 0,
                x: -0.8,
                y: 0,
              ),
              1 => island.copyWith(
                faction: Faction.cpu,
                currentForces: 10,
                durability: 0,
                x: 0.8,
                y: 0,
              ),
              2 => island.copyWith(
                faction: Faction.cpu,
                currentForces: 100,
                durability: 0,
                x: 0.7,
                y: 0,
              ),
              3 => island.copyWith(
                faction: Faction.player,
                currentForces: 10,
                durability: 0,
                x: -0.7,
                y: 0,
              ),
              _ => island,
            },
        ],
      );

      // Both profiles first become due at 1,500ms. The local Hard decision must
      // wait for the Very Hard response instead of getting a head start.
      for (var index = 0; index < 30; index++) {
        loop.tick();
      }
      await Future<void>.delayed(Duration.zero);
      expect(gateway.decisionCalls, 1);
      expect(container.read(gameControllerProvider).movingForces, isEmpty);

      final candidate = gateway.request
          .subjectFor(Faction.player)
          .candidates
          .first;
      gateway.response.complete(
        VeryHardDecisionResponse(
          requestId: gateway.request.requestId,
          candidateIdsByFaction: {Faction.player: candidate.id},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final after = container.read(gameControllerProvider);
      expect(after.movingForces, hasLength(2));
      expect(after.movingForces.map((force) => force.faction), [
        Faction.player,
        Faction.cpu,
      ]);
    },
  );
}
