import 'dart:math';

import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/movement_timing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class FixedClock extends GameClock {
  int value = 0;

  @override
  int nowMs() => value;
}

void main() {
  const rules = GameRules();

  test('uses one canonical ten-second diagonal duration and aliases', () {
    expect(MovementTiming.screenDiagonalDurationMs, 10000);
    expect(GameRules.movementDurationMs, 10000);
    expect(MovingForce.movementDefaultDurationMs, 10000);
    expect(MovingForce.movementDefaultArrivalTimeMs, 10000);
  });

  test('configuration exposes the supported counts and default selection', () {
    expect(GameConfiguration.allowedIslandCounts, [6, 8, 10, 12]);
    expect(GameConfiguration.initial.totalIslandCount, 10);
    expect(GameConfiguration.initial.gameMode, GameMode.playerVsCpu);
    expect(GameConfiguration.initial.playerCpuDifficulty, CpuDifficulty.normal);
    expect(GameConfiguration.initial.cpuDifficulty, CpuDifficulty.normal);
    expect(GameConfiguration(islandCount: 6).totalIslandCount, 6);
    expect(
      () => GameConfiguration(totalIslandCount: 7),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('configuration copy and equality include CPU difficulty', () {
    final easy = GameConfiguration(
      totalIslandCount: 8,
      cpuDifficulty: CpuDifficulty.easy,
    );
    final hard = easy.copyWith(cpuDifficulty: CpuDifficulty.hard);

    expect(easy.totalIslandCount, 8);
    expect(easy.cpuDifficulty, CpuDifficulty.easy);
    expect(hard.totalIslandCount, 8);
    expect(hard.cpuDifficulty, CpuDifficulty.hard);
    expect(easy, isNot(hard));
    expect(easy.hashCode, isNot(hard.hashCode));
    expect(
      easy.copyWith(totalIslandCount: 12),
      GameConfiguration(
        totalIslandCount: 12,
        cpuDifficulty: CpuDifficulty.easy,
      ),
    );
  });

  test(
    'configuration copy and equality include mode and both difficulties',
    () {
      final spectator = GameConfiguration(
        totalIslandCount: 8,
        gameMode: GameMode.cpuVsCpu,
        playerCpuDifficulty: CpuDifficulty.hard,
        cpuDifficulty: CpuDifficulty.easy,
      );
      final standard = spectator.copyWith(gameMode: GameMode.playerVsCpu);

      expect(standard.gameMode, GameMode.playerVsCpu);
      expect(standard.playerCpuDifficulty, CpuDifficulty.hard);
      expect(standard.cpuDifficulty, CpuDifficulty.easy);
      expect(standard, isNot(spectator));
      expect(standard.hashCode, isNot(spectator.hashCode));
    },
  );

  test('game modes expose human and CPU factions', () {
    expect(GameMode.playerVsCpu.humanFactions, [Faction.player]);
    expect(GameMode.playerVsCpu.cpuFactions, [Faction.cpu]);
    expect(GameMode.playerVsPlayer.humanFactions, [
      Faction.player,
      Faction.cpu,
    ]);
    expect(GameMode.playerVsPlayer.cpuFactions, isEmpty);
    expect(GameMode.cpuVsCpu.humanFactions, isEmpty);
    expect(GameMode.cpuVsCpu.cpuFactions, [Faction.player, Faction.cpu]);
    expect(GameMode.playerVsPlayer.usesVersusPresentation, isTrue);
    expect(GameMode.playerVsCpu.usesVersusPresentation, isFalse);
  });

  test(
    'configuration copy retains hidden CPU difficulties in local two-player',
    () {
      final local = GameConfiguration(
        totalIslandCount: 8,
        gameMode: GameMode.playerVsPlayer,
        playerCpuDifficulty: CpuDifficulty.hard,
        cpuDifficulty: CpuDifficulty.easy,
      );
      final restored = local.copyWith(gameMode: GameMode.playerVsCpu);

      expect(local.gameMode, GameMode.playerVsPlayer);
      expect(restored.playerCpuDifficulty, CpuDifficulty.hard);
      expect(restored.cpuDifficulty, CpuDifficulty.easy);
    },
  );

  test('island canDispatchAs is faction-specific', () {
    const player = IslandState(
      id: 0,
      faction: Faction.player,
      currentForces: 10,
      size: IslandSize.headquarters,
      capacity: 200,
    );
    const cpu = IslandState(
      id: 1,
      faction: Faction.cpu,
      currentForces: 10,
      size: IslandSize.headquarters,
      capacity: 200,
    );
    expect(player.canDispatch, isTrue);
    expect(player.canDispatchAs(Faction.player), isTrue);
    expect(player.canDispatchAs(Faction.cpu), isFalse);
    expect(cpu.canDispatch, isFalse);
    expect(cpu.canDispatchAs(Faction.cpu), isTrue);
    expect(cpu.canDispatchAs(Faction.neutral), isFalse);
  });

  test('game state stores independent player and opponent selections', () {
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      selectedIslandId: 0,
      opponentSelectedIslandId: 1,
      islands: const [
        IslandState(id: 0, faction: Faction.player, currentForces: 10),
        IslandState(id: 1, faction: Faction.cpu, currentForces: 10),
      ],
    );
    expect(state.selectedIslandIdFor(Faction.player), 0);
    expect(state.selectedIslandIdFor(Faction.cpu), 1);
    expect(state.clearSelection().opponentSelectedIslandId, 1);
    expect(state.clearOpponentSelection().selectedIslandId, 0);
    expect(state.clearAllSelections().selectedIslandId, isNull);
    expect(state.clearAllSelections().opponentSelectedIslandId, isNull);
  });

  test('invalidates only the opponent selection when 2P source is lost', () {
    const player = IslandState(
      id: 0,
      faction: Faction.player,
      currentForces: 10,
      size: IslandSize.headquarters,
      capacity: 200,
    );
    const cpu = IslandState(
      id: 1,
      faction: Faction.cpu,
      currentForces: 10,
      size: IslandSize.headquarters,
      capacity: 200,
    );
    final captured = GameState(
      phase: GamePhase.playing,
      elapsedMs: 100,
      selectedIslandId: 0,
      opponentSelectedIslandId: 1,
      islands: [
        player,
        cpu.copyWith(faction: Faction.player),
      ],
    );
    final next = const GameRules().tick(captured, deltaMs: 0);
    expect(next.selectedIslandId, 0);
    expect(next.opponentSelectedIslandId, isNull);
  });

  test('viewport island rect contains its center and not a far point', () {
    const viewport = IslandMapViewport(width: 390, height: 844);
    final hq = rules.initialState(viewport: viewport).islands.first;
    final rect = viewport.rectFor(hq);
    expect(
      rect.containsPoint(
        (rect.left + rect.right) / 2,
        (rect.top + rect.bottom) / 2,
      ),
      isTrue,
    );
    expect(rect.containsPoint(0, 0), isFalse);
  });

  test('configuration copy retains Very Easy CPU difficulty', () {
    final veryEasy = GameConfiguration(cpuDifficulty: CpuDifficulty.veryEasy);
    final updated = veryEasy.copyWith(totalIslandCount: 12);

    expect(updated.totalIslandCount, 12);
    expect(updated.cpuDifficulty, CpuDifficulty.veryEasy);
    expect(
      updated,
      GameConfiguration(
        totalIslandCount: 12,
        cpuDifficulty: CpuDifficulty.veryEasy,
      ),
    );
    expect(
      updated,
      isNot(
        GameConfiguration(
          totalIslandCount: 12,
          cpuDifficulty: CpuDifficulty.easy,
        ),
      ),
    );
    expect(
      updated.hashCode,
      isNot(
        GameConfiguration(
          totalIslandCount: 12,
          cpuDifficulty: CpuDifficulty.easy,
        ).hashCode,
      ),
    );
  });

  test('value objects provide immutable copy updates', () {
    const position = IslandPosition(x: 0.25, y: -0.5);
    const island = IslandState(
      id: 4,
      position: position,
      faction: Faction.player,
      size: IslandSize.medium,
      currentForces: 12,
      capacity: 100,
    );

    final updated = island.copyWith(currentForces: 20);

    expect(island.currentForces, 12);
    expect(updated.currentForces, 20);
    expect(updated.position, position);
    expect(updated.capacity, 100);
    expect(IslandSize.medium.capacity, 100);
  });

  test(
    'islands and moving forces expose current values and action availability',
    () {
      const player = IslandState(
        id: 0,
        faction: Faction.player,
        currentForces: 8,
        capacity: 50,
      );
      const exhausted = IslandState(
        id: 1,
        faction: Faction.player,
        currentForces: 1,
        capacity: 50,
      );
      const neutral = IslandState(
        id: 2,
        faction: Faction.neutral,
        durability: 7,
        currentForces: 0,
        capacity: 50,
      );
      const force = MovingForce(
        id: 3,
        faction: Faction.cpu,
        sourceIslandId: 1,
        destinationIslandId: 0,
        strength: 4,
      );

      expect(player.currentValue, 8);
      expect(player.canDispatch, isTrue);
      expect(player.actionAvailable, isTrue);
      expect(exhausted.canDispatch, isFalse);
      expect(neutral.currentValue, 7);
      expect(neutral.actionAvailable, isFalse);
      expect(force.currentValue, 4);
      expect(force.actionAvailable, isFalse);
      expect(force.isTappable, isFalse);
    },
  );

  test(
    'initial neutral island composition carries typed durability values',
    () {
      const expectedSizes = <int, List<IslandSize>>{
        6: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
        ],
        8: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.large,
          IslandSize.large,
        ],
        10: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.large,
          IslandSize.large,
        ],
        12: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.large,
          IslandSize.large,
        ],
      };

      for (final entry in expectedSizes.entries) {
        final islands = rules
            .initialState(
              configuration: GameConfiguration(totalIslandCount: entry.key),
              random: Random(entry.key),
            )
            .islands
            .skip(2)
            .toList();

        expect(islands.map((island) => island.size), entry.value);
        for (final island in islands) {
          expect(island.durability, island.size.neutralDurability);
          expect(island.capacity, island.size.capacity);
        }
      }
    },
  );

  test('generated maps keep fixed headquarters and pair neutral islands', () {
    const expectedSizes = <int, Map<IslandSize, int>>{
      6: {IslandSize.small: 2, IslandSize.medium: 2},
      8: {IslandSize.small: 2, IslandSize.medium: 2, IslandSize.large: 2},
      10: {IslandSize.small: 4, IslandSize.medium: 2, IslandSize.large: 2},
      12: {IslandSize.small: 4, IslandSize.medium: 4, IslandSize.large: 2},
    };

    for (final entry in expectedSizes.entries) {
      final islands = rules.generateIslands(
        configuration: GameConfiguration(totalIslandCount: entry.key),
        random: Random(entry.key),
      );
      expect(islands, hasLength(entry.key));
      expect(islands[0].position, const IslandPosition(x: 1, y: 1));
      expect(islands[0].faction, Faction.player);
      expect(islands[0].currentForces, 100);
      expect(islands[0].capacity, 200);
      expect(islands[1].position, const IslandPosition(x: -1, y: -1));
      expect(islands[1].faction, Faction.cpu);
      expect(islands[1].currentForces, 100);
      expect(islands[1].capacity, 200);

      final counts = <IslandSize, int>{};
      for (var index = 2; index < islands.length; index += 2) {
        final first = islands[index];
        final second = islands[index + 1];
        counts[first.size] = (counts[first.size] ?? 0) + 2;
        expect(second.size, first.size);
        expect(second.position.x, closeTo(-first.position.x, 1e-12));
        expect(second.position.y, closeTo(-first.position.y, 1e-12));
        expect(second.durability, first.durability);
        expect(second.capacity, first.capacity);
      }
      expect(counts, entry.value);
    }
  });

  test('headquarters match the tactical chart HUD-safe anchors', () {
    final islands = rules.generateIslands(
      configuration: GameConfiguration(totalIslandCount: 10),
      random: Random(1),
      viewport: GameRules.referenceMapViewport,
    );

    final playerRect = GameRules.referenceMapViewport.rectFor(islands[0]);
    final cpuRect = GameRules.referenceMapViewport.rectFor(islands[1]);

    expect(cpuRect.left, closeTo(16, 1e-9));
    expect(cpuRect.top, closeTo(48, 1e-9));
    expect(playerRect.right, closeTo(374, 1e-9));
    expect(playerRect.bottom, closeTo(796, 1e-9));
    expect(islands[0].x, closeTo(-islands[1].x, 1e-12));
    expect(islands[0].y, closeTo(-islands[1].y, 1e-12));
  });

  test('generated maps stay in viewport bounds and do not overlap', () {
    const viewports = <IslandMapViewport>[
      IslandMapViewport(width: 320, height: 320),
      IslandMapViewport(width: 320, height: 480),
      IslandMapViewport(width: 320, height: 568),
      IslandMapViewport(width: 390, height: 844),
      IslandMapViewport(width: 430, height: 932),
    ];
    for (final total in GameConfiguration.allowedIslandCounts) {
      for (var seed = 0; seed < 20; seed++) {
        for (final viewport in viewports) {
          final generated = rules.tryGenerateIslands(
            configuration: GameConfiguration(totalIslandCount: total),
            random: Random(seed),
            viewport: viewport,
          );
          expect(
            generated,
            isNotNull,
            reason:
                '$total islands, seed $seed, '
                '${viewport.width}x${viewport.height}',
          );
          final islands = generated!;
          for (final island in islands) {
            expect(island.x, inInclusiveRange(-1.0, 1.0));
            expect(island.y, inInclusiveRange(-1.0, 1.0));
          }
          final rectangles = [
            for (final island in islands) viewport.rectFor(island),
          ];
          for (var index = 0; index < rectangles.length; index++) {
            expect(
              rectangles[index].isWithin(viewport),
              isTrue,
              reason: 'island ${islands[index].id} is outside the safe area',
            );
            expect(
              rectangles[index].overlaps(viewport.topRightControlExclusion),
              isFalse,
              reason:
                  'island ${islands[index].id} overlaps the pause control '
                  'exclusion area',
            );
          }
          for (
            var firstIndex = 0;
            firstIndex < rectangles.length;
            firstIndex++
          ) {
            for (
              var secondIndex = firstIndex + 1;
              secondIndex < rectangles.length;
              secondIndex++
            ) {
              expect(
                rectangles[firstIndex].overlaps(rectangles[secondIndex]),
                isFalse,
                reason:
                    'islands ${islands[firstIndex].id} and '
                    '${islands[secondIndex].id} overlap',
              );
            }
          }
        }
      }
    }
  });

  test('map generation reserves the renderer pause control envelope', () {
    const viewport = IslandMapViewport(width: 402, height: 874);
    final exclusion = viewport.topRightControlExclusion;
    expect(exclusion.left, 282);
    expect(exclusion.top, 0);
    expect(exclusion.right, 402);
    expect(exclusion.bottom, 72);

    const candidate = IslandState(
      id: 2,
      position: IslandPosition(x: 0.7, y: -0.9),
      faction: Faction.neutral,
      size: IslandSize.small,
      durability: 10,
      capacity: 50,
    );
    expect(viewport.rectFor(candidate).overlaps(exclusion), isTrue);

    for (final total in GameConfiguration.allowedIslandCounts) {
      for (var seed = 0; seed < 100; seed++) {
        final islands = rules.generateIslands(
          configuration: GameConfiguration(totalIslandCount: total),
          random: Random(seed),
          viewport: viewport,
        );
        for (final island in islands) {
          expect(
            viewport.rectFor(island).overlaps(exclusion),
            isFalse,
            reason: 'seed $seed island ${island.id} overlaps pause control',
          );
        }
        for (var index = 2; index < islands.length; index += 2) {
          expect(islands[index + 1].x, closeTo(-islands[index].x, 1e-12));
          expect(islands[index + 1].y, closeTo(-islands[index].y, 1e-12));
        }
      }
    }
  });

  test(
    'viewport rectangles catch the tall-screen headquarters overlap case',
    () {
      const viewport = IslandMapViewport(width: 390, height: 844);
      const headquarters = IslandState(
        id: 0,
        position: IslandPosition(x: 1, y: 1),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 100,
        capacity: 200,
      );
      const small = IslandState(
        id: 2,
        position: IslandPosition(x: 0.66, y: 0.89),
        faction: Faction.neutral,
        size: IslandSize.small,
        durability: 10,
        capacity: 50,
      );

      final headquartersRect = viewport.rectFor(headquarters);
      final smallRect = viewport.rectFor(small);
      expect(headquartersRect.left, closeTo(290, 1e-12));
      expect(headquartersRect.top, closeTo(744, 1e-12));
      expect(smallRect.left, closeTo(282.2, 1e-12));
      expect(smallRect.top, closeTo(750.33, 1e-12));
      expect(headquartersRect.overlaps(smallRect), isTrue);
      expect(
        sqrt(
          pow(headquarters.x - small.x, 2) + pow(headquarters.y - small.y, 2),
        ),
        greaterThan(0.34),
        reason: 'the old normalized-radius check would incorrectly accept this',
      );
    },
  );

  test('default envelope rejects the short-screen symmetric overlap case', () {
    const viewport = GameRules.defaultMapViewport;
    const first = IslandState(
      id: 2,
      position: IslandPosition(x: 0, y: 0.105),
      faction: Faction.neutral,
      size: IslandSize.small,
      durability: 10,
      capacity: 50,
    );
    const counterpart = IslandState(
      id: 3,
      position: IslandPosition(x: 0, y: -0.105),
      faction: Faction.neutral,
      size: IslandSize.small,
      durability: 10,
      capacity: 50,
    );

    expect(
      GameRules.islandRectanglesOverlap(first, counterpart, viewport),
      isTrue,
    );
    final islands = rules.generateIslands(
      configuration: GameConfiguration(totalIslandCount: 6),
      random: Random(20),
    );
    final rectangles = [for (final island in islands) viewport.rectFor(island)];
    for (var firstIndex = 0; firstIndex < rectangles.length; firstIndex++) {
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < rectangles.length;
        secondIndex++
      ) {
        expect(
          rectangles[firstIndex].overlaps(rectangles[secondIndex]),
          isFalse,
        );
      }
    }
  });

  test('map generation is reproducible for a seed and varies across seeds', () {
    final first = rules.generateIslands(random: Random(123));
    final second = rules.generateIslands(random: Random(123));
    final different = rules.generateIslands(random: Random(124));

    expect(first, second);
    expect(
      first.skip(2).map((island) => island.position),
      isNot(orderedEquals(different.skip(2).map((island) => island.position))),
    );
  });

  test(
    'map generation returns a bounded failure when attempts are exhausted',
    () {
      expect(
        rules.tryGenerateIslands(random: Random(1), maxAttempts: 0),
        isNull,
      );
      expect(
        () => rules.generateIslands(random: Random(1), maxAttempts: 0),
        throwsA(isA<StateError>()),
      );
      expect(
        rules.tryGenerateIslands(
          random: Random(1),
          viewport: const IslandMapViewport(width: 80, height: 80),
        ),
        isNull,
      );
    },
  );

  test('state holds multiple typed moving forces immutably', () {
    const forces = [
      MovingForce(
        id: 1,
        faction: Faction.player,
        sourceIslandId: 0,
        destinationIslandId: 2,
        strength: 10,
      ),
      MovingForce(
        id: 2,
        faction: Faction.cpu,
        sourceIslandId: 1,
        destinationIslandId: 3,
        strength: 12,
      ),
    ];
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      movingForces: forces,
    );

    expect(state.movingForces, hasLength(2));
    expect(state.movingForces, isA<List<MovingForce>>());
    expect(() => state.movingForces.add(forces.first), throwsUnsupportedError);
    expect(state.movement, forces.first);
  });

  test('valid and invalid phase transitions are explicit and immutable', () {
    final initial = rules.initialState(random: Random(3));
    expect(
      rules.canTransition(GamePhase.configuration, GamePhase.startCountdown),
      isTrue,
    );
    expect(
      rules.canTransition(GamePhase.configuration, GamePhase.paused),
      isFalse,
    );

    final countdown = rules.startCountdown(initial, durationMs: 100);
    expect(countdown.phase, GamePhase.startCountdown);
    expect(countdown.countdownRemainingMs, 100);
    expect(rules.pause(initial), same(initial));
    expect(rules.tick(countdown, deltaMs: 99).phase, GamePhase.startCountdown);
    expect(rules.tick(countdown, deltaMs: 100).phase, GamePhase.playing);
  });

  test('phase transition table and result invariant agree for every phase', () {
    final initial = rules.initialState(random: Random(4));
    final playing = initial.copyWith(phase: GamePhase.playing);
    final paused = rules.pause(playing);
    final resuming = rules.resumeCountdown(paused, durationMs: 100);
    final result = const GameResult.draw(elapsedMs: 10);

    const validTransitions = <GamePhase, Set<GamePhase>>{
      GamePhase.configuration: {
        GamePhase.configuration,
        GamePhase.startCountdown,
      },
      GamePhase.startCountdown: {
        GamePhase.startCountdown,
        GamePhase.playing,
        GamePhase.paused,
      },
      GamePhase.playing: {
        GamePhase.playing,
        GamePhase.paused,
        GamePhase.result,
      },
      GamePhase.paused: {
        GamePhase.paused,
        GamePhase.resumeCountdown,
        GamePhase.configuration,
      },
      GamePhase.resumeCountdown: {
        GamePhase.resumeCountdown,
        GamePhase.playing,
        GamePhase.paused,
      },
      GamePhase.result: {GamePhase.result, GamePhase.configuration},
    };
    for (final from in GamePhase.values) {
      for (final to in GamePhase.values) {
        expect(
          rules.canTransition(from, to),
          validTransitions[from]!.contains(to),
          reason: '$from -> $to',
        );
      }
    }

    expect(rules.transitionTo(playing, GamePhase.result), same(playing));
    expect(rules.transitionTo(playing, GamePhase.playing), same(playing));
    final finished = rules.finish(playing, result);
    expect(finished.phase, GamePhase.result);
    expect(finished.result, result);
    expect(rules.transitionTo(finished, GamePhase.result), same(finished));
    expect(rules.finish(paused, result), same(paused));
    expect(rules.finish(resuming, result), same(resuming));
    expect(
      rules.transitionTo(finished, GamePhase.configuration).result,
      isNull,
    );
    expect(
      () => GameState(phase: GamePhase.result, elapsedMs: 0),
      throwsStateError,
    );
  });

  test(
    'returns a bounded failure when fixed headquarters cannot be separated',
    () {
      const viewport = IslandMapViewport(width: 180, height: 180);

      expect(
        rules.tryGenerateIslands(
          configuration: GameConfiguration(totalIslandCount: 6),
          random: Random(1),
          viewport: viewport,
        ),
        isNull,
      );
      expect(
        () => rules.generateIslands(
          configuration: GameConfiguration(totalIslandCount: 6),
          random: Random(1),
          viewport: viewport,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('countdown self-transitions preserve remaining time', () {
    final initial = rules.initialState(random: Random(5));
    final countdown = rules.startCountdown(initial, durationMs: 1000);
    final partialStart = rules.tick(countdown, deltaMs: 400);
    final paused = rules.pause(rules.tick(countdown, deltaMs: 1000));
    final resume = rules.resumeCountdown(paused, durationMs: 1200);
    final partialResume = rules.tick(resume, deltaMs: 500);

    expect(partialStart.countdownRemainingMs, 600);
    expect(
      rules.transitionTo(partialStart, GamePhase.startCountdown),
      same(partialStart),
    );
    expect(partialResume.countdownRemainingMs, 700);
    expect(
      rules.transitionTo(partialResume, GamePhase.resumeCountdown),
      same(partialResume),
    );
  });

  test(
    'fixed random seed reproduces initial state and fixed time reproduces ticks',
    () {
      final first = rules.initialState(random: Random(99));
      final second = rules.initialState(random: Random(99));

      expect(first, second);

      final playing = rules.tick(
        rules.startCountdown(first, durationMs: 0),
        deltaMs: 0,
      );
      final firstTick = rules.tick(playing, deltaMs: 1250);
      final secondTick = rules.tick(playing, deltaMs: 1250);

      expect(playing.phase, GamePhase.playing);
      expect(firstTick, secondTick);
      expect(firstTick.elapsedMs, 1250);
      expect(firstTick.islands.first.currentForces, 101);
    },
  );

  test(
    'grows player and CPU islands but never neutral durability or forces',
    () {
      const playerIsland = IslandState(
        id: 0,
        faction: Faction.player,
        size: IslandSize.small,
        currentForces: 10,
      );
      const cpuIsland = IslandState(
        id: 1,
        faction: Faction.cpu,
        size: IslandSize.medium,
        currentForces: 20,
      );
      const neutralIsland = IslandState(
        id: 2,
        faction: Faction.neutral,
        size: IslandSize.large,
        currentForces: 7,
        durability: 30,
      );
      final state = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [playerIsland, cpuIsland, neutralIsland],
      );

      final next = rules.tick(state, deltaMs: 1000);

      expect(next.islands[0].currentForces, 11);
      expect(next.islands[1].currentForces, 21);
      expect(next.islands[2].currentForces, 7);
      expect(next.islands[2].durability, 30);
    },
  );

  test('stops growth at the size and headquarters capacity', () {
    const islands = [
      IslandState(
        id: 0,
        faction: Faction.player,
        size: IslandSize.small,
        currentForces: 49,
      ),
      IslandState(
        id: 1,
        faction: Faction.cpu,
        size: IslandSize.medium,
        currentForces: 99,
      ),
      IslandState(
        id: 2,
        faction: Faction.player,
        size: IslandSize.large,
        currentForces: 149,
      ),
      IslandState(
        id: 3,
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 199,
      ),
      IslandState(
        id: 4,
        faction: Faction.player,
        size: IslandSize.small,
        currentForces: 50,
      ),
      IslandState(
        id: 5,
        faction: Faction.cpu,
        size: IslandSize.medium,
        currentForces: 100,
      ),
      IslandState(
        id: 6,
        faction: Faction.player,
        size: IslandSize.large,
        currentForces: 150,
      ),
      IslandState(
        id: 7,
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 200,
      ),
    ];
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: islands,
    );

    final next = rules.tick(state, deltaMs: 1000);

    expect(
      next.islands.map((island) => island.currentForces),
      orderedEquals([50, 100, 150, 200, 50, 100, 150, 200]),
    );
    expect(
      next.islands.map((island) => island.capacity),
      orderedEquals([50, 100, 150, 200, 50, 100, 150, 200]),
    );
  });

  test('counts one-second boundaries at 999, 1000, and 1001 milliseconds', () {
    const island = IslandState(
      id: 0,
      faction: Faction.player,
      size: IslandSize.small,
      currentForces: 0,
    );
    const cpu = IslandState(
      id: 1,
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 0,
    );
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: const [island, cpu],
    );

    final beforeBoundary = rules.tick(state, deltaMs: 999);
    expect(beforeBoundary.elapsedMs, 999);
    expect(beforeBoundary.islands.first.currentForces, 0);

    final atBoundary = rules.tick(beforeBoundary, deltaMs: 1);
    expect(atBoundary.elapsedMs, 1000);
    expect(atBoundary.islands.first.currentForces, 1);

    final afterBoundary = rules.tick(atBoundary, deltaMs: 1);
    expect(afterBoundary.elapsedMs, 1001);
    expect(afterBoundary.islands.first.currentForces, 1);
  });

  test('preserves every crossed growth boundary in a long tick', () {
    const island = IslandState(
      id: 0,
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 0,
    );
    const cpu = IslandState(
      id: 1,
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 0,
    );
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: const [island, cpu],
    );

    final next = rules.tick(state, deltaMs: 3500);

    expect(next.elapsedMs, 3500);
    expect(next.islands.first.currentForces, 3);
  });

  test('applies growth before an arrival at the same timestamp', () {
    const source = IslandState(
      id: 0,
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 20,
      position: IslandPosition(x: -1, y: 0),
    );
    const target = IslandState(
      id: 1,
      faction: Faction.player,
      size: IslandSize.small,
      currentForces: 10,
      position: IslandPosition(x: 1, y: 0),
    );
    const force = MovingForce(
      id: 0,
      faction: Faction.player,
      sourceIslandId: 0,
      destinationIslandId: 1,
      strength: 5,
      departureTimeMs: 0,
      arrivalTimeMs: 1000,
      durationMs: 1000,
    );
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: const [source, target],
      movingForces: const [force],
    );

    final next = rules.tick(state, deltaMs: 1000);

    expect(next.movingForces, isEmpty);
    expect(next.islands[1].currentForces, 16);
  });

  test('does not advance game time or troops outside the playing phase', () {
    const island = IslandState(
      id: 0,
      faction: Faction.player,
      size: IslandSize.small,
      currentForces: 10,
    );
    final configuration = GameState(
      phase: GamePhase.configuration,
      elapsedMs: 0,
      islands: const [island],
    );
    final countdown = rules.startCountdown(configuration, durationMs: 1000);
    final paused = configuration.copyWith(phase: GamePhase.paused);
    final resumeCountdown = rules.resumeCountdown(paused, durationMs: 1000);
    final result = configuration.copyWith(
      phase: GamePhase.result,
      result: const GameResult.draw(elapsedMs: 0),
    );

    for (final state in [
      configuration,
      countdown,
      paused,
      resumeCountdown,
      result,
    ]) {
      final next = rules.tick(state, deltaMs: 2000);
      expect(next.elapsedMs, state.elapsedMs, reason: state.phase.name);
      expect(
        next.islands.map((island) => island.currentForces),
        orderedEquals(state.islands.map((island) => island.currentForces)),
        reason: state.phase.name,
      );
    }
  });

  test('a moving force advances by time and arrives deterministically', () {
    const source = IslandState(
      id: 0,
      position: IslandPosition(x: -1, y: -1),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 40,
      capacity: 200,
    );
    const target = IslandState(
      id: 1,
      position: IslandPosition(x: 1, y: 1),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 10,
      capacity: 200,
    );
    const cpu = IslandState(
      id: 2,
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 0,
      capacity: 200,
    );
    final force = rules.createMovingForce(
      id: 0,
      faction: Faction.player,
      source: source,
      destination: target,
      strength: 15,
    );
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: [source, target, cpu],
      movingForces: [force],
    );

    final halfway = rules.tick(state, deltaMs: force.durationMs ~/ 2);
    expect(halfway.movingForces, hasLength(1));
    expect(halfway.movingForces.single.progress, closeTo(0.5, 0.01));

    final arrived = rules.tick(halfway, deltaMs: force.durationMs);
    expect(arrived.movingForces, isEmpty);
    expect(arrived.islands[1].currentForces, 40);
  });

  test(
    'movement duration is proportional to distance with a ten-second diagonal',
    () {
      const source = IslandState(
        id: 0,
        position: IslandPosition(x: -1, y: -1),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 40,
        capacity: 200,
      );
      const diagonalTarget = IslandState(
        id: 1,
        position: IslandPosition(x: 1, y: 1),
        faction: Faction.neutral,
        size: IslandSize.small,
        capacity: 50,
      );
      const nearTarget = IslandState(
        id: 2,
        position: IslandPosition(x: 0, y: -1),
        faction: Faction.neutral,
        size: IslandSize.small,
        capacity: 50,
      );

      final diagonal = rules.createMovingForce(
        id: 10,
        faction: Faction.player,
        source: source,
        destination: diagonalTarget,
        strength: 20,
        departureTimeMs: 1200,
      );
      final near = rules.createMovingForce(
        id: 11,
        faction: Faction.player,
        source: source,
        destination: nearTarget,
        strength: 20,
        departureTimeMs: 1200,
      );

      expect(diagonal.durationMs, 10000);
      expect(diagonal.arrivalTimeMs, 11200);
      expect(near.durationMs, lessThan(diagonal.durationMs));
      expect(near.arrivalTimeMs, 1200 + near.durationMs);
    },
  );

  test('takes five seconds from the center to a screen corner', () {
    const viewport = IslandMapViewport(width: 390, height: 844);
    const source = IslandState(
      id: 0,
      position: IslandPosition(x: 0, y: 0),
      faction: Faction.player,
      currentForces: 20,
      capacity: 200,
    );
    const target = IslandState(
      id: 1,
      position: IslandPosition(x: 1, y: 1),
      faction: Faction.neutral,
      capacity: 50,
    );

    final force = rules.createMovingForce(
      id: 0,
      faction: Faction.player,
      source: source,
      destination: target,
      strength: 5,
      viewport: viewport,
    );

    expect(force.durationMs, 5000);
  });

  test('uses portrait screen distance for duration and arrival boundaries', () {
    const viewport = IslandMapViewport(width: 390, height: 844);
    const horizontalSource = IslandState(
      id: 0,
      position: IslandPosition(x: -1, y: 0),
      faction: Faction.player,
      currentForces: 20,
      capacity: 200,
    );
    const horizontalTarget = IslandState(
      id: 1,
      position: IslandPosition(x: 1, y: 0),
      faction: Faction.neutral,
      capacity: 50,
    );
    const verticalSource = IslandState(
      id: 2,
      position: IslandPosition(x: 0, y: -1),
      faction: Faction.player,
      currentForces: 20,
      capacity: 200,
    );
    const verticalTarget = IslandState(
      id: 3,
      position: IslandPosition(x: 0, y: 0),
      faction: Faction.neutral,
      capacity: 50,
    );
    const cpu = IslandState(
      id: 99,
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 0,
      capacity: 200,
    );
    const diagonalSource = IslandState(
      id: 4,
      position: IslandPosition(x: -1, y: -1),
      faction: Faction.player,
      currentForces: 20,
      capacity: 200,
    );
    const diagonalTarget = IslandState(
      id: 5,
      position: IslandPosition(x: 1, y: 1),
      faction: Faction.neutral,
      capacity: 50,
    );

    final horizontal = rules.createMovingForce(
      id: 0,
      faction: Faction.player,
      source: horizontalSource,
      destination: horizontalTarget,
      strength: 5,
      viewport: viewport,
    );
    final vertical = rules.createMovingForce(
      id: 1,
      faction: Faction.player,
      source: verticalSource,
      destination: verticalTarget,
      strength: 5,
      viewport: viewport,
    );
    final diagonal = rules.createMovingForce(
      id: 2,
      faction: Faction.player,
      source: diagonalSource,
      destination: diagonalTarget,
      strength: 5,
      viewport: viewport,
    );

    expect(
      viewport.movingForceDistance(
        horizontalSource.position,
        horizontalTarget.position,
      ),
      closeTo(360, 1e-12),
    );
    expect(
      viewport.movingForceDistance(
        verticalSource.position,
        verticalTarget.position,
      ),
      closeTo(407, 1e-12),
    );
    expect(
      viewport.movingForceDistance(
        diagonalSource.position,
        diagonalTarget.position,
      ),
      closeTo(viewport.movingForceScreenDiagonal, 1e-12),
    );
    expect(horizontal.durationMs, 4045);
    expect(vertical.durationMs, 4573);
    expect(diagonal.durationMs, 10000);
    expect(vertical.durationMs, greaterThan(horizontal.durationMs));
    expect(diagonal.durationMs, MovementTiming.screenDiagonalDurationMs);

    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: [verticalSource, verticalTarget, cpu],
      movingForces: [vertical],
    );
    final beforeArrival = rules.tick(state, deltaMs: vertical.durationMs - 1);
    expect(beforeArrival.movingForces, hasLength(1));

    final atArrival = rules.tick(beforeArrival, deltaMs: 1);
    expect(atArrival.movingForces, isEmpty);
  });

  test(
    'keeps a troop until the tick before arrival and removes it at arrival',
    () {
      const source = IslandState(
        id: 0,
        position: IslandPosition(x: -1, y: -1),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 40,
        capacity: 200,
      );
      const target = IslandState(
        id: 1,
        position: IslandPosition(x: 1, y: 1),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 10,
        capacity: 200,
      );
      const cpu = IslandState(
        id: 2,
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 0,
        capacity: 200,
      );
      final force = rules.createMovingForce(
        id: 0,
        faction: Faction.player,
        source: source,
        destination: target,
        strength: 15,
      );
      final state = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: [source, target, cpu],
        movingForces: [force],
      );

      final beforeArrival = rules.tick(state, deltaMs: force.durationMs - 1);
      expect(beforeArrival.movingForces, hasLength(1));
      expect(beforeArrival.movingForces.single.progress, lessThan(1));
      expect(
        beforeArrival.movingForces.single.arrivalTimeMs,
        force.arrivalTimeMs,
      );

      final atArrival = rules.tick(beforeArrival, deltaMs: 1);
      expect(atArrival.movingForces, isEmpty);
      expect(atArrival.islands[1].currentForces, 35);
    },
  );

  test(
    'updates multiple troops independently without in-flight collisions',
    () {
      const firstSource = IslandState(
        id: 0,
        position: IslandPosition(x: -1, y: 0),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 40,
        capacity: 200,
      );
      const firstTarget = IslandState(
        id: 1,
        position: IslandPosition(x: 0, y: 0),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 10,
        capacity: 200,
      );
      const secondSource = IslandState(
        id: 2,
        position: IslandPosition(x: 0, y: -1),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 40,
        capacity: 200,
      );
      const secondTarget = IslandState(
        id: 3,
        position: IslandPosition(x: 0, y: 1),
        faction: Faction.neutral,
        size: IslandSize.small,
        capacity: 50,
      );
      final first = rules.createMovingForce(
        id: 0,
        faction: Faction.player,
        source: firstSource,
        destination: firstTarget,
        strength: 15,
      );
      final second = rules.createMovingForce(
        id: 1,
        faction: Faction.player,
        source: secondSource,
        destination: secondTarget,
        strength: 7,
      );
      final state = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        selectedIslandId: 2,
        islands: [firstSource, firstTarget, secondSource, secondTarget],
        movingForces: [first, second],
      );

      final next = rules.tick(state, deltaMs: first.durationMs);
      expect(next.movingForces, hasLength(1));
      expect(next.movingForces.single.id, second.id);
      expect(next.islands[1].currentForces, 28);
      expect(next.islands[3].currentForces, 0);
      expect(next.movingForces.single.progress, lessThan(1));
      expect(next.movingForces.single.position.x, closeTo(0, 1e-3));
      expect(next.movingForces.single.position.y, closeTo(0, 1e-3));
      expect(next.selectedIslandId, 2);
    },
  );

  test(
    'reinforcement adds arrival strength and clamps every island capacity',
    () {
      const source = IslandState(
        id: 0,
        position: IslandPosition(x: -1, y: 0),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 100,
        capacity: 200,
      );
      const enemy = IslandState(
        id: 99,
        position: IslandPosition(x: 1, y: 1),
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 100,
        capacity: 200,
      );

      for (final size in IslandSize.values) {
        final current = size.capacity - 1;
        final target = IslandState(
          id: 1,
          position: const IslandPosition(x: 1, y: 0),
          faction: Faction.player,
          size: size,
          currentForces: current,
          capacity: size.capacity,
        );
        final force = MovingForce(
          id: size.index,
          faction: Faction.player,
          sourceIslandId: source.id,
          destinationIslandId: target.id,
          strength: 1,
          departureTimeMs: 0,
          arrivalTimeMs: 0,
          durationMs: 1,
        );
        final next = rules.tick(
          GameState(
            phase: GamePhase.playing,
            elapsedMs: 0,
            islands: [source, target, enemy],
            movingForces: [force],
          ),
          deltaMs: 0,
        );
        expect(next.islands[1].currentForces, size.capacity);
        expect(next.islands[1].faction, Faction.player);
        expect(next.movingForces, isEmpty);
      }

      const atCapacity = IslandState(
        id: 1,
        position: IslandPosition(x: 1, y: 0),
        faction: Faction.player,
        size: IslandSize.small,
        currentForces: 50,
        capacity: 50,
      );
      final discarded = rules.tick(
        GameState(
          phase: GamePhase.playing,
          elapsedMs: 0,
          islands: const [source, atCapacity, enemy],
          movingForces: const [
            MovingForce(
              id: 20,
              faction: Faction.player,
              sourceIslandId: 0,
              destinationIslandId: 1,
              strength: 20,
              arrivalTimeMs: 0,
              durationMs: 1,
            ),
          ],
        ),
        deltaMs: 0,
      );
      expect(discarded.islands[1].currentForces, 50);
    },
  );

  test('neutral attacks persist damage and capture only above durability', () {
    const neutral = IslandState(
      id: 1,
      position: const IslandPosition(x: 1, y: 0),
      faction: Faction.neutral,
      size: IslandSize.small,
      durability: 10,
      capacity: 50,
    );
    const player = IslandState(
      id: 0,
      position: const IslandPosition(x: -1, y: 0),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    const enemy = IslandState(
      id: 2,
      position: const IslandPosition(x: 0, y: 1),
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );

    GameState attack(int strength, IslandState target) {
      return GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: [player, target, enemy],
        movingForces: [
          MovingForce(
            id: strength,
            faction: Faction.player,
            sourceIslandId: player.id,
            destinationIslandId: target.id,
            strength: strength,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      );
    }

    final below = rules.tick(attack(4, neutral), deltaMs: 0);
    expect(below.islands[1].faction, Faction.neutral);
    expect(below.islands[1].durability, 6);
    expect(below.islands[1].currentForces, 0);

    final equal = rules.tick(attack(10, neutral), deltaMs: 0);
    expect(equal.islands[1].faction, Faction.neutral);
    expect(equal.islands[1].durability, 0);

    final damagedThenCaptured = rules.tick(
      attack(7, below.islands[1]),
      deltaMs: 0,
    );
    expect(damagedThenCaptured.islands[1].faction, Faction.player);
    expect(damagedThenCaptured.islands[1].currentForces, 1);
    expect(damagedThenCaptured.islands[1].durability, 0);
  });

  test('enemy attacks retain defenders on below and equal values', () {
    const player = IslandState(
      id: 0,
      position: IslandPosition(x: -1, y: 0),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    const enemy = IslandState(
      id: 2,
      position: IslandPosition(x: 0, y: 1),
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    final target = IslandState(
      id: 1,
      position: const IslandPosition(x: 1, y: 0),
      faction: Faction.cpu,
      size: IslandSize.medium,
      currentForces: 10,
      capacity: 100,
    );

    GameState attack(int strength) {
      return GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: [player, target, enemy],
        movingForces: [
          MovingForce(
            id: strength,
            faction: Faction.player,
            sourceIslandId: player.id,
            destinationIslandId: target.id,
            strength: strength,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      );
    }

    final below = rules.tick(attack(4), deltaMs: 0);
    expect(below.islands[1].faction, Faction.cpu);
    expect(below.islands[1].currentForces, 6);

    final equal = rules.tick(attack(10), deltaMs: 0);
    expect(equal.islands[1].faction, Faction.cpu);
    expect(equal.islands[1].currentForces, 0);

    final captured = rules.tick(attack(12), deltaMs: 0);
    expect(captured.islands[1].faction, Faction.player);
    expect(captured.islands[1].currentForces, 2);
  });

  test('post-capture survivors are clamped to the target capacity', () {
    const player = IslandState(
      id: 0,
      position: IslandPosition(x: -1, y: 0),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    const neutral = IslandState(
      id: 1,
      position: IslandPosition(x: 1, y: 0),
      faction: Faction.neutral,
      size: IslandSize.small,
      durability: 10,
      capacity: 50,
    );
    const enemy = IslandState(
      id: 2,
      position: IslandPosition(x: 0, y: 1),
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    final next = rules.tick(
      GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [player, neutral, enemy],
        movingForces: const [
          MovingForce(
            id: 0,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 1,
            strength: 100,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      ),
      deltaMs: 0,
    );
    expect(next.islands[1].faction, Faction.player);
    expect(next.islands[1].currentForces, 50);
  });

  test('simultaneous arrivals cancel by faction before resolving a target', () {
    const target = IslandState(
      id: 2,
      position: const IslandPosition(x: 0, y: 0),
      faction: Faction.neutral,
      size: IslandSize.medium,
      durability: 10,
      capacity: 100,
    );
    const player = IslandState(
      id: 0,
      position: const IslandPosition(x: -1, y: 0),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    const cpu = IslandState(
      id: 1,
      position: const IslandPosition(x: 1, y: 0),
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );

    GameState simultaneous(int playerStrength, int cpuStrength) {
      return GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: [player, cpu, target],
        movingForces: [
          MovingForce(
            id: 0,
            faction: Faction.player,
            sourceIslandId: player.id,
            destinationIslandId: target.id,
            strength: playerStrength,
            arrivalTimeMs: 1000,
            durationMs: 1,
          ),
          MovingForce(
            id: 1,
            faction: Faction.cpu,
            sourceIslandId: cpu.id,
            destinationIslandId: target.id,
            strength: cpuStrength,
            arrivalTimeMs: 1000,
            durationMs: 1,
          ),
        ],
      );
    }

    final playerWins = rules.tick(simultaneous(8, 5), deltaMs: 1000);
    expect(playerWins.islands[2].faction, Faction.neutral);
    expect(playerWins.islands[2].durability, 7);

    final cpuWins = rules.tick(simultaneous(5, 20), deltaMs: 1000);
    expect(cpuWins.islands[2].faction, Faction.cpu);
    expect(cpuWins.islands[2].currentForces, 5);
    expect(cpuWins.islands[2].durability, 0);

    final equal = rules.tick(simultaneous(8, 8), deltaMs: 1000);
    expect(equal.islands[2], target);
  });

  test('growth is applied before an arrival at the same timestamp', () {
    const player = IslandState(
      id: 0,
      position: IslandPosition(x: -1, y: 0),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 10,
      capacity: 200,
    );
    const target = IslandState(
      id: 1,
      position: IslandPosition(x: 1, y: 0),
      faction: Faction.player,
      size: IslandSize.small,
      currentForces: 10,
      capacity: 50,
    );
    const enemy = IslandState(
      id: 2,
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    final next = rules.tick(
      GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [player, target, enemy],
        movingForces: const [
          MovingForce(
            id: 0,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 1,
            strength: 5,
            arrivalTimeMs: 1000,
            durationMs: 1000,
          ),
        ],
      ),
      deltaMs: 1000,
    );
    expect(next.islands[1].currentForces, 16);
  });

  test('result requires no owned islands and no troops in transit', () {
    const playerIsland = IslandState(
      id: 0,
      faction: Faction.player,
      size: IslandSize.small,
      currentForces: 1,
      capacity: 50,
    );
    const cpuIsland = IslandState(
      id: 1,
      faction: Faction.cpu,
      size: IslandSize.small,
      currentForces: 1,
      capacity: 50,
    );

    final defeat = rules.tick(
      GameState(
        phase: GamePhase.playing,
        elapsedMs: 12,
        islands: [playerIsland, cpuIsland],
        movingForces: const [
          MovingForce(
            id: 0,
            faction: Faction.cpu,
            sourceIslandId: 1,
            destinationIslandId: 0,
            strength: 2,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      ),
      deltaMs: 0,
    );
    expect(defeat.phase, GamePhase.result);
    expect(defeat.result?.type, GameResultType.defeat);
    expect(defeat.result?.winner, Faction.cpu);

    final victory = rules.tick(
      GameState(
        phase: GamePhase.playing,
        elapsedMs: 12,
        islands: [playerIsland, cpuIsland],
        movingForces: const [
          MovingForce(
            id: 1,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 1,
            strength: 2,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      ),
      deltaMs: 0,
    );
    expect(victory.phase, GamePhase.result);
    expect(victory.result?.type, GameResultType.victory);
    expect(victory.result?.winner, Faction.player);

    final draw = rules.tick(
      GameState(
        phase: GamePhase.playing,
        elapsedMs: 12,
        islands: const [
          IslandState(
            id: 2,
            faction: Faction.neutral,
            size: IslandSize.small,
            durability: 10,
          ),
        ],
        movingForces: const [
          MovingForce(
            id: 2,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 2,
            strength: 5,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
          MovingForce(
            id: 3,
            faction: Faction.cpu,
            sourceIslandId: 1,
            destinationIslandId: 2,
            strength: 5,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      ),
      deltaMs: 0,
    );
    expect(draw.phase, GamePhase.result);
    expect(draw.result?.type, GameResultType.draw);
  });

  test('an in-transit troop can recapture after the final island is lost', () {
    const cpu = IslandState(
      id: 1,
      position: IslandPosition(x: 1, y: 0),
      faction: Faction.cpu,
      size: IslandSize.small,
      currentForces: 1,
      capacity: 50,
    );
    const playerForce = MovingForce(
      id: 0,
      faction: Faction.player,
      sourceIslandId: 0,
      destinationIslandId: 1,
      strength: 2,
      arrivalTimeMs: 100,
      durationMs: 100,
    );
    final inTransit = rules.tick(
      GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [cpu],
        movingForces: const [playerForce],
      ),
      deltaMs: 50,
    );
    expect(inTransit.phase, GamePhase.playing);
    expect(inTransit.movingForces, hasLength(1));

    final next = rules.tick(inTransit, deltaMs: 50);
    expect(next.phase, GamePhase.result);
    expect(next.result?.type, GameResultType.victory);
    expect(next.islands.single.faction, Faction.player);
    expect(next.islands.single.currentForces, 1);
  });

  test('losing the headquarters alone does not finalize the match', () {
    const playerHeadquarters = IslandState(
      id: 0,
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 1,
      capacity: 200,
    );
    const playerIsland = IslandState(
      id: 2,
      faction: Faction.player,
      size: IslandSize.small,
      currentForces: 1,
      capacity: 50,
    );
    const cpuHeadquarters = IslandState(
      id: 1,
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    final next = rules.tick(
      GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [playerHeadquarters, playerIsland, cpuHeadquarters],
        movingForces: const [
          MovingForce(
            id: 0,
            faction: Faction.cpu,
            sourceIslandId: 1,
            destinationIslandId: 0,
            strength: 2,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      ),
      deltaMs: 0,
    );
    expect(next.phase, GamePhase.playing);
    expect(next.islands[0].faction, Faction.cpu);
    expect(next.islands[1].faction, Faction.player);
  });

  test('simultaneous elimination is a draw and freezes subsequent ticks', () {
    const target = IslandState(
      id: 2,
      faction: Faction.neutral,
      size: IslandSize.small,
      durability: 10,
    );
    final initial = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: const [target],
      movingForces: const [
        MovingForce(
          id: 0,
          faction: Faction.player,
          sourceIslandId: 0,
          destinationIslandId: 2,
          strength: 5,
          arrivalTimeMs: 0,
          durationMs: 1,
        ),
        MovingForce(
          id: 1,
          faction: Faction.cpu,
          sourceIslandId: 1,
          destinationIslandId: 2,
          strength: 5,
          arrivalTimeMs: 0,
          durationMs: 1,
        ),
      ],
    );
    final result = rules.tick(initial, deltaMs: 0);
    expect(result.phase, GamePhase.result);
    expect(result.result?.type, GameResultType.draw);
    expect(rules.tick(result, deltaMs: 5000), same(result));
  });

  test(
    'invalidates a selected source when ownership or force becomes invalid',
    () {
      const source = IslandState(
        id: 0,
        position: IslandPosition(x: 0, y: 0),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 10,
        capacity: 200,
      );
      const target = IslandState(
        id: 1,
        position: IslandPosition(x: 1, y: 1),
        faction: Faction.neutral,
        size: IslandSize.small,
        capacity: 50,
      );
      final ownershipChanged = GameState(
        phase: GamePhase.playing,
        elapsedMs: 100,
        selectedIslandId: 0,
        islands: [
          source.copyWith(faction: Faction.cpu),
          target,
        ],
      );
      final forceExhausted = ownershipChanged.copyWith(
        islands: [source.copyWith(currentForces: 1), target],
      );

      expect(rules.tick(ownershipChanged, deltaMs: 0).selectedIslandId, isNull);
      expect(rules.tick(forceExhausted, deltaMs: 0).selectedIslandId, isNull);
    },
  );

  test(
    'keeps a cleared selection cleared after later arrivals in one tick',
    () {
      const selected = IslandState(
        id: 0,
        position: IslandPosition(x: 0, y: 0),
        faction: Faction.player,
        size: IslandSize.small,
        currentForces: 5,
        capacity: 50,
      );
      const playerSource = IslandState(
        id: 1,
        position: IslandPosition(x: -1, y: 0),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 50,
        capacity: 200,
      );
      const cpuSource = IslandState(
        id: 2,
        position: IslandPosition(x: 1, y: 0),
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 50,
        capacity: 200,
      );

      final next = rules.tick(
        GameState(
          phase: GamePhase.playing,
          elapsedMs: 0,
          selectedIslandId: selected.id,
          islands: const [selected, playerSource, cpuSource],
          movingForces: const [
            MovingForce(
              id: 0,
              faction: Faction.cpu,
              sourceIslandId: 2,
              destinationIslandId: 0,
              strength: 10,
              arrivalTimeMs: 100,
              durationMs: 100,
            ),
            MovingForce(
              id: 1,
              faction: Faction.player,
              sourceIslandId: 1,
              destinationIslandId: 0,
              strength: 10,
              arrivalTimeMs: 200,
              durationMs: 200,
            ),
          ],
        ),
        deltaMs: 200,
      );

      expect(next.islands.first.faction, Faction.player);
      expect(next.selectedIslandId, isNull);
    },
  );

  test('controller uses an injected clock with a manual loop', () {
    final clock = FixedClock();
    final loop = ManualGameLoop();
    final container = ProviderContainer(
      overrides: [
        gameClockProvider.overrideWithValue(clock),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(7)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    clock.value = 3000;
    loop.tick();
    clock.value = 3125;
    loop.tick();

    expect(container.read(gameControllerProvider).elapsedMs, 125);
  });

  test('nullable state values are cleared through typed APIs', () {
    const force = MovingForce(
      id: 1,
      sourceIslandId: 0,
      destinationIslandId: 1,
      strength: 5,
    );
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      selectedIslandId: 0,
      movingForces: const [force],
    );
    final resultState = state.finishWithResult(
      const GameResult.draw(elapsedMs: 0),
    );

    expect(state.clearSelection().selectedIslandId, isNull);
    expect(state.clearMovingForces().movingForces, isEmpty);
    expect(state.clearResult().result, isNull);
    expect(state.copyWithMovement(null).movingForces, isEmpty);
    expect(resultState.phase, GamePhase.result);
    expect(resultState.result, isNotNull);
    expect(
      () => GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        result: const GameResult.draw(elapsedMs: 0),
      ),
      throwsStateError,
    );
    expect(
      () => state.copyWith(result: const GameResult.draw(elapsedMs: 0)),
      throwsStateError,
    );
    expect(
      () => resultState.copyWith(phase: GamePhase.playing),
      throwsStateError,
    );
    expect(() => resultState.clearResult(), throwsStateError);
  });

  test('controller ignores invalid island-count selections', () {
    final loop = ManualGameLoop();
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(8)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.selectIslandCount(7);
    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      10,
    );

    controller.selectIslandCount(6);
    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      6,
    );
    expect(container.read(gameControllerProvider).islands, hasLength(6));
  });
}
