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

  // Specific semantic radii used by off-scale call sites (preserves pixels).
  static const double grabHandle = 2.0; // Modal sheet grab-handle width/2.
  static const double banner = 10.0; // Featured-card / preview-badge border.
  static const double badge = 14.0; // Trial-badge / FAQ chip.
  static const double sheetBorderSm =
      20.0; // Smaller modal-sheet top radius (vs xl).
  static const double avatar = 28.0; // Circular avatar / play-pause disc.
  static const double ctaButton = 30.0; // CTA pill on welcome / onboarding.
  static const double heroImage = 35.0; // Login / register hero avatar.
  static const double heroGreeting = 40.0; // Welcome-screen greeting avatar.

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
  static const BorderRadius buttonBorder = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius fullBorder = BorderRadius.all(
    Radius.circular(full),
  );

  static const BorderRadius grabHandleBorder = BorderRadius.all(
    Radius.circular(grabHandle),
  );
  static const BorderRadius bannerBorder = BorderRadius.all(
    Radius.circular(banner),
  );
  static const BorderRadius badgeBorder = BorderRadius.all(
    Radius.circular(badge),
  );
  static const BorderRadius sheetBorderSmBorder = BorderRadius.all(
    Radius.circular(sheetBorderSm),
  );
  static const BorderRadius avatarBorder = BorderRadius.all(
    Radius.circular(avatar),
  );
  static const BorderRadius ctaButtonBorder = BorderRadius.all(
    Radius.circular(ctaButton),
  );
  static const BorderRadius heroImageBorder = BorderRadius.all(
    Radius.circular(heroImage),
  );
  static const BorderRadius heroGreetingBorder = BorderRadius.all(
    Radius.circular(heroGreeting),
  );

  // Top-only sheet radius — used by `showModalBottomSheet` containers.
  static const BorderRadius sheetTopBorder = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  // Parallel sheet-top variant for the smaller-radius sheets.
  static const BorderRadius sheetTopSmBorder = BorderRadius.vertical(
    top: Radius.circular(sheetBorderSm),
  );
}
