import 'dart:math' as math;

import 'package:conquest/base.dart';
import 'package:conquest/faction_presentation.dart';
import 'package:conquest/moving_force.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/game_controller.dart';
import 'game/game_rules.dart';
import 'game/game_state.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/generated/app_localizations_en.dart';
import 'ui/tactical_map_background.dart';
import 'ui/tactical_theme.dart';

AppLocalizations _appLocalizations(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizationsEn();
}

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
    final l10n = _appLocalizations(context);
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final isPlayerInteractionEnabled =
        state.phase == GamePhase.playing &&
        state.configuration.gameMode == GameMode.playerVsCpu;
    final isLocalTwoPlayer =
        state.configuration.gameMode == GameMode.playerVsPlayer;
    final showHumanSelectionChrome =
        state.phase == GamePhase.playing &&
        (isPlayerInteractionEnabled || isLocalTwoPlayer);
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
            label: l10n.boardMapSemantics(
              islandCount: state.configuration.totalIslandCount,
            ),
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
                        selected:
                            state.selectedIslandId == island.id ||
                            state.opponentSelectedIslandId == island.id,
                        destinationCandidate:
                            showHumanSelectionChrome &&
                            (state.selectedIslandId != null ||
                                state.opponentSelectedIslandId != null) &&
                            state.selectedIslandId != island.id &&
                            state.opponentSelectedIslandId != island.id,
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
            _InteractionFeedback(type: state.interactionFeedback!),
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
          title: Text(_appLocalizations(context).quitTitle),
          content: Text(_appLocalizations(context).quitDescription),
          actions: [
            TextButton(
              key: const ValueKey('cancel-quit'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_appLocalizations(context).cancel.toUpperCase()),
            ),
            TextButton(
              key: const ValueKey('confirm-quit'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_appLocalizations(context).quit.toUpperCase()),
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
    final l10n = _appLocalizations(context);
    final selected = state.selectedIslandId != null;
    final isSpectator = state.configuration.gameMode == GameMode.cpuVsCpu;
    final isLocalTwoPlayer =
        state.configuration.gameMode == GameMode.playerVsPlayer;
    final playerSelected = state.selectedIslandId != null;
    final opponentSelected = state.opponentSelectedIslandId != null;
    final localPlayerStatus = playerSelected
        ? l10n.boardStatusLocalSelected
        : l10n.boardStatusLocalUnselected;
    final localOpponentStatus = opponentSelected
        ? l10n.boardStatusLocalSelected
        : l10n.boardStatusLocalUnselected;
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
                    l10n.brandName,
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
                    l10n.boardTitle(
                      islandCount: state.configuration.totalIslandCount,
                    ),
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
                    child: Semantics(
                      hint: isLocalTwoPlayer
                          ? l10n.boardStatusLocalDetail
                          : null,
                      child: Text(
                        key: const ValueKey('board-status-label'),
                        isLocalTwoPlayer
                            ? l10n.boardStatusLocalPlayer(
                                status: localPlayerStatus,
                              )
                            : isSpectator
                            ? l10n.spectatorStatus
                            : selected
                            ? l10n.boardStatusSelected
                            : l10n.boardStatusUnselected,
                        style: TacticalTypography.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TacticalPalette.foreground,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      key: const ValueKey('board-status-detail'),
                      isLocalTwoPlayer
                          ? l10n.boardStatusLocalOpponent(
                              status: localOpponentStatus,
                            )
                          : isSpectator
                          ? l10n.spectatorDetail
                          : selected
                          ? l10n.boardStatusSelectedDetail
                          : l10n.boardStatusUnselectedDetail,
                      textAlign: TextAlign.right,
                      style: TacticalTypography.body(
                        fontSize: 10,
                        color: TacticalPalette.seaDeep.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
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
    final l10n = _appLocalizations(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: l10n.pauseGame,
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
    final l10n = _appLocalizations(context);
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
                l10n.pauseHeading,
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
                l10n.pauseTitle,
                style: TacticalTypography.display(
                  fontSize: 30,
                  height: 1,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pauseDescription,
                style: TacticalTypography.body(
                  fontSize: 12,
                  color: TacticalPalette.muted,
                ),
              ),
              const SizedBox(height: 21),
              _PrimaryActionButton(
                key: const ValueKey('resume-game'),
                onPressed: onResume,
                label: l10n.resume,
              ),
              const SizedBox(height: 9),
              _SecondaryActionButton(
                key: const ValueKey('quit-game'),
                onPressed: onQuit,
                label: l10n.returnSettings,
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
    final l10n = _appLocalizations(context);
    final title = _resultTitle(l10n, configuration, result);
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
                l10n.resultHeading,
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
                label: l10n.replay,
              ),
              const SizedBox(height: 9),
              _SecondaryActionButton(
                key: const ValueKey('return-settings'),
                onPressed: onSettings,
                label: l10n.returnSettings,
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
    final l10n = _appLocalizations(context);
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
                        l10n.settingsStep,
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
                          l10n.settingsTitle,
                          style: TacticalTypography.display(
                            fontSize: 40,
                            height: 0.96,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.configuration.gameMode == GameMode.playerVsPlayer
                            ? l10n.settingsDescriptionLocal
                            : l10n.settingsDescription,
                        style: TacticalTypography.body(
                          fontSize: 12,
                          color: TacticalPalette.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        l10n.islandCountLabel,
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
                        l10n.gameModeLabel,
                        style: TacticalTypography.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _GameModeChoice(
                                  state: state,
                                  mode: GameMode.playerVsCpu,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: _GameModeChoice(
                                  state: state,
                                  mode: GameMode.playerVsPlayer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          _GameModeChoice(
                            state: state,
                            mode: GameMode.cpuVsCpu,
                          ),
                        ],
                      ),
                      if (state.configuration.gameMode !=
                          GameMode.playerVsPlayer) ...[
                        const SizedBox(height: 16),
                        Text(
                          state.configuration.gameMode == GameMode.cpuVsCpu
                              ? l10n.playerCpuDifficultyLabel
                              : l10n.cpuDifficultyLabel,
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
                            l10n.opponentCpuDifficultyLabel,
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
                      ],
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
                              label: _startLabel(l10n, state.configuration),
                              child: Text(
                                l10n.startGame,
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
                        _selectionSummary(l10n, state.configuration),
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
    final l10n = _appLocalizations(context);
    final selected = state.configuration.totalIslandCount == count;
    final semanticLabel = l10n.islandCountChoice(count: count);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
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
          tooltip: semanticLabel,
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
    final l10n = _appLocalizations(context);
    final selected =
        (playerCpu
            ? state.configuration.playerCpuDifficulty
            : state.configuration.cpuDifficulty) ==
        difficulty;
    final label = _difficultyLabel(l10n, difficulty);
    final owner = playerCpu
        ? '1P '
        : state.configuration.gameMode == GameMode.cpuVsCpu
        ? '2P '
        : '';
    final semanticLabel = l10n.difficultyChoice(
      owner: owner,
      difficulty: label,
    );
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, textAlign: TextAlign.center),
            ),
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
    final l10n = _appLocalizations(context);
    final selected = state.configuration.gameMode == mode;
    final label = _modeLabel(l10n, mode);
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, textAlign: TextAlign.center),
            ),
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
  GameMode.playerVsPlayer => 'player-vs-player',
  GameMode.cpuVsCpu => 'cpu-vs-cpu',
};

String _modeLabel(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.playerVsCpu => l10n.modePlayerVsCpu,
  GameMode.playerVsPlayer => l10n.modePlayerVsPlayer,
  GameMode.cpuVsCpu => l10n.modeCpuVsCpu,
};

String _startLabel(AppLocalizations l10n, GameConfiguration configuration) =>
    switch (configuration.gameMode) {
      GameMode.playerVsCpu => l10n.startGameSemantics(
        islandCount: configuration.totalIslandCount,
        difficulty: _difficultyLabel(l10n, configuration.cpuDifficulty),
      ),
      GameMode.playerVsPlayer => l10n.startLocalSemantics(
        islandCount: configuration.totalIslandCount,
      ),
      GameMode.cpuVsCpu => l10n.startSpectatorSemantics(
        islandCount: configuration.totalIslandCount,
        playerDifficulty: _difficultyLabel(
          l10n,
          configuration.playerCpuDifficulty,
        ),
        cpuDifficulty: _difficultyLabel(l10n, configuration.cpuDifficulty),
      ),
    };

String _selectionSummary(
  AppLocalizations l10n,
  GameConfiguration configuration,
) => switch (configuration.gameMode) {
  GameMode.cpuVsCpu => l10n.selectedSummarySpectator(
    islandCount: configuration.totalIslandCount,
    playerDifficulty: _difficultyLabel(l10n, configuration.playerCpuDifficulty),
    cpuDifficulty: _difficultyLabel(l10n, configuration.cpuDifficulty),
  ),
  GameMode.playerVsPlayer => l10n.selectedSummaryLocal(
    islandCount: configuration.totalIslandCount,
  ),
  GameMode.playerVsCpu => l10n.selectedSummary(
    islandCount: configuration.totalIslandCount,
    difficulty: _difficultyLabel(l10n, configuration.cpuDifficulty),
  ),
};

String _resultTitle(
  AppLocalizations l10n,
  GameConfiguration configuration,
  GameResult result,
) {
  if (configuration.gameMode == GameMode.playerVsCpu) {
    return switch (result.type) {
      GameResultType.victory => l10n.victory,
      GameResultType.defeat => l10n.defeat,
      GameResultType.draw => l10n.draw,
    };
  }
  return switch (result.winner) {
    Faction.player => l10n.spectatorPlayerWin,
    Faction.cpu => l10n.spectatorCpuWin,
    Faction.neutral || null => l10n.spectatorDraw,
  };
}

String _difficultyLabel(AppLocalizations l10n, CpuDifficulty difficulty) =>
    switch (difficulty) {
      CpuDifficulty.veryEasy => l10n.difficultyVeryEasy,
      CpuDifficulty.easy => l10n.difficultyEasy,
      CpuDifficulty.normal => l10n.difficultyNormal,
      CpuDifficulty.hard => l10n.difficultyHard,
    };

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = _appLocalizations(context);
    final text = _countdownText(l10n);
    if (text == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ColoredBox(
        color: TacticalPalette.outer.withValues(alpha: 0.11),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: l10n.countdownSemantics(countdown: text),
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
                          fontSize: text == l10n.startWord ? 42 : 82,
                          height: 0.9,
                          letterSpacing: text == l10n.startWord ? 1 : -4.9,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 23),
                Text(
                  l10n.prepareToDeploy,
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

  String? _countdownText(AppLocalizations l10n) {
    if (state.phase == GamePhase.startCountdown ||
        state.phase == GamePhase.resumeCountdown) {
      if (state.countdownRemainingMs > 2000) return '3';
      if (state.countdownRemainingMs > 1000) return '2';
      if (state.countdownRemainingMs > 0) return '1';
      return null;
    }
    if (state.phase == GamePhase.playing && state.elapsedMs == 0)
      return l10n.startWord;
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
  const _InteractionFeedback({required this.type});

  final InteractionFeedbackType type;

  @override
  Widget build(BuildContext context) {
    final l10n = _appLocalizations(context);
    final message = switch (type) {
      InteractionFeedbackType.unavailableSource =>
        l10n.feedbackUnavailableSource,
      InteractionFeedbackType.invalidatedSource =>
        l10n.feedbackInvalidatedSource,
    };
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
    final opponentSelectedId = state.opponentSelectedIslandId;
    if (opponentSelectedId != null) {
      final source = _island(opponentSelectedId);
      if (source != null) {
        for (final destination
            in state.islands
                .where((island) => island.id != opponentSelectedId)
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
        state.opponentSelectedIslandId !=
            oldDelegate.state.opponentSelectedIslandId ||
        state.islands != oldDelegate.state.islands;
  }
}
