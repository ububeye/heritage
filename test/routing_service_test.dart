// Unit tests for [RoutingService].
//
// These tests exercise the OSRM demo path (the default, no ORS key
// configured). The ORS path is structurally identical — both produce
// GeoJSON `LineString` features that go through the same parser — so
// verifying one gives us high confidence in the other. The ORS path
// is skipped in CI because `AppConstants.orsApiKey` is a compile-time
// constant and we don't want to embed secrets in test fixtures.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/data/services/routing_service.dart';

void main() {
  group('RoutingService.getRoute', () {
    test('parses a successful OSRM GeoJSON response into LatLng points',
        () async {
      // Coordinates roughly inside Stone Town — keeps the test
      // independent of any other geographic config.
      const from = LatLng(-6.1620, 39.1900); // near Forodhani
      const to = LatLng(-6.1650, 39.1950); // nearby
      final client = MockClient(_okRoute);
      final service = RoutingService(client: client);

      final result = await service.getRoute(from: from, to: to);

      expect(result.isFallback, isFalse);
      expect(result.provider, 'osrmDemo');
      expect(result.distanceMeters, 432.0);
      expect(result.durationSeconds, 311.0);
      expect(result.points, hasLength(3));
      // GeoJSON is [lng, lat]; latlong2 wants (lat, lng).
      expect(result.points.first, const LatLng(-6.1620, 39.1900));
      expect(result.points.last, const LatLng(-6.1650, 39.1950));

      service.dispose();
    });

    test('returns a fallback when OSRM responds with non-200', () async {
      const from = LatLng(-6.1620, 39.1900);
      const to = LatLng(-6.1650, 39.1950);
      final client = MockClient(_upstreamDown);
      final service = RoutingService(client: client);

      final result = await service.getRoute(from: from, to: to);

      expect(result.isFallback, isTrue);
      expect(result.provider, 'none');
      expect(result.errorMessage, contains('503'));
      expect(result.points, hasLength(2));
      expect(result.points.first, from);
      expect(result.points.last, to);

      service.dispose();
    });

    test('returns a fallback when OSRM returns an error code', () async {
      const from = LatLng(-6.1620, 39.1900);
      const to = LatLng(-6.1650, 39.1950);
      final client = MockClient(_noRouteResponse);
      final service = RoutingService(client: client);

      final result = await service.getRoute(from: from, to: to);

      expect(result.isFallback, isTrue);
      expect(result.errorMessage, contains('NoRoute'));

      service.dispose();
    });

    test('30-minute cache short-circuits repeat calls', () async {
      const from = LatLng(-6.1620, 39.1900);
      const to = LatLng(-6.1650, 39.1950);
      var callCount = 0;
      Future<http.Response> countingHandler(http.Request req) async {
        callCount += 1;
        return _okRoute(req);
      }

      final service = RoutingService(client: MockClient(countingHandler));

      final first = await service.getRoute(from: from, to: to);
      final second = await service.getRoute(from: from, to: to);

      expect(first.isFallback, isFalse);
      expect(second.isFallback, isFalse);
      expect(callCount, 1, reason: 'second call should be served from cache');

      service.dispose();
    });

    test('cache is keyed on coordinates — different routes are not cached',
        () async {
      // Both pairs inside the Stone Town box so the new bounds check
      // doesn't reject them up-front.
      const fromA = LatLng(-6.1620, 39.1900);
      const toA = LatLng(-6.1650, 39.1950);
      const fromB = LatLng(-6.1610, 39.1880);
      const toB = LatLng(-6.1640, 39.1920);
      var callCount = 0;
      Future<http.Response> handler(http.Request req) async {
        callCount += 1;
        return _shortRoute(req);
      }

      final service = RoutingService(client: MockClient(handler));

      await service.getRoute(from: fromA, to: toA);
      await service.getRoute(from: fromB, to: toB);

      expect(callCount, 2);

      service.dispose();
    });

    test('a route longer than maxRouteDistanceMeters is clipped to fallback',
        () async {
      // Cross-country "route" — the routing engine resolved a long
      // motorway path that should never be drawn on a Stone Town map.
      const from = LatLng(-6.1620, 39.1900);
      const to = LatLng(-6.1650, 39.1950);
      final client = MockClient(_crossCountryRoute);
      final service = RoutingService(client: client);

      final result = await service.getRoute(from: from, to: to);

      expect(result.isFallback, isTrue);
      expect(result.errorMessage, contains('Route too long'));
      // Fallback polyline is just the two endpoints.
      expect(result.points, hasLength(2));
      expect(result.distanceMeters, lessThan(1000.0));

      service.dispose();
    });

    test('request URL includes radiuses=25;25 to clamp nearest-road snap',
        () async {
      const from = LatLng(-6.1620, 39.1900);
      const to = LatLng(-6.1650, 39.1950);
      Uri? captured;
      Future<http.Response> handler(http.Request req) async {
        captured = req.url;
        return _shortRoute(req);
      }

      final service = RoutingService(client: MockClient(handler));

      await service.getRoute(from: from, to: to);

      expect(captured, isNotNull);
      expect(captured!.queryParameters['radiuses'], '25;25');
      expect(captured!.path, contains('/route/v1/foot/'));

      service.dispose();
    });

    test('rejects coordinates that the engine cannot resolve (engine error)',
        () async {
      const from = LatLng(-6.1620, 39.1900);
      const to = LatLng(-6.1650, 39.1950);
      final client = MockClient(_noSegmentResponse);
      final service = RoutingService(client: client);

      final result = await service.getRoute(from: from, to: to);

      expect(result.isFallback, isTrue);
      expect(result.errorMessage, contains('NoSegment'));
      expect(
        result.distanceMeters - _haversineMetersForTest(from, to),
        lessThan(1.0),
      );

      service.dispose();
    });
  });
}

// =================== MockClient handlers ===================

/// Three-point Stone Town route with explicit distance / duration.
Future<http.Response> _okRoute(http.Request req) async {
  return http.Response(
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [39.1900, -6.1620],
              [39.1925, -6.1635],
              [39.1950, -6.1650],
            ],
          },
          'distance': 432.0,
          'duration': 311.0,
        }
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

/// Short, generic 2-point response for tests that just need *some*
/// valid route shape.
Future<http.Response> _shortRoute(http.Request req) async {
  return http.Response(
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [39.1900, -6.1620],
              [39.1950, -6.1650],
            ],
          },
          'distance': 100.0,
        }
      ],
    }),
    200,
  );
}

/// Cross-country snap — far-away waypoint + 25 km reported distance.
/// Used to exercise the sanity-clip in `RoutingService.getRoute`.
Future<http.Response> _crossCountryRoute(http.Request req) async {
  return http.Response(
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [39.1900, -6.1620],
              [39.5000, -6.5000], // far away — cross-country snap
              [39.1950, -6.1650],
            ],
          },
          'distance': 25000.0, // 25 km — well past the 8 km cap
          'duration': 18000.0,
        }
      ],
    }),
    200,
  );
}

/// Engine-level error response with a 5xx status.
Future<http.Response> _upstreamDown(http.Request req) async {
  return http.Response('upstream down', 503);
}

/// Engine-level error response with a non-Ok code.
Future<http.Response> _noRouteResponse(http.Request req) async {
  return http.Response(
    jsonEncode({'code': 'NoRoute', 'message': 'no segment'}),
    200,
  );
}

/// Engine-level error response for an unresolvable origin/destination.
Future<http.Response> _noSegmentResponse(http.Request req) async {
  return http.Response(
    jsonEncode({
      'code': 'NoSegment',
      'message': 'Could not find a matching segment for input',
    }),
    200,
  );
}

// =================== Helpers ===================

/// Mirrors the haversine math used inside RoutingService so the
/// fallback-distance assertion has a ground truth that's independent
/// of the implementation under test.
double _haversineMetersForTest(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _toRad(b.latitude - a.latitude);
  final dLng = _toRad(b.longitude - a.longitude);
  final lat1 = _toRad(a.latitude);
  final lat2 = _toRad(b.latitude);
  final h = (1 - math.cos(dLat)) / 2 +
      math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLng)) / 2;
  return 2 * earthRadius * math.asin(h.clamp(0.0, 1.0));
}

double _toRad(double deg) => deg * math.pi / 180.0;
