import 'package:flutter/material.dart';

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

abstract final class TacticalTypography {
  static const displayFamily = 'Avenir Next Condensed';
  static const bodyFamily = 'Hiragino Sans';
  static const monoFamily = 'SFMono-Regular';
  static const fallbacks = <String>['Avenir Next', 'Yu Gothic', 'sans-serif'];

  static TextStyle display({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color color = TacticalPalette.foreground,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontFamilyFallback: fallbacks,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double? fontSize,
    FontWeight? fontWeight,
    Color color = TacticalPalette.foreground,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontFamilyFallback: fallbacks,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color color = TacticalPalette.foreground,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: const <String>['Menlo', 'monospace'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

ThemeData buildTacticalTheme() {
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
    fontFamily: TacticalTypography.bodyFamily,
    fontFamilyFallback: TacticalTypography.fallbacks,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: TacticalPalette.foreground,
      selectionColor: TacticalPalette.border,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
