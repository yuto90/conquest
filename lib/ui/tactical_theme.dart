import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

abstract final class TacticalPalette {
  static const background = Color(0xFF84C9C6);
  static const surface = Color(0xFFA8DDD9);
  static const foreground = Color(0xFF002128);
  static const muted = Color(0xFF2B585C);
  static const border = Color(0xFF568F8E);
  static const accent = Color(0xFF069A4A);
  static const seaDeep = Color(0xFF003F46);
  static const paper = Color(0xFFE7FAF8);
  static const outer = Color(0xFF001216);
  static const player = Color(0xFF028C43);
  static const playerDeep = Color(0xFF003C1F);
  static const cpu = Color(0xFFBC4A3F);
  static const cpuDeep = Color(0xFF561E1B);
  static const neutral = Color(0xFF516F73);

  static Color factionBackground(bool isPlayer, bool isCpu) {
    if (isPlayer) return player;
    if (isCpu) return cpu;
    return Color.alphaBlend(neutral.withValues(alpha: 0.67), background);
  }
}

final class TacticalTypography {
  const TacticalTypography._({
    required this.fontFamily,
    required this.fontFamilyFallback,
  });

  static const notoSansJpFamily = 'Noto Sans JP';
  static const robotoFamily = 'Roboto';

  static const english = TacticalTypography._(
    fontFamily: robotoFamily,
    fontFamilyFallback: <String>[notoSansJpFamily],
  );
  static const japanese = TacticalTypography._(
    fontFamily: notoSansJpFamily,
    fontFamilyFallback: <String>[robotoFamily],
  );

  final String fontFamily;
  final List<String> fontFamilyFallback;

  /// Returns typography for the locale resolved by [AppLocalizations].
  ///
  /// The localization delegate reduces regional locales to the supported
  /// language locale, so this method intentionally reads [localeName] rather
  /// than inspecting the device locale independently.
  static TacticalTypography of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return forLocaleName(localizations?.localeName ?? 'en');
  }

  static TacticalTypography forLocale(Locale locale) =>
      forLocaleName(locale.languageCode);

  static TacticalTypography forLocaleName(String localeName) {
    final languageCode = localeName.split(RegExp('[-_]')).first.toLowerCase();
    return languageCode == 'ja' ? japanese : english;
  }

  TextStyle display({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color color = TacticalPalette.foreground,
    double? height,
    double? letterSpacing,
  }) {
    return _style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle body({
    double? fontSize,
    FontWeight? fontWeight,
    Color color = TacticalPalette.foreground,
    double? height,
    double? letterSpacing,
  }) {
    return _style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color color = TacticalPalette.foreground,
    double? height,
    double? letterSpacing,
  }) {
    return _style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle _style({
    double? fontSize,
    FontWeight? fontWeight,
    Color color = TacticalPalette.foreground,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

ThemeData buildTacticalTheme({
  TacticalTypography typography = TacticalTypography.english,
}) {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: TacticalPalette.accent,
        brightness: Brightness.light,
        surface: TacticalPalette.surface,
      ).copyWith(
        primary: TacticalPalette.foreground,
        onPrimary: TacticalPalette.paper,
        secondary: TacticalPalette.player,
        onSecondary: TacticalPalette.paper,
        error: TacticalPalette.cpu,
        onError: TacticalPalette.paper,
        surface: TacticalPalette.surface,
        onSurface: TacticalPalette.foreground,
        outline: TacticalPalette.border,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: TacticalPalette.background,
    fontFamily: typography.fontFamily,
    fontFamilyFallback: typography.fontFamilyFallback,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: TacticalPalette.foreground,
      selectionColor: TacticalPalette.border,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
