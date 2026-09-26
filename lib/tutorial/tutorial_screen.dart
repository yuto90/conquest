import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../base.dart';
import '../faction_presentation.dart';
import '../moving_force.dart';
import '../game/game_rules.dart';
import '../game/game_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import '../ui/tactical_map_background.dart';
import '../ui/tactical_theme.dart';
import 'tutorial_session.dart';

AppLocalizations _tutorialLocalizations(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizationsEn();
}

/// The hands-on tutorial surface. It renders a private [TutorialSession] and
/// never reads or mutates the normal match controller.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    required this.session,
    required this.onExit,
    this.spectatorSelected = false,
    super.key,
  });

  final TutorialSession session;
  final VoidCallback onExit;
  final bool spectatorSelected;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  Timer? _movementTimer;

  @override
  void initState() {
    super.initState();
    _movementTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => widget.session.tick(50),
    );
  }

  @override
  void didUpdateWidget(covariant TutorialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _movementTimer?.cancel();
      _movementTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => widget.session.tick(50),
      );
    }
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        SingleActivator(LogicalKeyboardKey.escape): widget.onExit,
      },
      child: Focus(
        autofocus: true,
        child: AnimatedBuilder(
          animation: widget.session,
          builder: (context, _) {
            final session = widget.session;
            return Stack(
              key: const ValueKey('tutorial-screen'),
              fit: StackFit.expand,
              children: [
                const TacticalMapBackground(),
                LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      _TutorialInfoCard(
                        session: session,
                        spectatorSelected: widget.spectatorSelected,
                        onExit: widget.onExit,
                        maxHeight: math.min(
                          230,
                          math.max(154, constraints.maxHeight * 0.38),
                        ),
                      ),
                      Expanded(
                        child: _TutorialMap(
                          session: session,
                          onIslandTap: session.tapIsland,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.lifecyclePaused)
                  _TutorialLifecycleOverlay(
                    onResume: session.resumeAfterLifecycle,
                    canResume: session.canResumeAfterLifecycle,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TutorialInfoCard extends StatelessWidget {
  const _TutorialInfoCard({
    required this.session,
    required this.spectatorSelected,
    required this.onExit,
    required this.maxHeight,
  });

  final TutorialSession session;
  final bool spectatorSelected;
  final VoidCallback onExit;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = _tutorialLocalizations(context);
    final step = session.step;
    final stepNumber = step.index + 1;
    final title = switch (step) {
      TutorialStep.selectSource => l10n.tutorialStepSourceTitle,
      TutorialStep.selectDestination => l10n.tutorialStepDestinationTitle,
      TutorialStep.watchCapture => l10n.tutorialStepCaptureTitle,
      TutorialStep.explainVictory => l10n.tutorialStepVictoryTitle,
    };
    final description = switch (step) {
      TutorialStep.selectSource => l10n.tutorialSourceInstruction,
      TutorialStep.selectDestination => l10n.tutorialDestinationInstruction,
      TutorialStep.watchCapture => l10n.tutorialCaptureInstruction,
      TutorialStep.explainVictory => l10n.tutorialVictoryInstruction,
    };
    final retry = switch (session.retryPrompt) {
      TutorialStep.selectSource => l10n.tutorialRetrySource,
      TutorialStep.selectDestination => l10n.tutorialRetryDestination,
      TutorialStep.watchCapture => l10n.tutorialRetryCapture,
      TutorialStep.explainVictory || null => null,
    };

    return SizedBox(
      height: maxHeight,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '$title. $description',
        child: DecoratedBox(
          key: const ValueKey('tutorial-info-card'),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              TacticalPalette.surface.withValues(alpha: 0.95),
              TacticalPalette.background,
            ),
            border: Border(
              bottom: BorderSide(
                color: TacticalPalette.border.withValues(alpha: 0.78),
              ),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tutorialTitle,
                        style: TacticalTypography.of(context).mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: TacticalPalette.muted,
                        ),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        key: const ValueKey('tutorial-back'),
                        onPressed: onExit,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: TacticalPalette.foreground,
                        ),
                        child: Text(
                          l10n.tutorialBack,
                          maxLines: 2,
                          softWrap: true,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TacticalTypography.of(
                          context,
                        ).display(fontSize: 25, height: 1, letterSpacing: -0.5),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        l10n.tutorialProgress(step: stepNumber),
                        maxLines: 2,
                        softWrap: true,
                        textAlign: TextAlign.end,
                        style: TacticalTypography.of(context).mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: TacticalPalette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TacticalTypography.of(context).body(
                    fontSize: 12,
                    color: TacticalPalette.muted,
                    height: 1.35,
                  ),
                ),
                if (spectatorSelected) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.tutorialSpectatorNotice,
                    key: const ValueKey('tutorial-spectator-notice'),
                    style: TacticalTypography.of(context).body(
                      fontSize: 11,
                      color: TacticalPalette.cpuDeep,
                      height: 1.3,
                    ),
                  ),
                ],
                if (retry != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    retry,
                    key: const ValueKey('tutorial-retry-prompt'),
                    style: TacticalTypography.of(context).body(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: TacticalPalette.playerDeep,
                      height: 1.3,
                    ),
                  ),
                ],
                if (step == TutorialStep.watchCapture &&
                    session.dispatchedStrength > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.tutorialDispatchFromTo(
                      remaining: session.sourceForcesAfterDispatch,
                    ),
                    style: TacticalTypography.of(context).mono(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: TacticalPalette.foreground,
                    ),
                  ),
                  Text(
                    l10n.tutorialDispatchBreakdown(
                      sent: session.dispatchedStrength,
                      remaining: session.sourceForcesAfterDispatch,
                    ),
                    style: TacticalTypography.of(
                      context,
                    ).mono(fontSize: 11, color: TacticalPalette.muted),
                  ),
                  if (session.hasArrived) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.tutorialCaptureValues(
                              attack: session.dispatchedStrength,
                              defense: 10,
                            ),
                            softWrap: true,
                            style: TacticalTypography.of(context).mono(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: TacticalPalette.playerDeep,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.tutorialCaptureComplete,
                            softWrap: true,
                            style: TacticalTypography.of(context).body(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TacticalPalette.playerDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _TutorialActionButton(
                      key: const ValueKey('tutorial-next'),
                      label: l10n.tutorialNext,
                      onPressed: session.advanceAfterCapture,
                    ),
                  ],
                ],
                if (step == TutorialStep.explainVictory) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.tutorialGrowthDemo(growth: session.growthDemonstrated),
                    key: const ValueKey('tutorial-growth-demo'),
                    style: TacticalTypography.of(context).mono(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TacticalPalette.playerDeep,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TutorialRuleCallouts(l10n: l10n),
                  const SizedBox(height: 6),
                  _TutorialActionButton(
                    key: const ValueKey('tutorial-return-settings'),
                    label: l10n.tutorialReturnSettings,
                    onPressed: onExit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialActionButton extends StatelessWidget {
  const _TutorialActionButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: TacticalPalette.foreground,
          side: const BorderSide(color: TacticalPalette.foreground),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        child: Text(
          label,
          maxLines: 2,
          softWrap: true,
          textAlign: TextAlign.center,
          style: TacticalTypography.of(
            context,
          ).body(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TutorialLifecycleOverlay extends StatelessWidget {
  const _TutorialLifecycleOverlay({
    required this.onResume,
    required this.canResume,
  });

  final VoidCallback onResume;
  final bool canResume;

  @override
  Widget build(BuildContext context) {
    final l10n = _tutorialLocalizations(context);
    return ColoredBox(
      color: TacticalPalette.outer.withValues(alpha: 0.30),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: TacticalPalette.surface,
              border: Border.all(color: TacticalPalette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tutorialLifecyclePaused,
                    textAlign: TextAlign.center,
                    style: TacticalTypography.of(
                      context,
                    ).body(fontSize: 13, height: 1.4),
                  ),
                  if (!canResume) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.tutorialLifecycleResizeRequired,
                      textAlign: TextAlign.center,
                      style: TacticalTypography.of(
                        context,
                      ).body(fontSize: 12, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _TutorialActionButton(
                    key: const ValueKey('tutorial-resume'),
                    label: l10n.tutorialResume,
                    onPressed: canResume ? onResume : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialRuleCallouts extends StatelessWidget {
  const _TutorialRuleCallouts({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('tutorial-rule-callouts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tutorialRulesHeading,
          style: TacticalTypography.of(context).mono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: TacticalPalette.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        _TutorialRuleCallout(
          key: const ValueKey('tutorial-rule-equal-forces'),
          icon: Icons.compare_arrows_rounded,
          label: l10n.tutorialRuleEqualForces,
        ),
        const SizedBox(height: 4),
        _TutorialRuleCallout(
          key: const ValueKey('tutorial-rule-reinforce'),
          icon: Icons.arrow_forward_rounded,
          label: l10n.tutorialRuleReinforce,
        ),
        const SizedBox(height: 4),
        _TutorialRuleCallout(
          key: const ValueKey('tutorial-rule-minimum-forces'),
          icon: Icons.block_rounded,
          label: l10n.tutorialRuleMinimumForces,
        ),
      ],
    );
  }
}

class _TutorialRuleCallout extends StatelessWidget {
  const _TutorialRuleCallout({
    required this.icon,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TacticalPalette.surface.withValues(alpha: 0.78),
            border: Border.all(color: TacticalPalette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Icon(icon, size: 18, color: TacticalPalette.playerDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TacticalTypography.of(context).body(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: TacticalPalette.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialMap extends StatefulWidget {
  const _TutorialMap({required this.session, required this.onIslandTap});

  final TutorialSession session;
  final ValueChanged<int> onIslandTap;

  @override
  State<_TutorialMap> createState() => _TutorialMapState();
}

class _TutorialMapState extends State<_TutorialMap> {
  Size? _lastMapSize;
  var _pauseScheduled = false;

  @override
  Widget build(BuildContext context) {
    final l10n = _tutorialLocalizations(context);
    final session = widget.session;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = IslandMapViewport(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        final mapSize = Size(viewport.width, viewport.height);
        if (_lastMapSize != null &&
            _lastMapSize != mapSize &&
            !session.lifecyclePaused &&
            !_pauseScheduled) {
          // A resize never advances a troop automatically. The overlay stays
          // until the player explicitly resumes the practice movement.
          _pauseScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pauseScheduled = false;
            if (mounted) session.pauseForLifecycle();
          });
        }
        _lastMapSize = mapSize;
        session.updateViewport(viewport);
        final state = session.gameState;
        final canTap =
            session.step == TutorialStep.selectSource ||
            session.step == TutorialStep.selectDestination ||
            (session.step == TutorialStep.watchCapture && !session.hasArrived);
        final highlightedIslandId = switch (session.step) {
          TutorialStep.selectSource => TutorialSession.playerHeadquartersId,
          TutorialStep.explainVictory => 1,
          TutorialStep.selectDestination || TutorialStep.watchCapture => null,
        };
        return Semantics(
          container: true,
          label: l10n.tutorialBoardSemantics(step: session.step.index + 1),
          child: Stack(
            key: const ValueKey('tutorial-map'),
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _TutorialRoutePainter(state: state)),
              for (final island in state.islands)
                Align(
                  key: ValueKey('tutorial-island-${island.id}'),
                  alignment: Alignment(island.x, island.y),
                  child: SizedBox.square(
                    dimension: GameRules.islandWidgetSize(island.size),
                    child: Base(
                      key: ValueKey('tutorial-island-button-${island.id}'),
                      base: island,
                      presentation: FactionPresentation.forMode(
                        GameMode.playerVsCpu,
                        island.faction,
                      ),
                      selected: state.selectedIslandId == island.id,
                      highlighted: highlightedIslandId == island.id,
                      highlightColor: island.faction == Faction.cpu
                          ? TacticalPalette.cpu
                          : TacticalPalette.player,
                      destinationCandidate:
                          session.step == TutorialStep.selectDestination &&
                          island.id == TutorialSession.targetIslandId,
                      onPressed: canTap
                          ? () => widget.onIslandTap(island.id)
                          : null,
                    ),
                  ),
                ),
              for (final force in state.movingForces)
                Align(
                  key: ValueKey('tutorial-moving-force-${force.id}'),
                  alignment: Alignment(force.x, force.y),
                  child: MovingForceWidget(
                    force: force,
                    boardSize: Size(viewport.width, viewport.height),
                    presentation: FactionPresentation.forMode(
                      GameMode.playerVsCpu,
                      force.faction,
                    ),
                    semanticsKey: ValueKey(
                      'tutorial-moving-force-semantics-${force.id}',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TutorialRoutePainter extends CustomPainter {
  const _TutorialRoutePainter({required this.state});

  final GameState state;

  @override
  void paint(Canvas canvas, Size size) {
    final selectedId = state.selectedIslandId;
    final routes = <(IslandState, IslandState, Faction)>[];
    for (final force in state.movingForces) {
      final source = _island(force.sourceIslandId);
      final destination = _island(force.destinationIslandId);
      if (source != null && destination != null) {
        routes.add((source, destination, force.faction));
      }
    }
    if (selectedId != null) {
      final source = _island(selectedId);
      if (source != null) {
        final target = _island(TutorialSession.targetIslandId);
        if (target != null) routes.add((source, target, Faction.player));
      }
    }
    for (final route in routes) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round
        ..color = TacticalPalette.playerDeep.withValues(alpha: 0.62);
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
  bool shouldRepaint(covariant _TutorialRoutePainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
