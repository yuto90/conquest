import 'dart:math' as math;

import 'package:conquest/base.dart';
import 'package:conquest/faction_presentation.dart';
import 'package:conquest/moving_force.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/game_controller.dart';
import 'game/game_rules.dart';
import 'game/game_state.dart';
import 'ui/tactical_map_background.dart';
import 'ui/tactical_theme.dart';

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
    final isPlayerInteractionEnabled =
        state.phase == GamePhase.playing &&
        state.configuration.gameMode == GameMode.playerVsCpu;
    final showBoardChrome = state.phase != GamePhase.configuration;

    return ColoredBox(
      color: TacticalPalette.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TacticalMapBackground(),
          CustomPaint(painter: _RoutePainter(state: state)),
          Semantics(
            container: true,
            label:
                'Island map, ${state.configuration.totalIslandCount} islands',
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
                        presentation: FactionPresentation.forMode(
                          state.configuration.gameMode,
                          island.faction,
                        ),
                        selected: state.selectedIslandId == island.id,
                        destinationCandidate:
                            isPlayerInteractionEnabled &&
                            state.selectedIslandId != null &&
                            state.selectedIslandId != island.id,
                        onPressed: isPlayerInteractionEnabled
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
                      presentation: FactionPresentation.forMode(
                        state.configuration.gameMode,
                        force.faction,
                      ),
                      semanticsKey: ValueKey('moving-force-${force.id}'),
                    ),
                  ),
              ],
            ),
          ),
          if (showBoardChrome)
            _BoardChrome(
              state: state,
              onPause: state.phase == GamePhase.playing
                  ? controller.pauseGame
                  : null,
            ),
          if (state.hasInteractionFeedback)
            _InteractionFeedback(message: state.interactionFeedback!),
          if (state.phase == GamePhase.configuration)
            _ConfigurationPanel(
              state: state,
              onStart:
                  state.islands.length == state.configuration.totalIslandCount
                  ? controller.startGame
                  : null,
            ),
          if (state.phase == GamePhase.paused)
            _PauseMenu(
              onResume: controller.resumeGame,
              onQuit: () => _confirmQuit(context, controller),
            ),
          if (state.phase == GamePhase.result)
            _ResultPanel(
              configuration: state.configuration,
              result: state.result!,
              onReplay: controller.replayGame,
              onSettings: controller.returnToConfiguration,
            ),
          _CountdownOverlay(state: state),
        ],
      ),
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
          backgroundColor: TacticalPalette.surface,
          shape: const RoundedRectangleBorder(),
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
    if (shouldQuit == true && mounted) controller.returnToConfiguration();
  }
}

class _BoardChrome extends StatelessWidget {
  const _BoardChrome({required this.state, required this.onPause});

  final GameState state;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedIslandId != null;
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 17,
            child: IgnorePointer(
              child: Column(
                key: const ValueKey('board-title-block'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONQUEST',
                    style: TacticalTypography.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TacticalPalette.seaDeep,
                      height: 1,
                      letterSpacing: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '戦術海図 / ${state.configuration.totalIslandCount}島',
                    style: TacticalTypography.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: TacticalPalette.seaDeep.withValues(alpha: 0.72),
                      height: 1,
                      letterSpacing: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 17,
            child: _PauseButton(onPressed: onPause),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 17,
            child: IgnorePointer(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      key: const ValueKey('board-status-label'),
                      selected ? '出兵元を選択中' : '自軍の島を選択',
                      style: TacticalTypography.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: TacticalPalette.foreground,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Text(
                    key: const ValueKey('board-status-detail'),
                    selected ? 'タップで目標を指定\n兵力の半分を派遣' : '島をタップして選択\n兵力2以上で出兵可能',
                    textAlign: TextAlign.right,
                    style: TacticalTypography.body(
                      fontSize: 10,
                      color: TacticalPalette.seaDeep.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Pause game',
      child: SizedBox.square(
        dimension: 48,
        child: ElevatedButton(
          key: onPressed == null ? null : const ValueKey('pause-game'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: TacticalPalette.foreground,
            backgroundColor: Color.alphaBlend(
              TacticalPalette.surface.withValues(alpha: 0.78),
              TacticalPalette.background,
            ),
            disabledForegroundColor: TacticalPalette.foreground,
            disabledBackgroundColor: Color.alphaBlend(
              TacticalPalette.surface.withValues(alpha: 0.78),
              TacticalPalette.background,
            ),
            side: BorderSide(
              color: TacticalPalette.seaDeep.withValues(alpha: 0.65),
            ),
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: TacticalPalette.seaDeep.withValues(alpha: 0.24),
          ),
          child: const Icon(Icons.pause_rounded, size: 24),
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
      color: TacticalPalette.outer.withValues(alpha: 0.23),
      child: Center(
        child: Container(
          key: const ValueKey('pause-sheet'),
          width: 248,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              TacticalPalette.surface.withValues(alpha: 0.94),
              TacticalPalette.background,
            ),
            border: Border.all(color: TacticalPalette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E1A4448),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '対戦を一時停止',
                style: TacticalTypography.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TacticalPalette.muted,
                  height: 1.2,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '一時停止',
                style: TacticalTypography.display(
                  fontSize: 30,
                  height: 1,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '現在の盤面を確認できます。',
                style: TacticalTypography.body(
                  fontSize: 12,
                  color: TacticalPalette.muted,
                ),
              ),
              const SizedBox(height: 21),
              _PrimaryActionButton(
                key: const ValueKey('resume-game'),
                onPressed: onResume,
                label: '再開',
              ),
              const SizedBox(height: 9),
              _SecondaryActionButton(
                key: const ValueKey('quit-game'),
                onPressed: onQuit,
                label: '設定へ戻る',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.configuration,
    required this.result,
    required this.onReplay,
    required this.onSettings,
  });

  final GameConfiguration configuration;
  final GameResult result;
  final VoidCallback onReplay;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final title = _resultTitle(configuration, result);
    final ruleColor = switch (result.type) {
      GameResultType.victory
          when configuration.gameMode == GameMode.playerVsCpu =>
        TacticalPalette.player,
      GameResultType.defeat
          when configuration.gameMode == GameMode.playerVsCpu =>
        TacticalPalette.cpu,
      GameResultType.victory =>
        result.winner == Faction.cpu
            ? TacticalPalette.cpu
            : TacticalPalette.player,
      GameResultType.defeat =>
        result.winner == Faction.cpu
            ? TacticalPalette.cpu
            : TacticalPalette.player,
      GameResultType.draw => TacticalPalette.neutral,
    };
    return ColoredBox(
      color: TacticalPalette.outer.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          key: const ValueKey('result-sheet'),
          width: 248,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              TacticalPalette.surface.withValues(alpha: 0.94),
              TacticalPalette.background,
            ),
            border: Border.all(color: TacticalPalette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E1A4448),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '戦闘終了',
                style: TacticalTypography.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TacticalPalette.muted,
                  height: 1.2,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('result-rule'),
                width: 54,
                height: 4,
                color: ruleColor,
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  style: TacticalTypography.display(
                    fontSize: 46,
                    height: 1,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryActionButton(
                key: const ValueKey('replay-game'),
                onPressed: onReplay,
                label: '再戦',
              ),
              const SizedBox(height: 9),
              _SecondaryActionButton(
                key: const ValueKey('return-settings'),
                onPressed: onSettings,
                label: '設定へ戻る',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigurationPanel extends StatelessWidget {
  const _ConfigurationPanel({required this.state, required this.onStart});

  final GameState state;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('settings-view'),
      color: TacticalPalette.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _SettingsDecorationPainter()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
              child: Transform.translate(
                offset: const Offset(0, 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '対戦設定 / 01',
                        style: TacticalTypography.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TacticalPalette.muted,
                          height: 1.2,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        header: true,
                        child: Text(
                          '対戦設定',
                          style: TacticalTypography.display(
                            fontSize: 40,
                            height: 0.96,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '海域の規模とCPUの判断速度を選択してください。',
                        style: TacticalTypography.body(
                          fontSize: 12,
                          color: TacticalPalette.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        '島数',
                        style: TacticalTypography.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          for (
                            var index = 0;
                            index <
                                GameConfiguration.allowedIslandCounts.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 7),
                            Expanded(
                              child: _IslandCountChoice(
                                state: state,
                                count: GameConfiguration
                                    .allowedIslandCounts[index],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ゲームモード',
                        style: TacticalTypography.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          for (final mode in GameMode.values) ...[
                            if (mode != GameMode.values.first)
                              const SizedBox(width: 7),
                            Expanded(
                              child: _GameModeChoice(state: state, mode: mode),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.configuration.gameMode == GameMode.cpuVsCpu
                            ? '1P CPU難易度'
                            : 'CPU難易度',
                        style: TacticalTypography.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (state.configuration.gameMode ==
                          GameMode.cpuVsCpu) ...[
                        Row(
                          children: [
                            for (
                              var index = 0;
                              index < CpuDifficulty.values.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 7),
                              Expanded(
                                child: _DifficultyChoice(
                                  state: state,
                                  difficulty: CpuDifficulty.values[index],
                                  playerCpu: true,
                                  keyPrefix: 'player-cpu-difficulty',
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '2P CPU難易度',
                          style: TacticalTypography.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          for (
                            var index = 0;
                            index < CpuDifficulty.values.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 7),
                            Expanded(
                              child: _DifficultyChoice(
                                state: state,
                                difficulty: CpuDifficulty.values[index],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 29),
                      Semantics(
                        button: onStart != null,
                        enabled: onStart != null,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            key: const ValueKey('start-game'),
                            onPressed: onStart,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: TacticalPalette.foreground,
                              foregroundColor: TacticalPalette.paper,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(2),
                                ),
                              ),
                            ),
                            child: Semantics(
                              excludeSemantics: true,
                              label: _startLabel(state.configuration),
                              child: Text(
                                'ゲーム開始',
                                style: TacticalTypography.body(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: TacticalPalette.paper,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Text(
                        _selectionSummary(state.configuration),
                        textAlign: TextAlign.center,
                        style: TacticalTypography.mono(
                          fontSize: 10,
                          color: TacticalPalette.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IslandCountChoice extends StatelessWidget {
  const _IslandCountChoice({required this.state, required this.count});

  final GameState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    final selected = state.configuration.totalIslandCount == count;
    return Semantics(
      button: true,
      selected: selected,
      label: '$count islands',
      child: SizedBox(
        height: 51,
        width: double.infinity,
        child: ChoiceChip(
          key: ValueKey('island-count-$count'),
          label: SizedBox(
            width: double.infinity,
            child: Text(
              count.toString().padLeft(2, '0'),
              textAlign: TextAlign.center,
            ),
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => _selectCount(context, count),
          tooltip: '$count islands',
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(vertical: 9),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(1)),
          ),
          side: BorderSide(
            color: selected
                ? TacticalPalette.foreground
                : TacticalPalette.border,
          ),
          selectedColor: TacticalPalette.foreground,
          backgroundColor: Color.alphaBlend(
            TacticalPalette.surface.withValues(alpha: 0.62),
            TacticalPalette.background,
          ),
          labelStyle: TacticalTypography.mono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? TacticalPalette.paper : TacticalPalette.muted,
          ),
        ),
      ),
    );
  }

  void _selectCount(BuildContext context, int count) {
    ProviderScope.containerOf(
      context,
    ).read(gameControllerProvider.notifier).selectIslandCount(count);
  }
}

class _DifficultyChoice extends StatelessWidget {
  const _DifficultyChoice({
    required this.state,
    required this.difficulty,
    this.playerCpu = false,
    this.keyPrefix = 'cpu-difficulty',
  });

  final GameState state;
  final CpuDifficulty difficulty;
  final bool playerCpu;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final selected =
        (playerCpu
            ? state.configuration.playerCpuDifficulty
            : state.configuration.cpuDifficulty) ==
        difficulty;
    final label = _difficultyLabel(difficulty);
    final owner = playerCpu
        ? '1P '
        : state.configuration.gameMode == GameMode.cpuVsCpu
        ? '2P '
        : '';
    final semanticLabel = '$owner$label CPU difficulty';
    return SizedBox(
      height: 51,
      width: double.infinity,
      child: ChoiceChip(
        key: ValueKey('$keyPrefix-${difficulty.name}'),
        label: SizedBox(
          width: double.infinity,
          child: Semantics(
            excludeSemantics: true,
            label: semanticLabel,
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => playerCpu
            ? _selectPlayerDifficulty(context, difficulty)
            : _selectDifficulty(context, difficulty),
        tooltip: semanticLabel,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(vertical: 9),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(1)),
        ),
        side: BorderSide(
          color: selected ? TacticalPalette.foreground : TacticalPalette.border,
        ),
        selectedColor: TacticalPalette.foreground,
        backgroundColor: Color.alphaBlend(
          TacticalPalette.surface.withValues(alpha: 0.62),
          TacticalPalette.background,
        ),
        labelStyle: TacticalTypography.body(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? TacticalPalette.paper : TacticalPalette.muted,
        ),
      ),
    );
  }

  void _selectDifficulty(BuildContext context, CpuDifficulty difficulty) {
    ProviderScope.containerOf(
      context,
    ).read(gameControllerProvider.notifier).selectCpuDifficulty(difficulty);
  }

  void _selectPlayerDifficulty(BuildContext context, CpuDifficulty difficulty) {
    ProviderScope.containerOf(context)
        .read(gameControllerProvider.notifier)
        .selectPlayerCpuDifficulty(difficulty);
  }
}

class _GameModeChoice extends StatelessWidget {
  const _GameModeChoice({required this.state, required this.mode});

  final GameState state;
  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final selected = state.configuration.gameMode == mode;
    final label = _modeLabel(mode);
    return SizedBox(
      height: 41,
      width: double.infinity,
      child: ChoiceChip(
        key: ValueKey('game-mode-${_modeKey(mode)}'),
        label: SizedBox(
          width: double.infinity,
          child: Semantics(
            excludeSemantics: true,
            label: label,
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => ProviderScope.containerOf(
          context,
        ).read(gameControllerProvider.notifier).selectGameMode(mode),
        tooltip: label,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(vertical: 9),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(1)),
        ),
        side: BorderSide(
          color: selected ? TacticalPalette.foreground : TacticalPalette.border,
        ),
        selectedColor: TacticalPalette.foreground,
        backgroundColor: Color.alphaBlend(
          TacticalPalette.surface.withValues(alpha: 0.62),
          TacticalPalette.background,
        ),
        labelStyle: TacticalTypography.body(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? TacticalPalette.paper : TacticalPalette.muted,
        ),
      ),
    );
  }
}

String _modeKey(GameMode mode) => switch (mode) {
  GameMode.playerVsCpu => 'player-vs-cpu',
  GameMode.cpuVsCpu => 'cpu-vs-cpu',
};

String _modeLabel(GameMode mode) => switch (mode) {
  GameMode.playerVsCpu => 'PLAY VS CPU',
  GameMode.cpuVsCpu => 'WATCH CPU VS CPU',
};

String _startLabel(GameConfiguration configuration) =>
    switch (configuration.gameMode) {
      GameMode.playerVsCpu =>
        'Start game with ${configuration.totalIslandCount} islands on '
            '${_difficultyLabel(configuration.cpuDifficulty)} CPU difficulty',
      GameMode.cpuVsCpu =>
        'Watch CPU versus CPU with ${configuration.totalIslandCount} islands, '
            '1P ${_difficultyLabel(configuration.playerCpuDifficulty)}, '
            '2P ${_difficultyLabel(configuration.cpuDifficulty)}',
    };

String _selectionSummary(GameConfiguration configuration) =>
    configuration.gameMode == GameMode.cpuVsCpu
    ? '選択中：${configuration.totalIslandCount}島 / 1P '
          '${_difficultyLabel(configuration.playerCpuDifficulty)} / 2P '
          '${_difficultyLabel(configuration.cpuDifficulty)}'
    : '選択中：${configuration.totalIslandCount}島 / '
          '${_difficultyLabel(configuration.cpuDifficulty)}';

String _resultTitle(GameConfiguration configuration, GameResult result) {
  if (configuration.gameMode == GameMode.playerVsCpu) {
    return switch (result.type) {
      GameResultType.victory => '勝利',
      GameResultType.defeat => '敗北',
      GameResultType.draw => '引き分け',
    };
  }
  return switch (result.winner) {
    Faction.player => '1P WIN',
    Faction.cpu => '2P WIN',
    Faction.neutral || null => 'DRAW',
  };
}

String _difficultyLabel(CpuDifficulty difficulty) => switch (difficulty) {
  CpuDifficulty.veryEasy => 'Very Easy',
  CpuDifficulty.easy => 'Easy',
  CpuDifficulty.normal => 'Normal',
  CpuDifficulty.hard => 'Hard',
};

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final text = _countdownText;
    if (text == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ColoredBox(
        color: TacticalPalette.outer.withValues(alpha: 0.11),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Game start $text',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  key: const ValueKey('countdown-ring'),
                  dimension: 174,
                  child: CustomPaint(
                    painter: const _CountdownRingPainter(),
                    child: Center(
                      child: Text(
                        text,
                        style: TacticalTypography.display(
                          fontSize: text == 'START' ? 42 : 82,
                          height: 0.9,
                          letterSpacing: text == 'START' ? 1 : -4.9,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 23),
                Text(
                  '出撃準備',
                  style: TacticalTypography.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? get _countdownText {
    if (state.phase == GamePhase.startCountdown ||
        state.phase == GamePhase.resumeCountdown) {
      if (state.countdownRemainingMs > 2000) return '3';
      if (state.countdownRemainingMs > 1000) return '2';
      if (state.countdownRemainingMs > 0) return '1';
      return null;
    }
    if (state.phase == GamePhase.playing && state.elapsedMs == 0)
      return 'START';
    return null;
  }
}

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      size.width / 2,
      Paint()
        ..color = TacticalPalette.surface.withValues(alpha: 0.45)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      size.width / 2 - 0.5,
      Paint()
        ..color = TacticalPalette.foreground.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final ring = Paint()
      ..color = TacticalPalette.playerDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width / 2 - 9),
      -math.pi * 0.85,
      math.pi * 1.45,
      false,
      ring,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width / 2 - 17),
      -math.pi * 0.1,
      math.pi * 1.45,
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SettingsDecorationPainter extends CustomPainter {
  const _SettingsDecorationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = TacticalPalette.border.withValues(alpha: 0.50);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width + 45, 50),
        width: 360,
        height: 220,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-15, size.height - 40),
        width: 300,
        height: 180,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onPressed,
    required this.label,
    super.key,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: TacticalPalette.foreground,
          foregroundColor: TacticalPalette.paper,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        child: Text(
          label,
          style: TacticalTypography.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TacticalPalette.paper,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.onPressed,
    required this.label,
    super.key,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: TacticalPalette.foreground,
          side: const BorderSide(color: TacticalPalette.foreground),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        child: Text(
          label,
          style: TacticalTypography.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 54),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: message,
            child: DecoratedBox(
              key: const ValueKey('interaction-feedback'),
              decoration: BoxDecoration(
                color: TacticalPalette.surface,
                border: Border.all(color: TacticalPalette.seaDeep),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TacticalTypography.body(
                    fontSize: 11,
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

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.state});

  final GameState state;

  @override
  void paint(Canvas canvas, Size size) {
    final routes = <(IslandState, IslandState, Faction)>[];
    for (final force in state.movingForces) {
      final source = _island(force.sourceIslandId);
      final destination = _island(force.destinationIslandId);
      if (source != null && destination != null) {
        routes.add((source, destination, force.faction));
      }
    }
    final selectedId = state.selectedIslandId;
    if (selectedId != null) {
      final source = _island(selectedId);
      if (source != null) {
        for (final destination
            in state.islands
                .where((island) => island.id != selectedId)
                .take(4)) {
          routes.add((source, destination, source.faction));
        }
      }
    }

    for (final route in routes) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round
        ..color =
            (route.$3 == Faction.cpu
                    ? TacticalPalette.cpuDeep
                    : TacticalPalette.playerDeep)
                .withValues(alpha: 0.58);
      _drawDashedLine(
        canvas,
        _centerFor(route.$1, size),
        _centerFor(route.$2, size),
        paint,
      );
    }
  }

  IslandState? _island(int id) {
    for (final island in state.islands) {
      if (island.id == id) return island;
    }
    return null;
  }

  Offset _centerFor(IslandState island, Size size) {
    final islandSize = GameRules.islandWidgetSize(island.size);
    return Offset(
      (size.width - islandSize) * (island.x + 1) / 2 + islandSize / 2,
      (size.height - islandSize) * (island.y + 1) / 2 + islandSize / 2,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final unit = delta / distance;
    const dash = 3.0;
    const gap = 7.0;
    for (var offset = 0.0; offset < distance; offset += dash + gap) {
      canvas.drawLine(
        start + unit * offset,
        start + unit * math.min(offset + dash, distance),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return state.movingForces != oldDelegate.state.movingForces ||
        state.selectedIslandId != oldDelegate.state.selectedIslandId ||
        state.islands != oldDelegate.state.islands;
  }
}
