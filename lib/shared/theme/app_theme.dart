import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Design tokens for the premium dark fintech interface.
abstract final class AppTheme {
  /// Deep graphite page background.
  static const background = Color(0xFF040607);

  /// Default card surface.
  static const surface = Color(0xFF11161C);

  /// Elevated surface tint.
  static const surfaceRaised = Color(0xFF171D24);

  /// Muted inset surface.
  static const surfaceMuted = Color(0xFF0B1015);

  /// Primary monochrome accent.
  static const accent = Color(0xFFFFFFFF);

  /// Soft light grey highlight.
  static const accentSoft = Color(0xFFE2E8F0);

  /// Cool secondary accent.
  static const blue = Color(0xFF8FB5FF);

  /// Premium turquoise accent for inflows.
  static const turquoise = Color(0xFF2DD4BF);

  /// Positive accent for inflows.
  static const sky = Color(0xFF7DD3FC);

  /// Warning accent for money lent out.
  static const amber = Color(0xFFF3B46B);

  /// Warm danger accent.
  static const coral = Color(0xFFF57B6C);

  /// Primary text (neutral slate white).
  static const textPrimary = Color(0xFFF8FAFC);

  /// Secondary text (neutral slate grey).
  static const textMuted = Color(0xFF94A3B8);

  /// Shadcn dark theme with custom liquid-fintech tokens.
  static ShadThemeData get dark {
    return ShadThemeData(
      brightness: Brightness.dark,
      radius: const BorderRadius.all(Radius.circular(24)),
      colorScheme: const ShadSlateColorScheme.dark(
        background: background,
        foreground: textPrimary,
        card: surface,
        cardForeground: textPrimary,
        primary: accent,
        primaryForeground: background,
        secondary: surfaceRaised,
        secondaryForeground: accentSoft,
        muted: surfaceMuted,
        mutedForeground: textMuted,
        border: Color(0xFF26303B),
        input: Color(0xFF121920),
        ring: accent,
      ),
      textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.interTight),
    );
  }
}
