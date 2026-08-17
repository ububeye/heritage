// Unit tests for the off-route hysteresis filter.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/polyline_snap.dart';

PolylineProjectionResult _proj({
  required LatLng point,
  required double distanceMeters,
  bool isOffRoute = false,
}) {
  return PolylineProjectionResult(
    point: point,
    snappedPoint: point,
    distanceToPolylineMeters: distanceMeters,
    segmentIndex: 0,
    remainingDistanceMeters: 0,
    isOffRoute: isOffRoute,
  );
}

void main() {
  group('OffRouteHysteresis', () {
    test('does not flip on a single off-route sample', () {
      final hyst = OffRouteHysteresis(
        thresholdMeters: 30.0,
        requiredSustained: const Duration(milliseconds: 1500),
      );
      final hit = hyst.onSample(
        _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
      );
      expect(hit, isFalse);
    });

    test(
      'flips after sustained deviation past the required duration',
      () async {
        final hyst = OffRouteHysteresis(
          thresholdMeters: 30.0,
          requiredSustained: const Duration(milliseconds: 100),
        );
        // First off-route sample starts the timer.
        hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
        );
        // Wait past the requiredSustained window.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        // Next sample — same condition — should now flip.
        final hit = hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
        );
        expect(hit, isTrue);
      },
    );

    test(
      'resets the timer when a sample comes back inside the threshold',
      () async {
        final hyst = OffRouteHysteresis(
          thresholdMeters: 30.0,
          requiredSustained: const Duration(milliseconds: 100),
        );
        // Start the off-route timer.
        hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // A clean sample resets the timer.
        final clean = hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 5.0),
        );
        expect(clean, isFalse);
        // Now: even after 100 ms, the next off-route sample should NOT flip
        // because the timer was reset.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final firstRestart = hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
        );
        expect(firstRestart, isFalse, reason: 'Timer should have been reset');
      },
    );

    test('reset() clears the in-flight off-route timer', () {
      final hyst = OffRouteHysteresis(
        thresholdMeters: 30.0,
        requiredSustained: const Duration(milliseconds: 1000),
      );
      hyst.onSample(
        _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
      );
      hyst.reset();
      // Even after waiting, the timer is gone — the next off-route sample
      // is treated as a fresh start.
      final hit = hyst.onSample(
        _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
      );
      expect(hit, isFalse);
    });

    test('sample at exactly the threshold is on-route', () {
      final hyst = OffRouteHysteresis(
        thresholdMeters: 30.0,
        requiredSustained: const Duration(milliseconds: 100),
      );
      final hit = hyst.onSample(
        _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 30.0),
      );
      // `>` not `>=` — at the threshold itself is still on-route.
      expect(hit, isFalse);
    });

    test(
      'one clean sample after sustained off-route flips the flag off',
      () async {
        final hyst = OffRouteHysteresis(
          thresholdMeters: 30.0,
          requiredSustained: const Duration(milliseconds: 50),
        );
        // Warm up to on.
        hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final fired = hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 80.0),
        );
        expect(fired, isTrue);
        // User is back on the route.
        final recovered = hyst.onSample(
          _proj(point: const LatLng(-6.1620, 39.1936), distanceMeters: 5.0),
        );
        expect(recovered, isFalse);
      },
    );
  });
}
