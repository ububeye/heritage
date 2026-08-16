// Unit tests for the bounds-selection policy on HeritageMap.
//
// HeritageMap has three variants (browse, picker, singleSite). The
// picker variant — used by the admin add/edit screens — must be hard-
// locked to the Stone Town UNESCO heritage peninsula; the browse /
// single-site variants must span all of Unguja so a tourist can pan
// across the whole island. These tests pin that policy: regression
// here means an admin could drop a pin in the harbour or a tourist
// could be confined to Stone Town even when they're in Nungwi.
//
// We exercise the static helpers rather than the widget itself —
// flutter_map requires a running MapController and tile provider
// which isn't worth spinning up for a pure-bounds test.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/stone_town_bounds.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/unguja_bounds.dart';
import 'package:stone_town_heritage_vt_guide/ui/widgets/heritage_map.dart';

void main() {
  group('HeritageMap.boundsFor', () {
    test('picker variant returns the Stone Town box', () {
      final bounds = HeritageMap.boundsFor(isPicker: true);
      // HeritageMap.picker → Stone Town. The exact numeric corner
      // doesn't matter for the policy — assert it matches the same
      // corners the StoneTownBounds utility exposes.
      final stoneTown = StoneTownBounds.pickerCameraBounds;
      expect(bounds.north, stoneTown.north);
      expect(bounds.south, stoneTown.south);
      expect(bounds.east, stoneTown.east);
      expect(bounds.west, stoneTown.west);
      // And it must NOT be the Unguja box.
      expect(bounds.north, isNot(UngujaBounds.cameraBounds.north));
    });

    test('browse / single-site variant returns the Unguja box', () {
      final bounds = HeritageMap.boundsFor(isPicker: false);
      final unguja = UngujaBounds.cameraBounds;
      expect(bounds.north, unguja.north);
      expect(bounds.south, unguja.south);
      expect(bounds.east, unguja.east);
      expect(bounds.west, unguja.west);
      expect(bounds.north, isNot(StoneTownBounds.cameraBounds.north));
    });
  });

  group('HeritageMap.constraintFor', () {
    test(
      'picker variant uses containCenter — never returns null on zoom-out',
      () {
        // containCenter constrains the camera *centre* to the box but
        // allows the viewport to spill past the edges when zoomed out.
        // This is critical because `CameraConstraint.contain` returns
        // `null` when the viewport can't fit inside the bounds, which
        // trips the `'MapCamera is no longer within the cameraConstraint'`
        // assertion on the next rebuild and shows the user the red
        // "Access blocked" overlay.
        final constraint = HeritageMap.constraintFor(isPicker: true);
        // The constraint classes themselves are private to flutter_map,
        // so we compare runtimeType strings instead.
        expect(constraint.runtimeType.toString(), contains('ContainCameraCenter'));
      },
    );

    test(
      'browse / single-site variant uses contain — tight viewport fit',
      () {
        final constraint = HeritageMap.constraintFor(isPicker: false);
        expect(constraint.runtimeType.toString(), contains('ContainCamera'));
        expect(
          constraint.runtimeType.toString(),
          isNot(contains('ContainCameraCenter')),
        );
      },
    );
  });

  group('HeritageMap.clampForPicker', () {
    test('picker variant clamps to Stone Town (not Unguja)', () {
      // Forodhani is inside Stone Town — should pass through.
      const forodhani = LatLng(-6.1619, 39.1936);
      expect(
        HeritageMap.clampForPicker(forodhani, isPicker: true),
        forodhani,
      );

      // A point outside Stone Town but inside Unguja (e.g. the airport)
      // should snap to the Stone Town edge — NOT pass through.
      const airport = LatLng(-6.2220, 39.2220);
      final clamped = HeritageMap.clampForPicker(airport, isPicker: true);
      expect(StoneTownBounds.contains(clamped), isTrue);
      // And the un-clamped point was definitely outside the Stone
      // Town box — confirms the clamp did real work.
      expect(StoneTownBounds.contains(airport), isFalse);
    });

    test('browse / single-site variant clamps to Unguja', () {
      // Paje — south-east coast, inside Unguja but outside Stone Town.
      const paje = LatLng(-6.2667, 39.4167);
      expect(
        HeritageMap.clampForPicker(paje, isPicker: false),
        paje,
      );

      // A point outside Unguja (Dar es Salaam) should snap to the
      // island edge.
      const dar = LatLng(-6.7924, 39.2083);
      final clamped = HeritageMap.clampForPicker(dar, isPicker: false);
      expect(UngujaBounds.contains(clamped), isTrue);
      expect(UngujaBounds.contains(dar), isFalse);
    });
  });

  group('Admin picker policy — pins cannot leave Stone Town', () {
    // This is the regression test for the recent PR that widened the
    // picker to Unguja. The fix swaps `UngujaBounds.clampPoint` for
    // `StoneTownBounds.clampPoint` on the picker path; this group
    // pins that the picker policy now resolves through the Stone
    // Town box.

    test('a coordinate inside Stone Town passes through the picker', () {
      const forodhani = LatLng(-6.1619, 39.1936);
      final bounds = HeritageMap.boundsFor(isPicker: true);
      expect(bounds.contains(forodhani), isTrue);
    });

    test('a coordinate inside Unguja but outside Stone Town is REJECTED by picker bounds', () {
      const airport = LatLng(-6.2220, 39.2220);
      final bounds = HeritageMap.boundsFor(isPicker: true);
      expect(bounds.contains(airport), isFalse);
    });

    test('the browse variant still accepts airport coords', () {
      const airport = LatLng(-6.2220, 39.2220);
      final bounds = HeritageMap.boundsFor(isPicker: false);
      expect(bounds.contains(airport), isTrue);
    });
  });
}