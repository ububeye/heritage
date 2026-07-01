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
