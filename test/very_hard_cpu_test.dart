import 'dart:async';
import 'dart:convert';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/very_hard_cpu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _viewport = IslandMapViewport(width: 320, height: 320);

IslandState _island({
  required int id,
  required Faction faction,
  required int forces,
  IslandSize size = IslandSize.small,
}) {
  return IslandState(
    id: id,
    position: IslandPosition(x: id / 20, y: id / 30),
    faction: faction,
    size: size,
    currentForces: forces,
    durability: faction == Faction.neutral ? forces : 0,
    capacity: size.capacity,
  );
}

GameState _playing({
  required List<IslandState> islands,
  GameConfiguration configuration = GameConfiguration.initial,
}) {
  return GameState(
    phase: GamePhase.playing,
    elapsedMs: 1234,
    configuration: configuration,
    islands: islands,
  );
}

void main() {
  test('Very Hard profile keeps Hard timing in centralized constants', () {
    final profile = CpuDifficultyProfile.forDifficulty(CpuDifficulty.veryHard);

    expect(CpuDifficulty.values, contains(CpuDifficulty.veryHard));
    expect(
      profile.minDecisionIntervalMs,
      VeryHardCpuConfig.minDecisionIntervalMs,
    );
    expect(
      profile.maxDecisionIntervalMs,
      VeryHardCpuConfig.maxDecisionIntervalMs,
    );
    expect(profile.minDecisionIntervalMs, 1500);
    expect(profile.maxDecisionIntervalMs, 2750);
    expect(
      VeryHardCpuConfig.decisionTimeout,
      const Duration(milliseconds: 1200),
    );
    expect(
      VeryHardCpuConfig.minDecisionIntervalMs,
      lessThanOrEqualTo(VeryHardCpuConfig.maxDecisionIntervalMs),
    );
  });

  test('generates every legal source-destination action plus wait', () {
    final state = _playing(
      islands: [
        _island(id: 0, faction: Faction.cpu, forces: 20),
        _island(id: 1, faction: Faction.cpu, forces: 1),
        _island(id: 2, faction: Faction.player, forces: 10),
        _island(id: 3, faction: Faction.neutral, forces: 8),
      ],
    );

    final candidates = VeryHardCandidateGenerator(
      viewport: _viewport,
    ).generate(state, faction: Faction.cpu);

    expect(candidates, hasLength(4)); // 1 source * 3 destinations + wait
    expect(candidates.last.action, VeryHardAction.wait);
    expect(candidates.where((candidate) => candidate.isDispatch), hasLength(3));
    expect(candidates.map((candidate) => candidate.id).toSet(), hasLength(4));
    for (final candidate in candidates.where(
      (candidate) => candidate.isDispatch,
    )) {
      expect(candidate.decision!.strength, 10);
      expect(candidate.sourceIslandId, 0);
      expect(candidate.destinationIslandId, isNot(0));
    }
  });

  test('caps the maximum candidate count at 132 dispatches plus wait', () {
    final state = _playing(
      islands: [
        for (var id = 0; id < 12; id++)
          _island(id: id, faction: Faction.cpu, forces: 20),
      ],
    );

    final candidates = VeryHardCandidateGenerator(
      viewport: _viewport,
    ).generate(state, faction: Faction.cpu);

    expect(candidates, hasLength(133));
    expect(
      candidates.where((candidate) => candidate.isDispatch),
      hasLength(VeryHardCpuConfig.maxCandidatesPerFaction - 1),
    );
  });

  test('serializes bounded candidates without accepting a model or prompt', () {
    final state = _playing(
      islands: [
        _island(id: 0, faction: Faction.cpu, forces: 20),
        _island(id: 1, faction: Faction.player, forces: 10),
      ],
    );
    final request = VeryHardDecisionRequest.fromState(
      state,
      matchId: 'match-1',
      requestId: 'request-1',
      factions: const [Faction.cpu],
      viewport: _viewport,
    );
    final json = request.toJson();

    expect(json['schemaVersion'], VeryHardCpuConfig.schemaVersion);
    expect(json['kind'], 'decision');
    expect(json.containsKey('model'), isFalse);
    expect(json.containsKey('prompt'), isFalse);
    expect(json['subjects'], hasLength(1));
    expect((json['subjects'] as List).single, containsPair('faction', 'cpu'));
  });

  test(
    'rejects a model response for an id not in the submitted candidates',
    () {
      final state = _playing(
        islands: [
          _island(id: 0, faction: Faction.cpu, forces: 20),
          _island(id: 1, faction: Faction.player, forces: 10),
        ],
      );
      final request = VeryHardDecisionRequest.fromState(
        state,
        matchId: 'match-1',
        requestId: 'request-1',
        factions: const [Faction.cpu],
        viewport: _viewport,
      );

      expect(
        () => VeryHardDecisionResponse.fromJson({
          'schemaVersion': VeryHardCpuConfig.schemaVersion,
          'requestId': 'request-1',
          'decisions': [
            {'faction': 'cpu', 'candidateId': 'unknown'},
          ],
        }, request: request),
        throwsA(isA<VeryHardCpuProtocolException>()),
      );
    },
  );

  test('parses and validates the resolved model diagnostic separately', () {
    final state = _playing(
      islands: [
        _island(id: 0, faction: Faction.cpu, forces: 20),
        _island(id: 1, faction: Faction.player, forces: 10),
      ],
    );
    final request = VeryHardDecisionRequest.fromState(
      state,
      matchId: 'match-1',
      requestId: 'request-1',
      factions: const [Faction.cpu],
      viewport: _viewport,
    );

    final response = VeryHardDecisionResponse.fromJson({
      'schemaVersion': VeryHardCpuConfig.schemaVersion,
      'requestId': 'request-1',
      'decisions': [
        {
          'faction': 'cpu',
          'candidateId': request.subjects.single.candidates.first.id,
        },
      ],
      'diagnostics': {
        'model': VeryHardCpuConfig.model,
        'resolvedModel': 'jev/provider-v1',
        'promptVersion': VeryHardCpuConfig.promptVersion,
        'latencyMs': 12,
      },
    }, request: request);

    expect(response.model, VeryHardCpuConfig.model);
    expect(response.resolvedModel, 'jev/provider-v1');

    expect(
      () => VeryHardDecisionResponse.fromJson({
        'schemaVersion': VeryHardCpuConfig.schemaVersion,
        'requestId': 'request-1',
        'decisions': [
          {
            'faction': 'cpu',
            'candidateId': request.subjects.single.candidates.first.id,
          },
        ],
        'diagnostics': {'resolvedModel': 42},
      }, request: request),
      throwsA(isA<VeryHardCpuProtocolException>()),
    );
  });

  test('HTTP gateway adds configured Preview protection headers', () async {
    Map<String, String>? capturedHeaders;
    final gateway = HttpVeryHardCpuGateway(
      endpoint: Uri.parse('https://preview.example/api/v1/cpu/very-hard'),
      requestHeaders: const {
        'x-vercel-protection-bypass': 'local-benchmark-secret',
      },
      client: MockClient((request) async {
        capturedHeaders = request.headers;
        final body = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'schemaVersion': VeryHardCpuConfig.schemaVersion,
            'kind': 'preflight',
            'requestId': body['requestId'],
            'available': true,
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(gateway.close);

    final result = await gateway.preflight(matchId: 'match-1');

    expect(result.available, isTrue);
    expect(
      capturedHeaders!['x-vercel-protection-bypass'],
      'local-benchmark-secret',
    );
    expect(capturedHeaders!['content-type'], 'application/json');
  });

  test('evaluates a fallback against the caller latest state', () async {
    final request = Completer<VeryHardDecisionResponse>();
    final coordinator = VeryHardCpuCoordinator(
      gateway: FakeVeryHardCpuGateway(decision: (_) => request.future),
      timeout: const Duration(seconds: 1),
    );
    var latest = _playing(
      islands: [
        _island(id: 0, faction: Faction.cpu, forces: 20),
        _island(id: 1, faction: Faction.player, forces: 10),
      ],
    );
    final fallbackStrategy = CpuStrategy(viewport: _viewport);
    final future = coordinator.decide(
      state: latest,
      matchId: 'match-1',
      factions: const [Faction.cpu],
      fallback: (faction) =>
          fallbackStrategy.decide(latest, difficulty: CpuDifficulty.hard),
    );

    latest = latest.copyWith(
      islands: [
        latest.islands.first.copyWith(currentForces: 40),
        latest.islands[1],
      ],
    );
    request.completeError(StateError('offline'));
    final outcome = await future;

    expect(outcome.usedFallback, isTrue);
    expect(outcome.decisions[Faction.cpu]!.strength, 20);
  });

  test('does not apply a late result after the request timeout', () async {
    final request = Completer<VeryHardDecisionResponse>();
    final coordinator = VeryHardCpuCoordinator(
      gateway: FakeVeryHardCpuGateway(decision: (_) => request.future),
      timeout: const Duration(milliseconds: 1),
    );

    final state = _playing(
      islands: [
        _island(id: 0, faction: Faction.cpu, forces: 20),
        _island(id: 1, faction: Faction.player, forces: 10),
      ],
    );
    final outcome = await coordinator.decide(
      state: state,
      matchId: 'match-1',
      factions: const [Faction.cpu],
      fallback: (faction) => null,
    );

    expect(outcome.usedFallback, isTrue);
    expect(outcome.decisions, containsPair(Faction.cpu, null));
    expect(coordinator.hasInFlightRequest, isTrue);
    final skipped = await coordinator.decide(
      state: state,
      matchId: 'match-1',
      factions: const [Faction.cpu],
      fallback: (faction) => null,
    );
    expect(skipped.skipped, isTrue);
    expect(coordinator.hasInFlightRequest, isTrue);
    request.completeError(StateError('late response'));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.hasInFlightRequest, isFalse);
  });

  test(
    'does not start a second request while one request is in flight',
    () async {
      final request = Completer<VeryHardDecisionResponse>();
      var calls = 0;
      final thisRequest = request;
      final coordinator = VeryHardCpuCoordinator(
        gateway: FakeVeryHardCpuGateway(
          decision: (request) {
            calls += 1;
            return thisRequest.future;
          },
        ),
        timeout: const Duration(seconds: 1),
      );
      final state = _playing(
        islands: [
          _island(id: 0, faction: Faction.cpu, forces: 20),
          _island(id: 1, faction: Faction.player, forces: 10),
        ],
      );

      final first = coordinator.decide(
        state: state,
        matchId: 'match-1',
        factions: const [Faction.cpu],
        fallback: (faction) => null,
      );
      final second = coordinator.decide(
        state: state,
        matchId: 'match-1',
        factions: const [Faction.cpu],
        fallback: (faction) => null,
      );

      expect(calls, 1);
      request.complete(
        VeryHardDecisionResponse(
          requestId: 'request-1',
          candidateIdsByFaction: const {},
        ),
      );
      await first;
      await second;
    },
  );
}

final class FakeVeryHardCpuGateway implements VeryHardCpuGateway {
  FakeVeryHardCpuGateway({required this.decision});

  final Future<VeryHardDecisionResponse> Function(
    VeryHardDecisionRequest request,
  )
  decision;

  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) async {
    return const VeryHardPreflightResult.available();
  }

  @override
  Future<VeryHardDecisionResponse> decide(VeryHardDecisionRequest request) {
    return decision(request);
  }
}
