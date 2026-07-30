// ignore_for_file: deprecated_member_use_from_same_package
//
// This file is intentionally split into two parts:
//
//  1. `AppPalette` (in app_palette.dart) — raw primitives. The only place
//     these literal swatches live. UI code must not import that file
//     directly.
//
//  2. `AppColors` (below) — a deprecated compatibility bridge. The values
//     forward to `AppPalette` so existing UI code keeps compiling while a
//     separate PR migrates each call site to `ColorScheme` or
//     `AppSemanticColors`. The bridge is removed at the end of the
//     migration track.

import 'package:flutter/material.dart';

import 'app_palette.dart';

export 'app_palette.dart';

/// Deprecated token-level colour shortcuts.
///
/// Each field forwards to the equivalent value in [AppPalette]. New code
/// should consume `Theme.of(context).colorScheme` (Material roles) or
/// `context.semanticColors` (app-specific roles) instead. The `AppColors`
/// class is scheduled for removal once every UI consumer has migrated.
@Deprecated('Use Theme.of(context).colorScheme or AppSemanticColors.')
class AppColors {
  AppColors._();

  // Primary
  @Deprecated('Use Theme.of(context).colorScheme.primary.')
  static const Color primary = AppPalette.coral500;
  @Deprecated('Use Theme.of(context).colorScheme.primary.')
  static const Color primaryDark = AppPalette.coral600;
  @Deprecated('Use Theme.of(context).colorScheme.primary.')
  static const Color primaryLight = AppPalette.coral300;

  // Accent / secondary
  @Deprecated('Use Theme.of(context).colorScheme.secondary.')
  static const Color accent = AppPalette.navy500;
  @Deprecated('Use Theme.of(context).colorScheme.secondary.')
  static const Color accentLight = AppPalette.sky300;
  @Deprecated('Use context.semanticColors.info or getColorScheme.secondary.')
  static const Color secondary = AppPalette.sky500;

  // Surface
  @Deprecated('Use Theme.of(context).colorScheme.surface.')
  static const Color surface = AppPalette.warmSurface;
  @Deprecated('Use Theme.of(context).colorScheme.surfaceContainer.')
  static const Color surfaceDark = AppPalette.charcoal900;
  @Deprecated('Use Theme.of(context).colorScheme.surface.')
  static const Color background = AppPalette.warmSurface;

  // Semantic
  @Deprecated('Use Theme.of(context).colorScheme.error.')
  static const Color error = AppPalette.red600;
  @Deprecated('Use context.semanticColors.success.')
  static const Color success = AppPalette.green700;
  @Deprecated('Use context.semanticColors.warning.')
  static const Color warning = AppPalette.orange700;
  @Deprecated('Use context.semanticColors.info.')
  static const Color info = AppPalette.sky700;

  // Text
  @Deprecated('Use Theme.of(context).colorScheme.onSurface.')
  static const Color textPrimary = Color(0xFF2C3E50);
  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant.')
  static const Color textSecondary = AppPalette.charcoal500;
  @Deprecated('Use Theme.of(context).colorScheme.outline.')
  static const Color textHint = AppPalette.charcoal100;
  @Deprecated('Use Theme.of(context).colorScheme.onPrimary.')
  static const Color textOnPrimary = AppPalette.fixedWhite;
  @Deprecated('Use Theme.of(context).colorScheme.onSecondary.')
  static const Color textOnAccent = AppPalette.fixedWhite;

  // Rating
  @Deprecated('Use context.semanticColors.rating.')
  static const Color rating = AppPalette.amber500;

  // Map
  @Deprecated('Use context.semanticColors.mapRoute.')
  static const Color mapRoute = AppPalette.navy500;
  @Deprecated('Use context.semanticColors.mapUser.')
  static const Color mapUser = AppPalette.sky700;
  @Deprecated('Use context.semanticColors.mapMarker.')
  static const Color mapMarker = AppPalette.coral500;

  // Overlays
  @Deprecated('Use context.semanticColors.imageScrim.')
  static const Color overlayDark = Color(0x99000000);
  @Deprecated('Use context.semanticColors.onImageMuted.')
  static const Color overlayLight = Color(0x33FFFFFF);

  // Borders / dividers
  @Deprecated('Use Theme.of(context).colorScheme.outline.')
  static const Color border = AppPalette.charcoal200;
  @Deprecated('Use Theme.of(context).colorScheme.outlineVariant.')
  static const Color divider = AppPalette.charcoal100;

  // Dark tokens
  @Deprecated('Use Theme.of(context).colorScheme.onPrimary.')
  static const Color darkOnPrimary = AppPalette.fixedWhite;
  @Deprecated('Use Theme.of(context).colorScheme.onSecondary.')
  static const Color darkOnAccent = AppPalette.fixedWhite;
  @Deprecated('Use Theme.of(context).colorScheme.error.')
  static const Color darkError = AppPalette.red400;
  @Deprecated('Use Theme.of(context).colorScheme.onSurface.')
  static const Color darkBody = AppPalette.charcoal200;
  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant.')
  static const Color darkMuted = AppPalette.charcoal400;
  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant.')
  static const Color darkHint = AppPalette.charcoal500;
  @Deprecated('Use Theme.of(context).colorScheme.outline.')
  static const Color darkBorder = AppPalette.charcoal600;
  @Deprecated('Use Theme.of(context).colorScheme.surface.')
  static const Color darkScaffold = AppPalette.charcoal950;
  @Deprecated('Use Theme.of(context).colorScheme.surfaceContainer.')
  static const Color darkSurfaceContainer = AppPalette.charcoal850;
  @Deprecated('Use Theme.of(context).colorScheme.surfaceContainerHigh.')
  static const Color darkSurfaceContainerHigh = AppPalette.charcoal800;
  @Deprecated('Use Theme.of(context).colorScheme.surfaceTint.')
  static const Color darkSurfaceTint = AppPalette.coral500;

  // Gradients
  @Deprecated('Use Theme.of(context) gradients derived from colorScheme.')
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppPalette.coral500, AppPalette.coral600],
  );

  @Deprecated('Use Theme.of(context) gradients derived from colorScheme.')
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppPalette.navy500, AppPalette.sky300],
  );

  @Deprecated('Use context.semanticColors.imageScrim for the overlay.')
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x00000000), Color(0xCC2C3E50)],
  );
}
