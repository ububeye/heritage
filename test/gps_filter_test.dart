// Unit tests for the GPS smoothing filter.
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/gps_filter.dart';

Position _pos({
  required double lat,
  required double lng,
  double accuracy = 8.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026, 1, 1, 12, 0, 0),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  group('GpsFilter', () {
    test('returns null for the null-island sentinel (0, 0)', () {
      final filter = GpsFilter();
      final result = filter.filter(_pos(lat: 0, lng: 0));
      expect(result, isNull);
    });

    test('returns null for NaN coordinates', () {
      final filter = GpsFilter();
      final result = filter.filter(_pos(lat: double.nan, lng: 39.1936));
      expect(result, isNull);
    });

    test('rejects low-accuracy fixes (> 100m)', () {
      final filter = GpsFilter();
      final result = filter.filter(
        _pos(lat: -6.1620, lng: 39.1936, accuracy: 150),
      );
      expect(result, isNull);
    });

    test('first valid fix is returned unchanged and seeds the EMA', () {
      final filter = GpsFilter();
      final result = filter.filter(_pos(lat: -6.1620, lng: 39.1936));
      expect(result, isNotNull);
      expect((result!.latitude - (-6.1620)).abs() < 1e-9, isTrue);
      expect((result.longitude - 39.1936).abs() < 1e-9, isTrue);
    });

    test('smoothing pulls a noisy fix toward the running mean', () {
      final filter = GpsFilter(alpha: 0.5);
      // First fix seeds the EMA.
      filter.filter(_pos(lat: -6.1620, lng: 39.1936));
      // Second fix is 30m north — the smoothed output should be between
      // the previous mean and the new fix, not equal to either.
      final result = filter.filter(_pos(lat: -6.1593, lng: 39.1936));
      expect(result, isNotNull);
      expect(result!.latitude > -6.1620 && result.latitude < -6.1593, isTrue);
    });

    test('rejects a clear outlier once the window has variance', () {
      // The outlier gate requires a non-zero standard deviation across the
      // window — i.e. realistic GPS noise, not a perfectly stable stream.
      // We seed the window with fixes spread over a few metres to give sd
      // a real value, then drop a fix ~1 km away.
      final filter = GpsFilter(alpha: 0.3);
      final seed = [
        _pos(lat: -6.1620, lng: 39.1936),
        _pos(lat: -6.16205, lng: 39.19365),
        _pos(lat: -6.16195, lng: 39.19355),
        _pos(lat: -6.16210, lng: 39.19370),
        _pos(lat: -6.16190, lng: 39.19350),
      ];
      for (final p in seed) {
        filter.filter(p);
      }
      final outlier = filter.filter(_pos(lat: -6.1500, lng: 39.1936));
      expect(outlier, isNull);
    });

    test('accepts a fix that is near the running mean', () {
      final filter = GpsFilter(alpha: 0.3);
      for (var i = 0; i < 4; i++) {
        filter.filter(_pos(lat: -6.1620, lng: 39.1936));
      }
      // A 5m nudge is well within tolerance.
      final result = filter.filter(_pos(lat: -6.16195, lng: 39.19362));
      expect(result, isNotNull);
    });

    test('reset() clears the EMA so the next fix is treated as a seed', () {
      final filter = GpsFilter();
      filter.filter(_pos(lat: -6.1620, lng: 39.1936));
      filter.filter(_pos(lat: -6.1619, lng: 39.1936));
      filter.reset();
      final result = filter.filter(_pos(lat: -6.1700, lng: 39.2000));
      expect(result, isNotNull);
      // After reset, the first fix IS the EMA — no smoothing applied.
      expect((result!.latitude - (-6.1700)).abs() < 1e-9, isTrue);
      expect((result.longitude - 39.2000).abs() < 1e-9, isTrue);
    });

    test('low-accuracy fixes get a smaller alpha (less trust)', () {
      // Both filters start at the same point. The high-accuracy filter
      // should pull toward the new fix more aggressively than the low-
      // accuracy one.
      final a = GpsFilter(alpha: 0.35);
      final b = GpsFilter(alpha: 0.35);
      a.filter(_pos(lat: -6.1620, lng: 39.1936, accuracy: 5));
      b.filter(_pos(lat: -6.1620, lng: 39.1936, accuracy: 80));
      final ra = a.filter(_pos(lat: -6.1593, lng: 39.1936, accuracy: 5));
      final rb = b.filter(_pos(lat: -6.1593, lng: 39.1936, accuracy: 80));
      // The high-accuracy filter should land closer to the new fix.
      expect(ra!.latitude, greaterThan(rb!.latitude));
    });

    test('handles a long stream of stable fixes without drift', () {
      final filter = GpsFilter();
      for (var i = 0; i < 50; i++) {
        filter.filter(_pos(lat: -6.1620, lng: 39.1936));
      }
      final result = filter.filter(_pos(lat: -6.1620, lng: 39.1936));
      expect(result, isNotNull);
      expect((result!.latitude - (-6.1620)).abs() < 1e-6, isTrue);
      expect((result.longitude - 39.1936).abs() < 1e-6, isTrue);
    });
  });
}
