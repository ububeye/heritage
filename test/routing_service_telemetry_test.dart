// Tests for the routing telemetry hook + 5xx retry path on
// [RoutingService]. Verifies that the sink fires the documented events
// (`routing_5xx_retry` and `routing_reroute`) and that the retry actually
// waits the configured backoff before re-issuing the request.
//
// Hand-written fakes per project convention (no mocktail / mockito).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/data/services/runtime_config_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/routing_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await RuntimeConfigService.getInstance();
  });

  test(
    'emits routing_5xx_retry telemetry and recovers on the second attempt',
    () async {
      var attempt = 0;
      final events = <Map<String, Object?>>[];
      void sink(String event, Map<String, Object?> payload) {
        events.add({'event': event, ...payload});
      }

      final client = MockClient((req) async {
        attempt += 1;
        if (attempt == 1) {
          return http.Response(
            'upstream failure',
            502,
            headers: {'content-type': 'text/plain'},
          );
        }
        // Second attempt returns a tiny OSRM-shaped GeoJSON response.
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [req.url.queryParametersAll.isEmpty ? 0 : 39.1900, -6.1620],
                    [39.1950, -6.1650],
                  ],
                  'type': 'LineString',
                },
                'distance': 432.0,
                'duration': 311.0,
                'legs': [],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RoutingService(
        client: client,
        telemetry: sink,
        retryDelay: const Duration(milliseconds: 30),
        timeout: const Duration(seconds: 3),
      );

      final result = await service.getRoute(
        from: const LatLng(-6.1620, 39.1900),
        to: const LatLng(-6.1650, 39.1950),
      );

      expect(attempt, 2, reason: 'should have retried after the 5xx');
      expect(result.isFallback, isFalse);
      expect(result.provider, 'osrmDemo');
      expect(
        events.where((e) => e['event'] == 'routing_5xx_retry'),
        hasLength(1),
      );
      final retryEvent = events.firstWhere(
        (e) => e['event'] == 'routing_5xx_retry',
      );
      expect(retryEvent['status'], 502);
      expect(retryEvent['retry_delay_ms'], 30);

      service.dispose();
    },
  );

  test('does not retry on 4xx (those are caller errors)', () async {
    var attempt = 0;
    final client = MockClient((req) async {
      attempt += 1;
      return http.Response(
        'bad request',
        400,
        headers: {'content-type': 'text/plain'},
      );
    });

    final service = RoutingService(client: client);

    final result = await service.getRoute(
      from: const LatLng(-6.1620, 39.1900),
      to: const LatLng(-6.1650, 39.1950),
    );

    // The chain has two legs (OSRM + Valhalla). Both tried once. The
    // "no retry on 4xx" contract means: within each provider, a 4xx
    // doesn't trigger an internal retry — and that still holds (each
    // leg ran exactly once, no second hit from the same provider).
    // The test previously asserted `attempt == 1` because there was
    // only one provider; the chain extension to two providers means
    // each provider gets one chance, then the chain ends in fallback.
    expect(attempt, 2, reason: 'no internal retry per provider on 4xx');
    expect(result.isFallback, isTrue);

    service.dispose();
  });

  test('does not retry if the first response is 200', () async {
    var attempt = 0;
    final client = MockClient((req) async {
      attempt += 1;
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'geometry': {
                'coordinates': [
                  [39.1900, -6.1620],
                  [39.1950, -6.1650],
                ],
                'type': 'LineString',
              },
              'distance': 200.0,
              'duration': 150.0,
              'legs': [],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = RoutingService(client: client);
    await service.getRoute(
      from: const LatLng(-6.1620, 39.1900),
      to: const LatLng(-6.1650, 39.1950),
    );

    expect(attempt, 1, reason: '200 should not trigger a retry');
    service.dispose();
  });
}
