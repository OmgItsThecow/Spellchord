// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/models/harmonic_function.dart';

/// Strict dark-mode-only palette and typography tokens.
class AppDarkTheme {
  AppDarkTheme._();

  static const Color bgPrimary = Color(0xFF121212);
  static const Color bgWorkspace = Color(0xFF18181B);
  static const Color cardSurface = Color(0xFF1E1E24);
  static const Color cardElevated = Color(0xFF25252D);
  static const Color borderSubtle = Color(0xFF2E2E38);

  static const Color textPrimary = Color(0xFFF4F4F6);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Muted harmonic function accents
  static const Color tonicColor = Color(0xFF4FD1C5);
  static const Color pelicanPink = Color(0xFFF28BA8);
  static const Color subdominantColor = Color(0xFFF6AD55);
  static const Color dominantColor = Color(0xFFFC8181);
  static const Color secondaryDomColor = Color(0xFFB794F4);
  static const Color diminishedPassingColor = Color(0xFFF687B3);
  static const Color borrowedColor = Color(0xFF63B3ED);
  static const Color chromaticColor = Color(0xFF9F7AEA);

  // Visualizer note role colors
  static const Color rootNoteHighlight = Color(0xFFF6AD55);
  static const Color upperNoteHighlight = Color(0xFF4FD1C5);
  static const Color commonToneHighlight = Color(0xFF68D391);

  /// Primary UI accent: Pelican Pink in Piano Mode, Teal in Guitar Mode.
  static Color accentFor({required bool isPiano}) =>
      isPiano ? pelicanPink : tonicColor;

  static Color colorForCategory(
    HarmonicCategory category, {
    bool isPiano = false,
  }) {
    switch (category) {
      case HarmonicCategory.tonic:
        return accentFor(isPiano: isPiano);
      case HarmonicCategory.subdominant:
        return subdominantColor;
      case HarmonicCategory.dominant:
        return dominantColor;
      case HarmonicCategory.secondaryDominant:
        return secondaryDomColor;
      case HarmonicCategory.diminishedPassing:
        return diminishedPassingColor;
      case HarmonicCategory.borrowed:
        return borrowedColor;
      case HarmonicCategory.chromaticMediant:
        return chromaticColor;
    }
  }

  static ThemeData get themeData {
    const ColorScheme scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: tonicColor,
      onPrimary: Color(0xFF0E1416),
      secondary: rootNoteHighlight,
      onSecondary: Color(0xFF16120B),
      tertiary: borrowedColor,
      surface: cardSurface,
      onSurface: textPrimary,
      error: dominantColor,
      onError: Color(0xFF190B0B),
      outline: borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgPrimary,
      canvasColor: bgWorkspace,
      cardColor: cardSurface,
      dividerColor: borderSubtle,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 13,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 11.5,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderSubtle),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 11),
      ),
    );
  }
}
