import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import 'tactical_map_background.dart';
import 'tactical_theme.dart';

/// The app's entry screen. Match state and navigation belong to its host.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();

    return Stack(
      key: const ValueKey('title-view'),
      fit: StackFit.expand,
      children: [
        const TacticalMapBackground(),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.brandName,
                          textAlign: TextAlign.center,
                          style: TacticalTypography.display(
                            fontSize: 48,
                            height: 1.1,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        key: const ValueKey('title-start'),
                        onPressed: onStart,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          visualDensity: VisualDensity.standard,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          elevation: 0,
                          backgroundColor: TacticalPalette.foreground,
                          foregroundColor: TacticalPalette.paper,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                        child: Text(
                          l10n.titleStart,
                          textAlign: TextAlign.center,
                          style: TacticalTypography.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: TacticalPalette.paper,
                            height: 1.4,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
