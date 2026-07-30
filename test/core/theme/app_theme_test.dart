// Direct theme tests for the Stone Town Heritage VT-Guide design tokens.
//
// These tests guard the foundation PR — they ensure every theme-dependent
// token (light/dark `ColorScheme`, app semantic roles, helper accessors)
// is wired correctly so that downstream PRs can migrate UI call sites with
// confidence.
//
// The full `AppTheme.lightTheme` / `AppTheme.darkTheme` composition is
// smoke-tested on a real device via `flutter run`; the unit tests here
// focus on the building blocks (`AppSemanticColors`, the `ColorScheme`
// generation, the `AppRadius` constants) that can be exercised without
// triggering a `GoogleFonts` network fetch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stone_town_heritage_vt_guide/core/theme/app_palette.dart';
import 'package:stone_town_heritage_vt_guide/core/theme/app_radius.dart';
import 'package:stone_town_heritage_vt_guide/core/theme/app_semantic_colors.dart';

void main() {
  group('AppPalette', () {
    test('coral anchors around the brand seed', () {
      expect(AppPalette.coral500.toARGB32(), isNot(equals(0)));
      // The rest of the scale should be derived around the same hue.
      expect(AppPalette.coral500.r, greaterThan(AppPalette.coral500.b));
    });

    test('fixed white and black are not theme-bound', () {
      expect(AppPalette.fixedWhite, const Color(0xFFFFFFFF));
      expect(AppPalette.fixedBlack, const Color(0xFF000000));
    });
  });

  group('AppRadius', () {
    test('card / button / chip tokens are non-zero', () {
      expect(AppRadius.card, greaterThan(0));
      expect(AppRadius.button, greaterThan(0));
      expect(AppRadius.full, greaterThan(AppRadius.card));
    });

    test('BorderRadius constants round-trip the underlying radius', () {
      expect(AppRadius.cardBorder.topLeft, Radius.circular(AppRadius.card));
      expect(AppRadius.buttonBorder.topLeft, Radius.circular(AppRadius.button));
    });

    test('fullBorder uses the pill radius', () {
      expect(AppRadius.fullBorder.topLeft, Radius.circular(AppRadius.full));
    });

    test('sheetTopBorder uses the xl radius', () {
      expect(AppRadius.sheetTopBorder.topLeft, Radius.circular(AppRadius.xl));
    });
  });

  group('AppSemanticColors', () {
    test('copyWith preserves untouched fields', () {
      const original = AppSemanticColors(
        success: Color(0xFF111111),
        onSuccess: Color(0xFF222222),
        warning: Color(0xFF333333),
        onWarning: Color(0xFF444444),
        info: Color(0xFF555555),
        onInfo: Color(0xFF666666),
        rating: Color(0xFF777777),
        mapRoute: Color(0xFF888888),
        mapUser: Color(0xFF999999),
        mapMarker: Color(0xFFAAAAAA),
        onImage: Color(0xFFBBBBBB),
        onImageMuted: Color(0xFFCCCCCC),
        imageScrim: Color(0xFFDDDDDD),
        shadow: Color(0xFFEEEEEE),
      );
      final updated = original.copyWith(rating: const Color(0xFFFF0000));
      expect(updated.rating, const Color(0xFFFF0000));
      expect(updated.success, original.success);
      expect(updated.shadow, original.shadow);
    });

    test('lerp interpolates between two palettes', () {
      const a = AppSemanticColors(
        success: Color(0xFF000000),
        onSuccess: Color(0xFF000000),
        warning: Color(0xFF000000),
        onWarning: Color(0xFF000000),
        info: Color(0xFF000000),
        onInfo: Color(0xFF000000),
        rating: Color(0xFF000000),
        mapRoute: Color(0xFF000000),
        mapUser: Color(0xFF000000),
        mapMarker: Color(0xFF000000),
        onImage: Color(0xFF000000),
        onImageMuted: Color(0xFF000000),
        imageScrim: Color(0xFF000000),
        shadow: Color(0xFF000000),
      );
      const b = AppSemanticColors(
        success: Color(0xFFFFFFFF),
        onSuccess: Color(0xFFFFFFFF),
        warning: Color(0xFFFFFFFF),
        onWarning: Color(0xFFFFFFFF),
        info: Color(0xFFFFFFFF),
        onInfo: Color(0xFFFFFFFF),
        rating: Color(0xFFFFFFFF),
        mapRoute: Color(0xFFFFFFFF),
        mapUser: Color(0xFFFFFFFF),
        mapMarker: Color(0xFFFFFFFF),
        onImage: Color(0xFFFFFFFF),
        onImageMuted: Color(0xFFFFFFFF),
        imageScrim: Color(0xFFFFFFFF),
        shadow: Color(0xFFFFFFFF),
      );
      final mid = a.lerp(b, 0.5);
      expect(mid.success.r * 255 ~/ 1, inInclusiveRange(126, 129));
    });

    test('equality is structural', () {
      const a = AppSemanticColors(
        success: Color(0xFF000000),
        onSuccess: Color(0xFF000000),
        warning: Color(0xFF000000),
        onWarning: Color(0xFF000000),
        info: Color(0xFF000000),
        onInfo: Color(0xFF000000),
        rating: Color(0xFF000000),
        mapRoute: Color(0xFF000000),
        mapUser: Color(0xFF000000),
        mapMarker: Color(0xFF000000),
        onImage: Color(0xFF000000),
        onImageMuted: Color(0xFF000000),
        imageScrim: Color(0xFF000000),
        shadow: Color(0xFF000000),
      );
      const b = AppSemanticColors(
        success: Color(0xFF000000),
        onSuccess: Color(0xFF000000),
        warning: Color(0xFF000000),
        onWarning: Color(0xFF000000),
        info: Color(0xFF000000),
        onInfo: Color(0xFF000000),
        rating: Color(0xFF000000),
        mapRoute: Color(0xFF000000),
        mapUser: Color(0xFF000000),
        mapMarker: Color(0xFF000000),
        onImage: Color(0xFF000000),
        onImageMuted: Color(0xFF000000),
        imageScrim: Color(0xFF000000),
        shadow: Color(0xFF000000),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ColorScheme.fromSeed', () {
    test('light scheme derives a primary from the coral seed', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: AppPalette.coral500,
        brightness: Brightness.light,
      );
      expect(scheme.primary.toARGB32(), isNot(equals(0)));
      expect(scheme.brightness, Brightness.light);
    });

    test('dark scheme derives a primary from the coral seed', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: AppPalette.coral500,
        brightness: Brightness.dark,
      );
      expect(scheme.primary.toARGB32(), isNot(equals(0)));
      expect(scheme.brightness, Brightness.dark);
    });

    test('light + dark schemes produce different onSurface values', () {
      final light = ColorScheme.fromSeed(
        seedColor: AppPalette.coral500,
        brightness: Brightness.light,
      );
      final dark = ColorScheme.fromSeed(
        seedColor: AppPalette.coral500,
        brightness: Brightness.dark,
      );
      expect(light.onSurface, isNot(equals(dark.onSurface)));
    });
  });
}
