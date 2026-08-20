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
  static const EdgeInsets scrollBottomGutter = EdgeInsets.only(
    bottom: AppSpacing.lg,
  );

  /// Horizontal gutter for centred banners (e.g. featured-site card).
  static const EdgeInsets bannerHorizontal = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
  );

  /// Padding for a list-row body (mirrors [tile] but standalone).
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.xs,
  );

  /// Padding inside a tall chip or trial badge body.
  static const EdgeInsets chipTall = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  /// Padding inside a small inline tag.
  static const EdgeInsets tag = EdgeInsets.symmetric(
    horizontal: AppSpacing.xs,
    vertical: AppSpacing.xxs,
  );

  /// Padding inside a small pill or language chip.
  static const EdgeInsets pillSm = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical:
        AppSpacing.xs - 2, // 6 — borderline; intentionally separate from xs(8).
  );

  /// Padding inside a tiny pill badge.
  static const EdgeInsets pillTiny = EdgeInsets.symmetric(
    horizontal: AppSpacing.xs,
    vertical: AppSpacing.xxs / 2, // 2 — preview / superscript-style badge.
  );

  /// Padding inside a language / status chip (h: 10).
  static const EdgeInsets pillTight = EdgeInsets.symmetric(
    horizontal: 10.0,
    vertical: AppSpacing.xxs,
  );

  /// Padding inside a status-chip row (e.g. route progress banner).
  static const EdgeInsets pillRow = EdgeInsets.symmetric(
    horizontal: 10.0,
    vertical: 6.0,
  );

  /// Padding inside a banner with 14/10 cadence.
  static const EdgeInsets bannerInner = EdgeInsets.symmetric(
    horizontal: 14.0,
    vertical: 10.0,
  );

  /// Padding for tall elevated/outlined buttons (button vertical = 14).
  static const EdgeInsets buttonTall = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: 14.0,
  );

  /// Padding for a compact badge / pill (h: 6, v: 2).
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(
    horizontal: 6.0,
    vertical: AppSpacing.xxs / 2,
  );

  /// Padding inside a form-field body (mirrors chipTall).
  static const EdgeInsets formField = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
}
