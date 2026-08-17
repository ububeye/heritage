// Unit tests for the heading source (handles the heading == 0 edge case).
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/heading_source.dart';

Position _pos({
  required double lat,
  required double lng,
  double heading = 0.0,
  double headingAccuracy = 0.0,
  DateTime? timestamp,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp ?? DateTime(2026, 1, 1, 12, 0, 0),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: heading,
    headingAccuracy: headingAccuracy,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  group('HeadingSource', () {
    test('uses pos.heading == 0 when headingAccuracy is trusted', () {
      // The original bug: heading == 0 was treated as "no fix". The fix
      // trusts the heading iff headingAccuracy is reported and < 30°.
      final src = HeadingSource();
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 0.0, headingAccuracy: 5.0),
      );
      expect(src.currentDeg, isNotNull);
      expect(src.currentDeg, closeTo(0.0, 0.01));
    });

    test('honours a non-zero trusted heading', () {
      final src = HeadingSource();
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 90.0, headingAccuracy: 5.0),
      );
      expect(src.currentDeg, closeTo(90.0, 0.01));
    });

    test(
      'falls back to GPS-derived bearing when headingAccuracy is bad',
      () async {
        final src = HeadingSource();
        // First fix seeds the previous-fix state.
        src.onPosition(
          _pos(
            lat: -6.1620,
            lng: 39.1936,
            timestamp: DateTime(2026, 1, 1, 12, 0, 0),
            heading: 0.0,
            headingAccuracy: 0.0, // unknown — fall back
          ),
        );
        // HeadingSource stores DateTime.now() internally, so real wall-clock
        // time must elapse between samples for the dt > 0 gate.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        // Second fix is ~111m east — bearing should be ~90°.
        src.onPosition(
          _pos(
            lat: -6.1620,
            lng: 39.1946,
            timestamp: DateTime(2026, 1, 1, 12, 0, 1),
            heading: 0.0,
            headingAccuracy: 0.0,
          ),
        );
        expect(src.currentDeg, isNotNull);
        expect(src.currentDeg!, closeTo(90.0, 5.0));
      },
    );

    test('does not update the heading when neither source is usable', () {
      final src = HeadingSource();
      // Anchor with a trusted fix.
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 45.0, headingAccuracy: 5.0),
      );
      final before = src.currentDeg;
      // Now feed a fix with no heading info AND no displacement (rejected
      // by the 2m gate).
      src.onPosition(
        _pos(
          lat: -6.1620,
          lng: 39.1936,
          timestamp: DateTime(2026, 1, 1, 12, 0, 1),
          heading: 0.0,
          headingAccuracy: 0.0,
        ),
      );
      expect(src.currentDeg, before);
    });

    test('EMA smooths jitter between two close headings', () {
      final src = HeadingSource();
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 80.0, headingAccuracy: 5.0),
      );
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 100.0, headingAccuracy: 5.0),
      );
      // Second update should be a blend toward 100, not the raw value.
      expect(src.currentDeg, isNotNull);
      expect(src.currentDeg!, greaterThan(80.0));
      expect(src.currentDeg!, lessThan(100.0));
    });

    test('handles wrap-around at 0/360 without flipping', () {
      final src = HeadingSource();
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 350.0, headingAccuracy: 5.0),
      );
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 10.0, headingAccuracy: 5.0),
      );
      // The blended heading should be near 0/360, not near 180.
      final h = src.currentDeg!;
      expect(
        h < 30.0 || h > 330.0,
        isTrue,
        reason: 'Expected heading near 360°; got $h',
      );
    });

    test('reset() clears state so the next fix is un-smoothed', () {
      final src = HeadingSource();
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 90.0, headingAccuracy: 5.0),
      );
      src.reset();
      expect(src.currentDeg, isNull);
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 180.0, headingAccuracy: 5.0),
      );
      expect(src.currentDeg, closeTo(180.0, 0.01));
    });

    test('ignores fixes older than 5 seconds for bearing fallback', () {
      final src = HeadingSource();
      src.onPosition(
        _pos(
          lat: -6.1620,
          lng: 39.1936,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
          heading: 45.0,
          headingAccuracy: 5.0,
        ),
      );
      final before = src.currentDeg;
      // 10-second gap — the fallback should refuse to compute a bearing.
      src.onPosition(
        _pos(
          lat: -6.1620,
          lng: 39.1946,
          timestamp: DateTime(2026, 1, 1, 12, 0, 10),
          heading: 0.0,
          headingAccuracy: 0.0,
        ),
      );
      expect(src.currentDeg, before);
    });

    test('stale fallback (no-bearing fix) does not erase a prior heading', () {
      final src = HeadingSource();
      src.onPosition(
        _pos(lat: -6.1620, lng: 39.1936, heading: 45.0, headingAccuracy: 5.0),
      );
      final before = src.currentDeg;
      // 6-second gap — too long for the fallback, lone new fix.
      src.onPosition(
        _pos(
          lat: -6.1620,
          lng: 39.1936,
          timestamp: DateTime(2026, 1, 1, 12, 0, 6),
          heading: 0.0,
          headingAccuracy: 0.0,
        ),
      );
      expect(src.currentDeg, before);
    });
  });

  group('HeadingMath.toUnitVector', () {
    test('heading 0° projects due north (positive latitude)', () {
      final v = 0.0.toUnitVector(metres: 1000);
      expect(v.latitude, greaterThan(0));
      expect(v.longitude.abs(), lessThan(1e-6));
    });

    test('heading 90° projects due east (positive longitude)', () {
      final v = 90.0.toUnitVector(metres: 1000);
      expect(v.longitude, greaterThan(0));
      expect(v.latitude.abs(), lessThan(1e-6));
    });

    test('heading 180° projects due south (negative latitude)', () {
      final v = 180.0.toUnitVector(metres: 1000);
      expect(v.latitude, lessThan(0));
      expect(v.longitude.abs(), lessThan(1e-6));
    });
  });
}
