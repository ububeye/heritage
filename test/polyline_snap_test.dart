// Unit tests for the polyline snapping helper.
//
// The helper is pure Dart with no I/O — every test runs in milliseconds
// and is safe in CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/polyline_snap.dart';

void main() {
  group('PolylineSnap.snapToPolyline', () {
    test('returns the input point unchanged on empty polyline', () {
      const point = LatLng(-6.1620, 39.1936);
      expect(PolylineSnap.snapToPolyline(point, const []), point);
    });

    test('returns the only vertex when polyline has one point', () {
      const point = LatLng(-6.1620, 39.1936);
      const vertex = LatLng(-6.1619, 39.1935);
      expect(PolylineSnap.snapToPolyline(point, [vertex]), vertex);
    });

    test('returns the nearest vertex of a multi-vertex polyline', () {
      const target = LatLng(-6.1620, 39.1936);
      const polyline = [
        LatLng(-6.1630, 39.1940), // far
        LatLng(-6.1621, 39.1937), // very close (≈15 m away)
        LatLng(-6.1615, 39.1930), // far
      ];
      final snapped = PolylineSnap.snapToPolyline(target, polyline);
      expect(snapped, const LatLng(-6.1621, 39.1937));
    });

    test('returns the first vertex when it is the closest', () {
      const target = LatLng(-6.1630, 39.1940);
      const polyline = [
        LatLng(-6.1630, 39.1940), // exact match
        LatLng(-6.1619, 39.1936), // far
      ];
      expect(PolylineSnap.snapToPolyline(target, polyline), target);
    });

    test('snaps to a polyline vertex matching the door\'s longitude', () {
      // Roughly a north-south drag through the heritage peninsula.
      const polyline = [
        LatLng(-6.1575, 39.1936),
        LatLng(-6.1600, 39.1936),
        LatLng(-6.1625, 39.1936),
        LatLng(-6.1650, 39.1936),
      ];
      // A doorway offset 50 m east of the road. The snap should move
      // the longitude onto the polyline (39.1936), not the doorway's
      // longitude (39.1944). Exact latitude selection depends on the
      // tie-breaker — we just need *a* vertex on this polyline.
      const doorway = LatLng(-6.1612, 39.1944);
      final snapped = PolylineSnap.snapToPolyline(doorway, polyline);
      // Longitude snaps to the road.
      expect(snapped.longitude, 39.1936);
      // Latitude is one of the polyline vertices (not the doorway).
      final lats = polyline.map((p) => p.latitude).toSet();
      expect(
        lats.contains(snapped.latitude),
        isTrue,
        reason:
            'snapped latitude ${snapped.latitude} must be a polyline vertex',
      );
      expect(snapped.latitude, isNot(equals(doorway.latitude)));
    });
  });
}
