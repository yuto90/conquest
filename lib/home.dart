import 'package:conquest/base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/game_controller.dart';
import 'game/game_rules.dart';
import 'game/game_state.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = IslandMapViewport(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            );
            return ProviderScope(
              overrides: [
                mapViewportProvider.overrideWithValue(viewport),
                gameControllerProvider.overrideWith(GameController.new),
              ],
              child: const _GameSurface(),
            );
          },
        ),
      ),
    );
  }
}

class _GameSurface extends ConsumerWidget {
  const _GameSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.blue),
        Semantics(
          container: true,
          label: 'Island map, ${state.configuration.totalIslandCount} islands',
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final island in state.islands)
                Align(
                  key: ValueKey('island-${island.id}'),
                  alignment: Alignment(island.x, island.y),
                  child: SizedBox.square(
                    dimension: GameRules.islandWidgetSize(island.size),
                    child: Base(
                      key: ValueKey('island-button-${island.id}'),
                      base: island,
                      onPressed: state.phase == GamePhase.playing
                          ? () => controller.tapBase(island.id)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (state.phase == GamePhase.configuration && state.islands.isNotEmpty)
          _ConfigurationPanel(state: state, onStart: controller.startGame),
        _CountdownBanner(state: state),
      ],
    );
  }
}

class _ConfigurationPanel extends StatelessWidget {
  const _ConfigurationPanel({required this.state, required this.onStart});

  final GameState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Choose total islands',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final count in GameConfiguration.allowedIslandCounts)
                      Semantics(
                        button: true,
                        selected: state.configuration.totalIslandCount == count,
                        label: '$count islands',
                        child: ChoiceChip(
                          key: ValueKey('island-count-$count'),
                          label: Text('$count'),
                          selected:
                              state.configuration.totalIslandCount == count,
                          onSelected: (_) => _selectCount(context, count),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          tooltip: '$count islands',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label:
                      'Start game with ${state.configuration.totalIslandCount} islands',
                  child: ElevatedButton(
                    key: const ValueKey('start-game'),
                    onPressed: onStart,
                    child: const Text('START GAME'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectCount(BuildContext context, int count) {
    final container = ProviderScope.containerOf(context);
    container.read(gameControllerProvider.notifier).selectIslandCount(count);
  }
}

class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final text = _countdownText;
    if (text == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: 'Game start $text',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? get _countdownText {
    if (state.phase == GamePhase.startCountdown ||
        state.phase == GamePhase.resumeCountdown) {
      if (state.countdownRemainingMs > 2000) {
        return '3';
      }
      if (state.countdownRemainingMs > 1000) {
        return '2';
      }
      if (state.countdownRemainingMs > 0) {
        return '1';
      }
      return null;
    }
    if (state.phase == GamePhase.playing && state.elapsedMs == 0) {
      return 'START';
    }
    return null;
  }
}
