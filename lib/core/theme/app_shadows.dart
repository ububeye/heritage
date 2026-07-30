import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  // Elevation tokens for Material widgets
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // BoxShadows for custom drawn containers
  static final List<BoxShadow> low = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4.0,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8.0,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> high = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 16.0,
      offset: const Offset(0, 8),
    ),
  ];

  /// Brightness-aware low shadow. The default [low] is `Colors.black @ 5%`,
  /// which is invisible on a dark surface (and looks like a smudge against
  /// `darkScaffold`). For card-like containers that sit on `surface` in
  /// light mode and `surfaceDark` in dark mode, return a faint white halo
  /// in dark mode and the original black shadow in light mode.
  static List<BoxShadow> lowFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x14FFFFFF), // white @ ~8%
          blurRadius: 6.0,
          offset: Offset(0, 2),
        ),
      ];
    }
    return low;
  }

  /// Brightness-aware medium shadow. Mirrors [lowFor]'s white-halo behaviour
  /// so cards on dark surfaces still read as elevated.
  static List<BoxShadow> mediumFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x18FFFFFF), // white @ ~9.5%
          blurRadius: 10.0,
          offset: Offset(0, 4),
        ),
      ];
    }
    return medium;
  }

  /// Brightness-aware high shadow.
  static List<BoxShadow> highFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x1FFFFFFF), // white @ ~12.5%
          blurRadius: 18.0,
          offset: Offset(0, 8),
        ),
      ];
    }
    return high;
  }

  // ─── Named semantic tokens ───────────────────────────────────────────────

  /// Brand-tinted halo for elevated CTAs, featured cards, and premium banners.
  ///
  /// Light mode: primary colour @ 30% alpha, blurRadius 15, offset (0, 6).
  /// Dark mode: primary colour @ 20% alpha with slightly tighter blur so
  /// the tint reads as a glow rather than a muddy smear on dark surfaces.
  ///
  /// [primaryColor] is typically `Theme.of(context).colorScheme.primary`.
  static List<BoxShadow> brandHaloFor(
    Brightness brightness, {
    required Color primaryColor,
  }) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.20),
          blurRadius: 12.0,
          offset: const Offset(0, 5),
        ),
      ];
    }
    return [
      BoxShadow(
        color: primaryColor.withValues(alpha: 0.30),
        blurRadius: 15.0,
        offset: const Offset(0, 6),
      ),
    ];
  }

  /// Upward-casting shadow for floating bottom bars (navigation sheet,
  /// audio player). Identical shape to the exempt `audio_player_bar` token —
  /// uses the theme-aware semantic shadow colour passed in as [shadowColor].
  ///
  /// [shadowColor] is typically `context.semanticColors.shadow`.
  static List<BoxShadow> bottomBarFor(Color shadowColor) => [
    BoxShadow(
      color: shadowColor,
      blurRadius: 10.0,
      offset: const Offset(0, -2),
    ),
  ];

  /// Large diffuse shadow for hero logo containers (splash, login, register,
  /// welcome screens). Brightness-aware: drops opacity in dark mode so the
  /// glow doesn't overwhelm a dark scaffold.
  ///
  /// [shadowColor] is typically `context.semanticColors.shadow`.
  static List<BoxShadow> heroLogoFor(
    Brightness brightness, {
    required Color shadowColor,
  }) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: shadowColor,
          blurRadius: 20.0,
          offset: const Offset(0, 10),
        ),
      ];
    }
    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: 30.0,
        offset: const Offset(0, 15),
      ),
    ];
  }

  /// Compact drop-shadow for map-marker label chips. Kept minimal so it
  /// doesn't compete with the map tile content beneath.
  ///
  /// [shadowColor] is typically `context.semanticColors.shadow`.
  static List<BoxShadow> mapPinFor(Color shadowColor) => [
    BoxShadow(color: shadowColor, blurRadius: 2.0),
  ];
}
