import 'package:flutter/widgets.dart';

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

/// Semantic padding presets built from [AppSpacing].
///
/// These are the most common padding shapes seen across the app. UI code
/// should reach for these before reaching for `EdgeInsets.all(16)` etc —
/// the migration cleans up the long tail in the spacing PR.
class AppInsets {
  AppInsets._();

  /// Outer page padding for a [Scaffold] body.
  static const EdgeInsets screen = EdgeInsets.all(AppSpacing.md);

  /// Padding inside a card / container that holds grouped content.
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.md);

  /// Padding for a settings tile / list row.
  static const EdgeInsets tile = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.xs,
  );

  /// Padding inside a pill / category chip.
  static const EdgeInsets chip = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.xxs,
  );

  /// Padding inside a primary action button.
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.xs,
  );

  /// Padding reserved at the bottom of a scroll view so the last item
  /// isn't covered by the bottom navigation bar.
  static const EdgeInsets scrollBottomGutter =
      EdgeInsets.only(bottom: AppSpacing.lg);

  /// Horizontal gutter for centred banners (e.g. featured-site card).
  static const EdgeInsets bannerHorizontal =
      EdgeInsets.symmetric(horizontal: AppSpacing.md);
}
