import 'package:flutter/material.dart';

/// Raw primitive palette — context-independent swatches only.
///
/// UI code must never import this file directly. The colour scheme and the
/// [AppSemanticColors] theme extension are the only sanctioned access points
/// for colours at the call-site layer; this class is the single source of
/// truth that those semantic tokens reference.
///
/// Naming is value-based (not role-based) so that rebranding a tone does not
/// require auditing every call site — only the role-mapping in
/// `app_theme.dart` needs to change.
abstract final class AppPalette {
  // ── Coral brand scale ───────────────────────────────────────────────
  // Anchor of the brand. Warm terracotta. Used as the seed for the M3
  // tonal palette in light + dark themes.
  static const Color coral50 = Color(0xFFFCEEE8);
  static const Color coral100 = Color(0xFFF7D6C9);
  static const Color coral200 = Color(0xFFF0B9A4);
  static const Color coral300 = Color(0xFFE89478);
  static const Color coral400 = Color(0xFFE48263);
  static const Color coral500 = Color(0xFFE07A5F);
  static const Color coral600 = Color(0xFFC85A41);
  static const Color coral700 = Color(0xFFA8472F);
  static const Color coral800 = Color(0xFF7C3322);
  static const Color coral900 = Color(0xFF4E1F15);

  // ── Navy / teal accent scale ────────────────────────────────────────
  // Cool counterpoint to the coral — used for the secondary role and the
  // "ocean" navigation accents.
  static const Color navy50 = Color(0xFFE9EEF4);
  static const Color navy100 = Color(0xFFC9D4E2);
  static const Color navy300 = Color(0xFF7E96B5);
  static const Color navy500 = Color(0xFF3D5A80);
  static const Color navy700 = Color(0xFF2A4060);
  static const Color sky300 = Color(0xFF7FBFE0);
  static const Color sky500 = Color(0xFF29B6F6);
  static const Color sky700 = Color(0xFF0288D1);

  // ── Warm surface scale ──────────────────────────────────────────────
  // Off-white surfaces in light mode — reads as warm heritage paper.
  static const Color warmSurface = Color(0xFFFAF9F6);
  static const Color warmSurfaceContainer = Color(0xFFF1EEE8);
  static const Color warmSurfaceContainerHigh = Color(0xFFE8E3D9);

  // ── Charcoal / dark scale ───────────────────────────────────────────
  static const Color charcoal950 = Color(0xFF121212);
  static const Color charcoal900 = Color(0xFF1E2124);
  static const Color charcoal850 = Color(0xFF24272A);
  static const Color charcoal800 = Color(0xFF2D3034);
  static const Color charcoal700 = Color(0xFF36393C);
  static const Color charcoal600 = Color(0xFF424242);
  static const Color charcoal500 = Color(0xFF757575);
  static const Color charcoal400 = Color(0xFF9E9E9E);
  static const Color charcoal300 = Color(0xFFB0B0B0);
  static const Color charcoal200 = Color(0xFFE0E0E0);
  static const Color charcoal100 = Color(0xFFEEEEEE);
  static const Color charcoal50 = Color(0xFFF5F5F5);

  // ── Semantic base swatches ──────────────────────────────────────────
  // Used to build error / success / warning / info roles. Not directly
  // consumed by UI code.
  static const Color red600 = Color(0xFFD32F2F);
  static const Color red400 = Color(0xFFEF5350);
  static const Color green700 = Color(0xFF2E7D32);
  static const Color orange700 = Color(0xFFF57C00);
  static const Color amber500 = Color(0xFFFFC107);

  // ── Fixed neutrals ─────────────────────────────────────────────────
  // Reserved for content rendered directly on top of photographs or map
  // imagery — must remain colour-stable across light and dark theme.
  static const Color fixedWhite = Color(0xFFFFFFFF);
  static const Color fixedBlack = Color(0xFF000000);

  // ── Legacy gradients ────────────────────────────────────────────────
  // The hero-card gradient overlay rendered over a featured-site image.
  // Kept here so the role-mapping can swap it without losing the value.
  static const Color heroOverlay = Color(0xCC2C3E50);
}
