import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF8B5E3C);
  static const Color primaryDark = Color(0xFF6B3F27);
  static const Color primaryLight = Color(0xFFAB7B5C);

  // Accent Colors
  static const Color accent = Color(0xFFD4A574);
  static const Color accentLight = Color(0xFFE8C9A0);

  // Surface Colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color background = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color error = Color(0xFFC0392B);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  // Text Colors
  static const Color textPrimary = Color(0xFF3E2723);
  static const Color textSecondary = Color(0xFF8D6E63);
  static const Color textHint = Color(0xFFBCAAA4);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF3E2723); // Changed from white to dark brown for contrast

  // Rating Colors
  static const Color rating = Color(0xFFFFB800);

  // Map Colors
  static const Color mapRoute = Color(0xFFD4A574);
  static const Color mapUser = Color(0xFF3498DB);
  static const Color mapMarker = Color(0xFFE74C3C);

  // Overlay Colors
  static const Color overlayDark = Color(0x99000000);
  static const Color overlayLight = Color(0x33FFFFFF);

  // Border Colors
  static const Color border = Color(0xFFE0D6C8);
  static const Color divider = Color(0xFFD7CCC8);

  // Dark Theme Tokens — used only by AppTheme.darkTheme for accessible
  // foreground/background pairings on the warm brown surfaces used in dark mode.
  static const Color darkOnPrimary = Color(0xFF1B1208); // dark text on light brown primary button
  static const Color darkOnAccent = Color(0xFF1B1208); // dark text on tan accent button
  static const Color darkError = Color(0xFFCF6679); // Material dark-mode error red
  // Body text lifted from #E8E1D6 → #F0EAE0: AAA contrast on #1E1E1E (≈13:1),
  // warmer than pure white, avoids OLED halation. Used for body / label.
  static const Color darkBody = Color(0xFFF0EAE0);
  // Secondary text — bright enough to read clearly on #1E1E1E cards (≈9.5:1).
  // The previous #B8A89A only hit 6.3:1, which fails WCAG AA for small text.
  static const Color darkMuted = Color(0xFFD7C7B6);
  static const Color darkHint = Color(0xFFB8A89A); // placeholder/hint text only
  static const Color darkBorder = Color(0xFF3A312A); // visible-but-quiet warm border
  // Tonal-elevation tokens — cards lift off the scaffold via these rather
  // than via shadow, which is invisible on a warm dark surface.
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkSurfaceContainer = Color(0xFF262220);
  static const Color darkSurfaceContainerHigh = Color(0xFF2E2924);
  static const Color darkSurfaceTint = Color(0xFF6B3F27); // primaryDark — drives the lift

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFB8956A)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC3E2723)],
  );
}
