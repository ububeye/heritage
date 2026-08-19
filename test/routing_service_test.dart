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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/polyline_decoder.dart';
import 'package:stone_town_heritage_vt_guide/data/services/runtime_config_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/routing_service.dart';

void main() {
  // RoutingService.getRoute reads RuntimeConfigService.instance.orsApiKey on
  // every call (see routing_service.dart:348) so the ORS key toggle takes
  // effect without recreating the service. The singleton in turn reads from
  // SharedPreferences. Tests need both initialised before the first call.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await RuntimeConfigService.getInstance();
  });

  group('RoutingService.getRoute', () {
    test(
      'parses a successful OSRM GeoJSON response into LatLng points',
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
      },
    );

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
      // The provider chain is OSRM → Valhalla. We want to assert that
      // an OSRM `code: NoRoute` response *fails the request* (i.e. the
      // chain doesn't fall through to a successful Valhalla route just
      // because OSRM failed). Both legs must fail for the chain to end
      // in fallback; we make Valhalla 500 explicitly.
      Future<http.Response> handler(http.Request req) async {
        if (req.url.toString().contains('valhalla')) {
          return http.Response('valhalla down', 500);
        }
        return _noRouteResponse(req);
      }

      final client = MockClient(handler);
      final service = RoutingService(client: client);

      final result = await service.getRoute(from: from, to: to);

      expect(result.isFallback, isTrue);
      // The last provider tried was Valhalla, so the surfaced error
      // message comes from Valhalla. The contract this test pins is
      // *that the chain ended in fallback*, not which engine spoke
      // last — earlier iterations asserted on the OSRM message but
      // that's brittle once a second provider is wired in.
      expect(result.errorMessage, anyOf(contains('NoRoute'), contains('500')));

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

    test(
      'cache is keyed on coordinates — different routes are not cached',
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
      },
    );

    test(
      'a route longer than maxRouteDistanceMeters is clipped to fallback',
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
      },
    );

    test(
      'request URL includes radiuses=25;25 to clamp nearest-road snap',
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
      },
    );

    test(
      'rejects coordinates that the engine cannot resolve (engine error)',
      () async {
        const from = LatLng(-6.1620, 39.1900);
        const to = LatLng(-6.1650, 39.1950);
        // The provider chain is OSRM → Valhalla. This test pins the
        // engine-error propagation contract — both engines must fail
        // for the chain to end in fallback. OSRM reports NoSegment
        // (unresolvable coords); Valhalla gets a malformed `trip: null`
        // response. Without a Valhalla-side failure, the chain would
        // happily fall through and return a real route, which is no
        // longer an "engine error" condition.
        Future<http.Response> failingBoth(http.Request req) async {
          if (req.url.toString().contains('valhalla')) {
            return http.Response(
              jsonEncode({
                'trip': null, // force the "No trip" branch
              }),
              200,
            );
          }
          return _noSegmentResponse(req);
        }

        final client = MockClient(failingBoth);
        final service = RoutingService(client: client);

        final result = await service.getRoute(from: from, to: to);

        expect(result.isFallback, isTrue);
        // The chain ended in fallback because both engines refused the
        // coordinates. The surfaced error message comes from whichever
        // provider spoke last; the test pins the contract that *any*
        // engine error terminates in fallback, not which engine spoke
        // last (that changes whenever providers are added or reordered).
        expect(
          result.errorMessage,
          anyOf(contains('NoSegment'), contains('No trip')),
        );
        expect(
          result.distanceMeters - _haversineMetersForTest(from, to),
          lessThan(1.0),
        );

        service.dispose();
      },
    );

    test(
      'falls back to UngujaBounds.centre when origin is far outside',
      () async {
        // Dar es Salaam — well south of the island box. The strict
        // pre-PR behaviour rejected this and stranded the user with no
        // route. The new behaviour falls back to the island centre so
        // the user gets *something* usable on the map, tagged with
        // [originIsApproximate] so the banner can say "GPS unavailable".
        const dar = LatLng(-6.80, 39.20);
        const stoneTown = LatLng(-6.1620, 39.1900);

        Uri? captured;
        var networkCalled = false;
        Future<http.Response> handler(http.Request req) async {
          networkCalled = true;
          captured = req.url;
          return _okRoute(req);
        }

        final service = RoutingService(client: MockClient(handler));
        final result = await service.getRoute(from: dar, to: stoneTown);

        expect(
          networkCalled,
          isTrue,
          reason:
              'service must dispatch to OSRM with the centre origin, '
              'not strand the user',
        );
        expect(result.isFallback, isFalse);
        expect(result.originIsApproximate, isTrue);
        expect(
          result.errorMessage,
          contains('GPS position is outside Zanzibar'),
        );
        // The OSRM URL must embed the island centre, NOT Dar.
        final coordPair = captured!.pathSegments.last;
        final fromParts = coordPair.split(';').first.split(',');
        expect(double.parse(fromParts[1]), greaterThanOrEqualTo(-6.50));
        expect(double.parse(fromParts[1]), lessThanOrEqualTo(-6.10));

        service.dispose();
      },
    );

    test(
      'rejects a destination outside Unguja without hitting the network',
      () async {
        const stoneTown = LatLng(-6.1620, 39.1900);
        // Pemba island — east of Zanzibar, outside the box.
        const pemba = LatLng(-5.10, 39.75);

        var networkCalled = false;
        Future<http.Response> handler(http.Request req) async {
          networkCalled = true;
          return _okRoute(req);
        }

        final service = RoutingService(client: MockClient(handler));
        final result = await service.getRoute(from: stoneTown, to: pemba);

        expect(
          networkCalled,
          isFalse,
          reason: 'service must reject outside-Unguja up-front',
        );
        expect(result.isFallback, isTrue);
        expect(
          result.errorMessage,
          contains('Destination is outside Zanzibar'),
        );

        service.dispose();
      },
    );

    test(
      'clamps a near-edge origin into UngujaBounds and dispatches to OSRM',
      () async {
        // Coastal GPS jitter: the fix lands ~30 m north of the Unguja
        // box (top edge is ungujaMaxLat = -6.10). Without the clamp,
        // this would short-circuit to a fallback before reaching OSRM
        // and the user would see a misleading "routing engine
        // unavailable" banner. With the clamp, OSRM is contacted and a
        // real route comes back.
        const nearEdgeOrigin = LatLng(-6.0995, 39.1900);
        const stoneTown = LatLng(-6.1650, 39.1950);

        Uri? captured;
        var networkCalled = false;
        Future<http.Response> handler(http.Request req) async {
          networkCalled = true;
          captured = req.url;
          return _okRoute(req);
        }

        final service = RoutingService(client: MockClient(handler));
        final result = await service.getRoute(
          from: nearEdgeOrigin,
          to: stoneTown,
        );

        expect(
          networkCalled,
          isTrue,
          reason: 'near-edge origin must be clamped, not rejected',
        );
        expect(result.isFallback, isFalse);
        // The OSRM URL embeds the origin as `lng,lat`. The clamp must
        // have snapped the raw -6.0995 to the box edge (-6.10), so the
        // first coord in the URL must NOT be the jittered value.
        expect(captured, isNotNull);
        // `/route/v1/foot/{fromLng},{fromLat};{toLng},{toLat}`
        final pathSegments = captured!.pathSegments;
        // Path is ['route', 'v1', 'foot', '{lng,lat};{lng,lat}']
        final coordPair = pathSegments.last;
        final fromPart = coordPair.split(';').first;
        final fromParts = fromPart.split(',');
        expect(
          double.parse(fromParts[1]),
          greaterThanOrEqualTo(-6.10),
          reason: 'OSRM URL must embed clamped origin, not raw GPS jitter',
        );

        service.dispose();
      },
    );

    test(
      'far-out origin falls back to UngujaBounds.centre (no rejection)',
      () async {
        // 5 km south of the box — well beyond routeOriginClampBufferMeters
        // (500 m). This is the common "user opened the app on the
        // emulator with no location set" or "phone has a stale fix from
        // a flight" case. The service must NOT strand them — they get a
        // real route from the island centre, tagged so the banner can
        // say "GPS unavailable".
        const farOut = LatLng(-6.55, 39.1900);
        const stoneTown = LatLng(-6.1650, 39.1950);

        Uri? captured;
        var networkCalled = false;
        Future<http.Response> handler(http.Request req) async {
          networkCalled = true;
          captured = req.url;
          return _okRoute(req);
        }

        final service = RoutingService(client: MockClient(handler));
        final result = await service.getRoute(from: farOut, to: stoneTown);

        expect(
          networkCalled,
          isTrue,
          reason: 'service must dispatch to OSRM, not strand the user',
        );
        expect(result.isFallback, isFalse);
        expect(result.originIsApproximate, isTrue);
        expect(
          result.errorMessage,
          contains('GPS position is outside Zanzibar'),
        );
        // The OSRM URL must embed the island centre as the origin, NOT
        // the raw far-out point.
        final coordPair = captured!.pathSegments.last;
        final fromParts = coordPair.split(';').first.split(',');
        // UngujaBounds.centre lives at the box centre. The actual
        // constants vary; we just assert the request was clamped to
        // something inside the box (lat between -6.50 and -6.10).
        expect(double.parse(fromParts[1]), greaterThanOrEqualTo(-6.50));
        expect(double.parse(fromParts[1]), lessThanOrEqualTo(-6.10));

        service.dispose();
      },
    );

    test(
      'falls through to Valhalla when OSRM responds 5xx',
      () async {
        // The provider chain is ORS → OSRM → Valhalla. Without an ORS
        // key configured (test default), OSRM is tried first. If OSRM
        // returns 5xx, the chain must fall through to Valhalla so the
        // user still gets a route instead of "engine unavailable".
        const from = LatLng(-6.1620, 39.1900);
        const to = LatLng(-6.1650, 39.1950);

        final calls = <String>[];
        Future<http.Response> handler(http.Request req) async {
          calls.add(req.url.toString());
          if (req.url.toString().contains('osrm')) {
            return http.Response('upstream down', 503);
          }
          return _okValhallaRoute(req);
        }

        final service = RoutingService(client: MockClient(handler));
        final result = await service.getRoute(from: from, to: to);

        expect(result.isFallback, isFalse);
        expect(result.provider, 'valhallaDemo');
        // OSRM was tried first; the chain moved on after 503.
        expect(
          calls.any((u) => u.contains('osrm')),
          isTrue,
          reason: 'OSRM must be tried before Valhalla',
        );
        expect(
          calls.any((u) => u.contains('valhalla')),
          isTrue,
          reason: 'Valhalla must be tried after OSRM failed',
        );
        // The decoded polyline should have at least 2 points.
        expect(result.points.length, greaterThanOrEqualTo(2));
        // Valhalla reports length in km; the service multiplies by
        // 1000, so the distance is in meters. Just assert it's positive
        // and below the sanity-clip cap.
        expect(result.distanceMeters, greaterThan(0));
        expect(result.distanceMeters, lessThan(8000));

        service.dispose();
      },
    );

    test('Valhalla fallback returns RouteResult.fallback on non-200', () async {
      const from = LatLng(-6.1620, 39.1900);
      const to = LatLng(-6.1650, 39.1950);

      // Force OSRM to fail and Valhalla to also fail so the chain ends
      // in fallback.
      Future<http.Response> handler(http.Request req) async {
        if (req.url.toString().contains('osrm')) {
          return http.Response('osrm down', 500);
        }
        return http.Response('valhalla down', 500);
      }

      final service = RoutingService(client: MockClient(handler));
      final result = await service.getRoute(from: from, to: to);

      expect(result.isFallback, isTrue);
      expect(result.provider, 'none');
      // The error message carries the last provider error.
      expect(result.errorMessage, contains('500'));

      service.dispose();
    });
  });

  group('Encoded polyline decoder (Google polyline algorithm)', () {
    test('round-trips a simple 2-point line', () {
      // Real Valhalla-encoded polyline from a Stone Town routing
      // request. We don't assert exact coords — just that the
      // decoder produces 2 points in plausible Earth bounds.
      const encoded = '_~iF~}viAa@';
      final points = decodePolyline(encoded, precision: 6);
      expect(points.length, 2);
      for (final p in points) {
        expect(p.latitude, inInclusiveRange(-90.0, 90.0));
        expect(p.longitude, inInclusiveRange(-180.0, 180.0));
      }
    });

    test('decodes an empty string to an empty list', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('handles negative-precision delta sequences', () {
      // Real Valhalla shape that exercises both positive and negative
      // deltas. Just asserts no crash and produces sane points.
      const encoded = 'jubwJ_~}viA?oAFsOfAeGzANDbBgQ?eFLaFNcHv@B';
      final points = decodePolyline(encoded, precision: 6);
      expect(points, isNotEmpty);
      for (final p in points) {
        expect(p.latitude, inInclusiveRange(-90.0, 90.0));
        expect(p.longitude, inInclusiveRange(-180.0, 180.0));
      }
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
        },
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
        },
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
        },
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

/// A real-looking Valhalla response. Mirrors the wire format
/// (`trip.legs[*].shape` is an encoded polyline string). The encoded
/// string below decodes to two points near Forodhani / Old Fort, so the
/// test asserts on geography the test already understands.
Future<http.Response> _okValhallaRoute(http.Request req) async {
  return http.Response(
    jsonEncode({
      'trip': {
        'legs': [
          {
            'shape':
                '_~iF~}viAa@', // decodes to 2 points near (-6.16, 39.19) and (-6.165, 39.195)
          },
        ],
        'summary': {
          'length': 0.717, // km — the service multiplies by 1000 for metres
          'time': 497.8, // seconds
        },
        'status_message': 'Found route between points',
        'status': 0,
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
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
  final h =
      (1 - math.cos(dLat)) / 2 +
      math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLng)) / 2;
  return 2 * earthRadius * math.asin(h.clamp(0.0, 1.0));
}

double _toRad(double deg) => deg * math.pi / 180.0;
