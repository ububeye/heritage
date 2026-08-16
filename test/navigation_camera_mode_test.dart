import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/polyline_snap.dart';
import 'package:stone_town_heritage_vt_guide/data/services/routing_service.dart';

void main() {
  group('Navigation & Camera Logic Tests', () {
    test('PolylineSnap accurately measures cross-track error for off-route detection', () {
      // Straight walking path along Mizingani Road: LatLng(-6.1600, 39.1900) to LatLng(-6.1650, 39.1900)
      const route = [
        LatLng(-6.1600, 39.1900),
        LatLng(-6.1650, 39.1900),
      ];

      // Tourist on route
      const onRoute = LatLng(-6.1625, 39.19005); // ~5m offset
      final onRouteProj = PolylineSnap.projectPoint(onRoute, route, offRouteThresholdMeters: 30.0);
      expect(onRouteProj.isOffRoute, isFalse);
      expect(onRouteProj.distanceToPolylineMeters, lessThan(10.0));

      // Tourist turns down wrong alley (45m east)
      const offRoute = LatLng(-6.1625, 39.19045); // ~50m offset
      final offRouteProj = PolylineSnap.projectPoint(offRoute, route, offRouteThresholdMeters: 30.0);
      expect(offRouteProj.isOffRoute, isTrue);
      expect(offRouteProj.distanceToPolylineMeters, greaterThan(35.0));
    });

    test('RouteStep parsing keeps maneuvers, bearings, and step icons consistent', () {
      const step = RouteStep(
        maneuver: 'turn slight right',
        name: 'Hurumzi Street',
        distanceMeters: 75.0,
        startLocation: LatLng(-6.1610, 39.1920),
        endLocation: LatLng(-6.1615, 39.1925),
        bearingBefore: 180,
        bearingAfter: 135,
      );

      expect(step.mainManeuver, 'turn');
      expect(step.modifierManeuver, 'slight right');
      expect(step.name, 'Hurumzi Street');
      expect(step.bearingBefore, 180);
      expect(step.bearingAfter, 135);
    });
  });
}
