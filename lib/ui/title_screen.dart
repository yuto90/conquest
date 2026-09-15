import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import 'tactical_theme.dart';

const _ink = Color(0xFF002C36);
const _paper = Color(0xFFF6F8F7);
const _referenceSize = Size(941, 1672);
// トップ画面の補助ボタンは、再表示するまで一時的に非表示にする。
const _showSecondaryActions = false;

/// The app's entry screen. Match state and navigation belong to its host.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();

    return LayoutBuilder(
      key: const ValueKey('title-view'),
      builder: (context, constraints) {
        final scale = constraints.maxWidth / _referenceSize.width;
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        // Keep secondary labels readable on narrow Web portrait stages.
        final secondaryWidth = largeText
            ? 667 * scale
            : math.max(562 * scale, math.min(constraints.maxWidth - 32, 260.0));
        final iconSize = 70 * scale;
        final iconTarget = math.max(48.0, iconSize);
        final iconInset = (iconTarget - iconSize) / 2;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      'assets/title/isles_chart.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(height: constraints.maxHeight * 666 / 1672),
                    Center(child: _ReferenceWordmark(scale: scale)),
                    SizedBox(height: 31 * scale),
                    SizedBox(
                      width: 656 * scale,
                      height: 28 * scale,
                      child: const _Tagline(),
                    ),
                    SizedBox(height: 42 * scale),
                    SizedBox(
                      width: 667 * scale,
                      child: _TitleButton(
                        buttonKey: const ValueKey('title-start'),
                        label: 'START',
                        semanticLabel: l10n.titleStart,
                        onPressed: onStart,
                        scale: scale,
                        primary: true,
                      ),
                    ),
                    if (_showSecondaryActions) ...[
                      SizedBox(height: 42 * scale),
                      SizedBox(
                        width: secondaryWidth,
                        child: largeText
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _settingsButton(l10n, scale),
                                  const SizedBox(height: 12),
                                  _helpButton(context, l10n, scale),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: _settingsButton(l10n, scale)),
                                  SizedBox(width: 24 * scale),
                                  Expanded(
                                    child: _helpButton(context, l10n, scale),
                                  ),
                                ],
                              ),
                      ),
                    ],
                    // Let short screens and enlarged text scroll every action
                    // into view without shrinking interactive targets.
                    SizedBox(height: math.max(24.0, 32 * scale)),
                  ],
                ),
                if (_showSecondaryActions)
                  Positioned(
                    top: math.max(4.0, 60 * scale - iconInset),
                    right: math.max(4.0, 44 * scale - iconInset),
                    child: Row(
                      children: [
                        _ChartIconButton(
                          buttonKey: const ValueKey('title-sound'),
                          icon: CupertinoIcons.speaker_2_fill,
                          tooltip: l10n.titleSound,
                          size: iconSize,
                          onPressed: () => _showInformation(
                            context,
                            title: l10n.titleSound,
                            content: Text(l10n.titleSoundDescription),
                            closeLabel: l10n.titleClose,
                          ),
                        ),
                        SizedBox(
                          width: math.max(0.0, 30 * scale - 2 * iconInset),
                        ),
                        _ChartIconButton(
                          buttonKey: const ValueKey('title-settings-icon'),
                          icon: CupertinoIcons.gear_alt_fill,
                          tooltip: l10n.settingsTitle,
                          size: iconSize,
                          onPressed: onStart,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingsButton(AppLocalizations l10n, double scale) => _TitleButton(
    buttonKey: const ValueKey('title-settings'),
    label: 'SETTINGS',
    semanticLabel: l10n.settingsTitle,
    icon: CupertinoIcons.gear_alt,
    onPressed: onStart,
    scale: scale,
  );

  Widget _helpButton(
    BuildContext context,
    AppLocalizations l10n,
    double scale,
  ) => _TitleButton(
    buttonKey: const ValueKey('title-how-to-play'),
    label: 'HOW TO PLAY',
    semanticLabel: l10n.titleHowToPlay,
    icon: CupertinoIcons.book,
    onPressed: () => _showInformation(
      context,
      title: l10n.titleHowToPlay,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.titleHowToGoal),
          const SizedBox(height: 20),
          Text(l10n.titleHowToSelect),
          const SizedBox(height: 16),
          Text(l10n.titleHowToSend),
          const SizedBox(height: 16),
          Text(l10n.titleHowToCapture),
        ],
      ),
      closeLabel: l10n.titleClose,
    ),
    scale: scale,
  );
}

/// Uses only the supplied wordmark, retaining its original letterforms.
/// The color key removes turquoise paper from the tightly bounded crop.
/// All controls and the rest of the screen are independent Flutter widgets.
class _ReferenceWordmark extends StatelessWidget {
  const _ReferenceWordmark({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('title-wordmark'),
    header: true,
    image: true,
    label: 'CONQUEST ISLES',
    child: ExcludeSemantics(
      child: SizedBox(
        width: 821 * scale,
        height: 130 * scale,
        child: ClipRect(
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              -5.1,
              0,
              0,
              0,
              510,
            ]),
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: _referenceSize.width * scale,
              maxWidth: _referenceSize.width * scale,
              minHeight: _referenceSize.height * scale,
              maxHeight: _referenceSize.height * scale,
              child: Transform.translate(
                offset: Offset(-60 * scale, -666 * scale),
                child: Image.asset(
                  'assets/title/title_reference.png',
                  width: _referenceSize.width * scale,
                  height: _referenceSize.height * scale,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Builder(
      builder: (context) {
        final typography = TacticalTypography.of(context);
        return FittedBox(
          child: Row(
            children: [
              const SizedBox(
                width: 80,
                child: Divider(color: _ink, thickness: 2),
              ),
              const SizedBox(width: 26),
              Text(
                'A STRATEGY FOR A WIDER WORLD',
                textScaler: TextScaler.noScaling,
                style: typography.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.5,
                  color: _ink.withValues(alpha: 0.85),
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 26),
              const SizedBox(
                width: 80,
                child: Divider(color: _ink, thickness: 2),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _TitleButton extends StatelessWidget {
  const _TitleButton({
    required this.buttonKey,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    required this.scale,
    this.primary = false,
    this.icon,
  });

  final Key buttonKey;
  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;
  final double scale;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final typography = TacticalTypography.of(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: math.max(18, 42 * scale)),
          SizedBox(width: 20 * scale),
        ],
        Align(
          widthFactor: primary ? 1 : 0.86,
          heightFactor: 1,
          child: Transform.scale(
            scaleX: primary ? 1 : 0.86,
            child: Text(
              label,
              semanticsLabel: semanticLabel,
              style: typography.display(
                fontSize: math.max(
                  primary ? 20 : 12,
                  (primary ? 50 : 26) * scale,
                ),
                fontWeight: primary ? FontWeight.w600 : FontWeight.w700,
                letterSpacing: (primary ? 13 : 0) * scale,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: _ink.withValues(alpha: 0.17),
                  blurRadius: 32 * scale,
                  offset: Offset(0, 12 * scale),
                ),
              ]
            : null,
      ),
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        autofocus: primary,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, math.max(48, (primary ? 141 : 93) * scale)),
          visualDensity: VisualDensity.standard,
          padding: EdgeInsets.symmetric(
            horizontal: math.max(6, 20 * scale),
            vertical: math.max(12, 20 * scale),
          ),
          backgroundColor: primary
              ? const Color(0xFF032B36)
              : Colors.transparent,
          foregroundColor: primary ? _paper : _ink,
          side: BorderSide(
            color: primary ? const Color(0xFFB3DCD9) : _ink,
            width: math.max(1, (primary ? 1.5 : 2.5) * scale),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: content),
      ),
    );
  }
}

class _ChartIconButton extends StatelessWidget {
  const _ChartIconButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(48),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      foregroundColor: _ink,
      shape: const CircleBorder(),
    ),
    icon: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _ink, width: math.max(1, size / 38)),
      ),
      child: Icon(icon, size: size * 0.48),
    ),
  );
}

Future<void> _showInformation(
  BuildContext context, {
  required String title,
  required Widget content,
  required String closeLabel,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(child: content),
    actions: [
      TextButton(
        key: const ValueKey('title-dialog-close'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(closeLabel),
      ),
    ],
  ),
);
