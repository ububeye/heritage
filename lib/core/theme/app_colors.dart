import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors (Coral/Terracotta)
  static const Color primary = Color(0xFFE07A5F);
  static const Color primaryDark = Color(0xFFC85A41);
  static const Color primaryLight = Color(0xFFF2A48C);

  // Accent Colors (Teal/Turquoise)
  static const Color accent = Color(0xFF3D5A80);
  static const Color accentLight = Color(0xFF98C1D9);
  
  // Alternative accent (oceanic)
  static const Color secondary = Color(0xFF29B6F6);

  // Surface Colors
  static const Color surface = Color(0xFFFAF9F6); // Warm off-white
  static const Color surfaceDark = Color(0xFF1E2124); // Deep charcoal
  static const Color background = Color(0xFFFAF9F6);

  // Semantic Colors
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF0288D1);

  // Text Colors
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textHint = Color(0xFFBDC3C7);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Rating Colors
  static const Color rating = Color(0xFFFFC107);

  // Map Colors
  static const Color mapRoute = Color(0xFF3D5A80);
  static const Color mapUser = Color(0xFF0288D1);
  static const Color mapMarker = Color(0xFFE07A5F);

  // Overlay Colors
  static const Color overlayDark = Color(0x99000000);
  static const Color overlayLight = Color(0x33FFFFFF);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Dark Theme Tokens
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkOnAccent = Color(0xFFFFFFFF);
  static const Color darkError = Color(0xFFEF5350);
  
  static const Color darkBody = Color(0xFFE0E0E0);
  static const Color darkMuted = Color(0xFF9E9E9E);
  static const Color darkHint = Color(0xFF757575);
  static const Color darkBorder = Color(0xFF424242);
  
  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkSurfaceContainer = Color(0xFF24272A);
  static const Color darkSurfaceContainerHigh = Color(0xFF2D3034);
  static const Color darkSurfaceTint = Color(0xFFE07A5F);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC2C3E50)],
  );
}
