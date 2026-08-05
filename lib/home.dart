import 'package:conquest/base.dart';
import 'package:conquest/moving_force.dart';
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

class _GameSurface extends ConsumerStatefulWidget {
  const _GameSurface();

  @override
  ConsumerState<_GameSurface> createState() => _GameSurfaceState();
}

class _GameSurfaceState extends ConsumerState<_GameSurface>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.detached) {
      ref.read(gameControllerProvider.notifier).pauseGame();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      selected: state.selectedIslandId == island.id,
                      destinationCandidate:
                          state.selectedIslandId != null &&
                          state.selectedIslandId != island.id,
                      onPressed: state.phase == GamePhase.playing
                          ? () => controller.tapBase(island.id)
                          : null,
                    ),
                  ),
                ),
              for (final force in state.movingForces)
                Align(
                  key: ValueKey('moving-force-position-${force.id}'),
                  alignment: Alignment(force.x, force.y),
                  child: MovingForceWidget(
                    force: force,
                    semanticsKey: ValueKey('moving-force-${force.id}'),
                  ),
                ),
            ],
          ),
        ),
        if (state.hasInteractionFeedback)
          _InteractionFeedback(message: state.interactionFeedback!),
        if (state.phase == GamePhase.configuration && state.islands.isNotEmpty)
          _ConfigurationPanel(state: state, onStart: controller.startGame),
        if (state.phase == GamePhase.playing)
          _PauseButton(onPressed: controller.pauseGame),
        if (state.phase == GamePhase.paused)
          _PauseMenu(
            onResume: controller.resumeGame,
            onQuit: () => _confirmQuit(context, controller),
          ),
        if (state.phase == GamePhase.result)
          _ResultPanel(
            result: state.result!,
            onReplay: controller.replayGame,
            onSettings: controller.returnToConfiguration,
          ),
        _CountdownBanner(state: state),
      ],
    );
  }

  Future<void> _confirmQuit(
    BuildContext context,
    GameController controller,
  ) async {
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quit match?'),
          content: const Text('Your current match will not be saved.'),
          actions: [
            TextButton(
              key: const ValueKey('cancel-quit'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              key: const ValueKey('confirm-quit'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('QUIT'),
            ),
          ],
        );
      },
    );
    if (shouldQuit == true && mounted) {
      controller.returnToConfiguration();
    }
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(IslandMapViewport.pauseControlPadding),
        child: SizedBox(
          width: IslandMapViewport.pauseButtonWidth,
          height: IslandMapViewport.pauseButtonHeight,
          child: Semantics(
            button: true,
            label: 'Pause game',
            child: ElevatedButton(
              key: const ValueKey('pause-game'),
              onPressed: onPressed,
              child: const Text('PAUSE'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseMenu extends StatelessWidget {
  const _PauseMenu({required this.onResume, required this.onQuit});

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Material(
          color: Colors.black.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Game Paused',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const ValueKey('resume-game'),
                  onPressed: onResume,
                  child: const Text('RESUME'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('quit-game'),
                  onPressed: onQuit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: const Text('QUIT MATCH'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.onReplay,
    required this.onSettings,
  });

  final GameResult result;
  final VoidCallback onReplay;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final title = switch (result.type) {
      GameResultType.victory => 'Victory',
      GameResultType.defeat => 'Defeat',
      GameResultType.draw => 'Draw',
    };
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Material(
          color: Colors.black.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const ValueKey('replay-game'),
                  onPressed: onReplay,
                  child: const Text('PLAY AGAIN'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('return-settings'),
                  onPressed: onSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: const Text('RETURN TO SETTINGS'),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _InteractionFeedback extends StatelessWidget {
  const _InteractionFeedback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: message,
            child: DecoratedBox(
              key: const ValueKey('interaction-feedback'),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
