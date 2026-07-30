import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised typography ramp for the Stone Town Heritage VT-Guide.
///
/// Families:
///   • [displayFontFamily] — Fraunces, a variable serif by Undercase Type.
///     Used for the editorial hero voice on welcome, onboarding, and
///     large marketing surfaces.
///   • [bodyFontFamily] — Inter. Body, titles, controls, labels, app bars,
///     inputs, badges. The dominant voice.
///
/// All role mapping is documented in [buildTextTheme]. UI code consumes
/// the resulting `Theme.of(context).textTheme` directly; raw `GoogleFonts.*`
/// calls outside this file are not allowed.
class AppTextStyles {
  AppTextStyles._();

  /// Variable serif used for display + headline roles.
  static final String displayFontFamily =
      GoogleFonts.fraunces().fontFamily ?? 'Fraunces';

  /// Geometric sans used for body, titles, labels, controls.
  static final String bodyFontFamily =
      GoogleFonts.inter().fontFamily ?? 'Inter';

  // ── Role mapping ────────────────────────────────────────────────────
  // | Use case                       | Material role     |
  // | ------------------------------ | ----------------- |
  // | Welcome hero, splash           | displayLarge      |
  // | Onboarding page title          | displayMedium     |
  // | Large screen heading           | headlineLarge     |
  // | Section heading                | titleLarge        |
  // | Card / sheet title             | titleMedium       |
  // | Body copy                      | bodyLarge/Medium  |
  // | Supporting copy                | bodySmall         |
  // | Buttons, chips                 | labelLarge        |
  // | Tiny badges, captions          | labelSmall        |
  static TextTheme buildTextTheme(
    TextTheme base,
    Color primaryColor,
    Color secondaryColor, {
    Color? headlineColor,
  }) {
    final hColor = headlineColor ?? primaryColor;
    return base.copyWith(
      // ── Display — Fraunces, editorial hero ─────────────────────────
      displayLarge: GoogleFonts.fraunces(
        textStyle: base.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: hColor,
        ),
      ),
      displayMedium: GoogleFonts.fraunces(
        textStyle: base.displayMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: hColor,
        ),
      ),
      displaySmall: GoogleFonts.fraunces(
        textStyle: base.displaySmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: hColor,
        ),
      ),
      // ── Headline — Fraunces, large screen headings ─────────────────
      headlineLarge: GoogleFonts.fraunces(
        textStyle: base.headlineLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: hColor,
        ),
      ),
      // ── Headline Medium/Small — Inter, section headings ────────────
      headlineMedium: GoogleFonts.inter(
        textStyle: base.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: hColor,
        ),
      ),
      headlineSmall: GoogleFonts.inter(
        textStyle: base.headlineSmall?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: hColor,
        ),
      ),
      // ── Title — Inter, card / sheet titles ─────────────────────────
      titleLarge: GoogleFonts.inter(
        textStyle: base.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      titleMedium: GoogleFonts.inter(
        textStyle: base.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      titleSmall: GoogleFonts.inter(
        textStyle: base.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      // ── Body — Inter ───────────────────────────────────────────────
      bodyLarge: GoogleFonts.inter(
        textStyle: base.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: primaryColor,
        ),
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: base.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: primaryColor,
        ),
      ),
      bodySmall: GoogleFonts.inter(
        textStyle: base.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: secondaryColor,
        ),
      ),
      // ── Label — Inter, buttons / chips / captions ──────────────────
      labelLarge: GoogleFonts.inter(
        textStyle: base.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
      labelMedium: GoogleFonts.inter(
        textStyle: base.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: secondaryColor,
        ),
      ),
      labelSmall: GoogleFonts.inter(
        textStyle: base.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: secondaryColor,
        ),
      ),
    );
  }
}
