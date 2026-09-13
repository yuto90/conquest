import 'package:flutter/material.dart';

import 'faction_presentation.dart';
import 'game/game_state.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/generated/app_localizations_en.dart';
import 'ui/island_assets.dart';
import 'ui/tactical_theme.dart';

/// Tactical-chart renderer for one island.
///
/// The supplied island image communicates the landform and faction treatment.
/// Gameplay feedback, values, and accessibility remain Flutter overlays so
/// they update independently of the asset and stay available to assistive
/// technologies.
class Base extends StatelessWidget {
  const Base({
    required this.base,
    required this.onPressed,
    this.presentation,
    this.selected = false,
    this.destinationCandidate = false,
    super.key,
  });

  final IslandState base;
  final VoidCallback? onPressed;
  final FactionPresentation? presentation;
  final bool selected;
  final bool destinationCandidate;

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final isHeadquarters = base.size == IslandSize.headquarters;
    final numberColor = base.faction == Faction.neutral
        ? TacticalPalette.foreground
        : TacticalPalette.paper;
    final interactive = onPressed != null;
    final assetPath = islandAssetPath(islandId: base.id, faction: base.faction);

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: interactive,
      enabled: interactive,
      selected: interactive && selected,
      onTap: onPressed,
      label: _semanticLabel(l10n),
      hint: interactive ? _semanticHint(l10n) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          excludeFromSemantics: true,
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IslandAssetImage(
                    assetPath: assetPath,
                    faction: base.faction,
                    isHeadquarters: isHeadquarters,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _IslandFeedbackPainter(
                      selected: selected,
                      destinationCandidate: destinationCandidate,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: isHeadquarters && base.y > 0
                    ? const Offset(0, -8)
                    : Offset.zero,
                child: _IslandStatusPanel(
                  base: base,
                  marker: _effectivePresentation.marker,
                  isHeadquarters: isHeadquarters,
                  numberColor: numberColor,
                ),
              ),
              if (isHeadquarters)
                Positioned(
                  top: 4,
                  right: 4,
                  child: _HeadquartersMarker(
                    key: ValueKey('island-${base.id}-hq-marker'),
                    faction: base.faction,
                  ),
                ),
              if (selected)
                Positioned(
                  top: -14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TacticalPalette.surface,
                      border: Border.all(color: TacticalPalette.playerDeep),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        l10n.sourceBadge,
                        style: TacticalTypography.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: TacticalPalette.playerDeep,
                          height: 1,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  FactionPresentation get _effectivePresentation =>
      presentation ??
      FactionPresentation.forMode(GameMode.playerVsCpu, base.faction);

  String _sizeName(AppLocalizations l10n) => switch (base.size) {
    IslandSize.small => l10n.islandSizeSmall,
    IslandSize.medium => l10n.islandSizeMedium,
    IslandSize.large => l10n.islandSizeLarge,
    IslandSize.headquarters => l10n.islandSizeHeadquarters,
  };

  String _factionName(AppLocalizations l10n) {
    if (_effectivePresentation.semanticName == '1P') {
      return l10n.factionPlayerOne;
    }
    if (_effectivePresentation.semanticName == '2P') {
      return l10n.factionPlayerTwo;
    }
    return switch (base.faction) {
      Faction.player => l10n.factionPlayer,
      Faction.cpu => l10n.factionCpu,
      Faction.neutral => l10n.factionNeutral,
    };
  }

  String _semanticLabel(AppLocalizations l10n) {
    final identity = base.faction == Faction.neutral
        ? l10n.islandNeutralSemantics(
            faction: _factionName(l10n),
            size: _sizeName(l10n),
            durability: base.currentDurability,
            value: base.currentValue,
          )
        : l10n.islandOwnedSemantics(
            faction: _factionName(l10n),
            size: _sizeName(l10n),
            forces: base.currentForces,
            capacity: base.capacity,
            value: base.currentValue,
          );
    if (onPressed == null) return identity;
    final action = selected
        ? l10n.islandActionSelected
        : destinationCandidate
        ? l10n.islandActionDestination
        : base.canDispatch
        ? l10n.islandActionAvailable
        : l10n.islandActionUnavailable;
    return '$identity, $action';
  }

  String? _semanticHint(AppLocalizations l10n) {
    if (onPressed == null) return null;
    if (selected) {
      return l10n.islandHintSelected;
    }
    if (destinationCandidate) return l10n.islandHintDestination;
    if (base.canDispatch) {
      return l10n.islandHintAvailable;
    }
    return l10n.islandHintUnavailable;
  }
}

class _IslandStatusPanel extends StatelessWidget {
  const _IslandStatusPanel({
    required this.base,
    required this.marker,
    required this.isHeadquarters,
    required this.numberColor,
  });

  final IslandState base;
  final String marker;
  final bool isHeadquarters;
  final Color numberColor;

  @override
  Widget build(BuildContext context) {
    final accent = switch (base.faction) {
      Faction.player => TacticalPalette.player,
      Faction.cpu => TacticalPalette.cpu,
      Faction.neutral => TacticalPalette.neutral,
    };
    final panelColor = base.faction == Faction.neutral
        ? TacticalPalette.surface.withValues(alpha: 0.84)
        : TacticalPalette.outer.withValues(alpha: 0.72);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(color: accent.withValues(alpha: 0.72), width: 0.8),
        borderRadius: BorderRadius.circular(isHeadquarters ? 12 : 10),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isHeadquarters ? 7 : 5,
          vertical: isHeadquarters ? 4 : 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              marker,
              style: TacticalTypography.mono(
                fontSize: isHeadquarters ? 10 : 8,
                fontWeight: FontWeight.w800,
                color: numberColor,
                height: 1,
              ),
            ),
            Text(
              base.currentValue.toString(),
              key: base.faction == Faction.neutral
                  ? ValueKey('island-${base.id}-value')
                  : ValueKey('island-${base.id}-current'),
              style:
                  TacticalTypography.display(
                    fontSize: isHeadquarters ? 27 : 20,
                    fontWeight: FontWeight.w800,
                    color: numberColor,
                    height: 1,
                    letterSpacing: -0.8,
                  ).copyWith(
                    shadows: base.faction == Faction.neutral
                        ? null
                        : const <Shadow>[
                            Shadow(
                              color: Color(0xB0001116),
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ],
                  ),
            ),
            if (base.faction != Faction.neutral)
              Text(
                '/${base.capacity}',
                key: ValueKey('island-${base.id}-capacity'),
                style: TacticalTypography.mono(
                  fontSize: isHeadquarters ? 9 : 8,
                  fontWeight: FontWeight.w700,
                  color: numberColor.withValues(alpha: 0.86),
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeadquartersMarker extends StatelessWidget {
  const _HeadquartersMarker({required this.faction, super.key});

  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final color = switch (faction) {
      Faction.player => TacticalPalette.player,
      Faction.cpu => TacticalPalette.cpu,
      Faction.neutral => TacticalPalette.neutral,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TacticalPalette.surface.withValues(alpha: 0.88),
        border: Border.all(color: color, width: 1),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(Icons.fort_rounded, size: 10, color: color),
      ),
    );
  }
}

class _IslandFeedbackPainter extends CustomPainter {
  const _IslandFeedbackPainter({
    required this.selected,
    required this.destinationCandidate,
  });

  final bool selected;
  final bool destinationCandidate;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale, scale);

    if (selected) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = TacticalPalette.playerDeep;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 4, 92, 92),
          const Radius.circular(20),
        ),
        ringPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(10, 10, 80, 80),
          const Radius.circular(17),
        ),
        ringPaint..color = TacticalPalette.player,
      );
    }

    if (destinationCandidate) _paintDestinationBrackets(canvas);
    canvas.restore();
  }

  void _paintDestinationBrackets(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = TacticalPalette.seaDeep.withValues(alpha: 0.72);
    const inset = 1.0;
    const length = 14.0;
    for (final path in <Path>[
      Path()
        ..moveTo(inset, inset + length)
        ..lineTo(inset, inset)
        ..lineTo(inset + length, inset),
      Path()
        ..moveTo(100 - inset - length, inset)
        ..lineTo(100 - inset, inset)
        ..lineTo(100 - inset, inset + length),
      Path()
        ..moveTo(inset, 100 - inset - length)
        ..lineTo(inset, 100 - inset)
        ..lineTo(inset + length, 100 - inset),
      Path()
        ..moveTo(100 - inset - length, 100 - inset)
        ..lineTo(100 - inset, 100 - inset)
        ..lineTo(100 - inset, 100 - inset - length),
    ]) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IslandFeedbackPainter oldDelegate) {
    return selected != oldDelegate.selected ||
        destinationCandidate != oldDelegate.destinationCandidate;
  }
}
