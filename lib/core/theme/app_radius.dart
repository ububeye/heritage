import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Specific usages to map old app_constants
  static const double button = sm;
  static const double card = md;

  // Pill / capsule controls. A value this large renders as a perfect
  // stadium shape on any height up to its full diameter.
  static const double full = 999.0;

  // ── Pre-built BorderRadius constants ───────────────────────────────
  // Prefer these over `BorderRadius.circular()` so the radius token stays
  // the single source of truth.
  static const BorderRadius noneBorder = BorderRadius.zero;
  static const BorderRadius xsBorder = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smBorder = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlBorder = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius buttonBorder =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius cardBorder =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius fullBorder = BorderRadius.all(Radius.circular(full));

  // Top-only sheet radius — used by `showModalBottomSheet` containers.
  static const BorderRadius sheetTopBorder = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
