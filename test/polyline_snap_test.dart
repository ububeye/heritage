// Unit tests for the polyline snapping and projection helper.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/polyline_snap.dart';

void main() {
  group('PolylineSnap.snapToPolyline & projectPoint', () {
    test('returns the input point unchanged on empty polyline', () {
      const point = LatLng(-6.1620, 39.1936);
      expect(PolylineSnap.snapToPolyline(point, const []), point);
    });

    test('returns the only vertex when polyline has one point', () {
      const point = LatLng(-6.1620, 39.1936);
      const vertex = LatLng(-6.1619, 39.1935);
      expect(PolylineSnap.snapToPolyline(point, [vertex]), vertex);
    });

    test('projects orthogonally onto a line segment between vertices', () {
      // East-west road along latitude -6.1600 from lng 39.1900 to 39.1950
      const polyline = [
        LatLng(-6.1600, 39.1900),
        LatLng(-6.1600, 39.1950),
      ];
      // User is slightly north of the midpoint of the street
      const user = LatLng(-6.1598, 39.1925);
      final res = PolylineSnap.projectPoint(user, polyline);

      // Snapped latitude should be exactly on the road (-6.1600)
      expect((res.snappedPoint.latitude - (-6.1600)).abs() < 1e-5, isTrue);
      // Snapped longitude should be orthogonal at 39.1925
      expect((res.snappedPoint.longitude - 39.1925).abs() < 1e-5, isTrue);
      // Distance should be approximately 22 meters
      expect(res.distanceToPolylineMeters > 15 && res.distanceToPolylineMeters < 30, isTrue);
      // Not off-route (within 30m default)
      expect(res.isOffRoute, isFalse);
    });

    test('detects off-route when cross-track error exceeds threshold', () {
      const polyline = [
        LatLng(-6.1600, 39.1900),
        LatLng(-6.1600, 39.1950),
      ];
      // User is 100 meters north of the road
      const farUser = LatLng(-6.1590, 39.1925);
      final res = PolylineSnap.projectPoint(farUser, polyline);

      expect(res.distanceToPolylineMeters > 50, isTrue);
      expect(res.isOffRoute, isTrue);
      expect(PolylineSnap.isOffRoute(farUser, polyline), isTrue);
    });

    test('computes along-track remaining distance correctly', () {
      const polyline = [
        LatLng(-6.1600, 39.1900),
        LatLng(-6.1600, 39.1920),
        LatLng(-6.1600, 39.1940),
      ];
      // User is near segment 0 at 39.1910
      const user = LatLng(-6.1600, 39.1910);
      final res = PolylineSnap.projectPoint(user, polyline);

      expect(res.segmentIndex, 0);
      // Remaining distance from 39.1910 to 39.1940 (approx 330m)
      expect(res.remainingDistanceMeters > 300 && res.remainingDistanceMeters < 360, isTrue);
    });

    test('snaps to a polyline segment matching the door\'s longitude', () {
      // Roughly a north-south drag through the heritage peninsula.
      const polyline = [
        LatLng(-6.1575, 39.1936),
        LatLng(-6.1600, 39.1936),
        LatLng(-6.1625, 39.1936),
        LatLng(-6.1650, 39.1936),
      ];
      const doorway = LatLng(-6.1612, 39.1944);
      final snapped = PolylineSnap.snapToPolyline(doorway, polyline);
      // Longitude snaps orthogonally onto the road (39.1936)
      expect((snapped.longitude - 39.1936).abs() < 1e-4, isTrue);
    });
  });
}
