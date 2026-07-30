import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  // Elevaton tokens for Material widgets
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
}
