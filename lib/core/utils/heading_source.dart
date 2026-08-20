import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Source of the current heading as a direction in degrees (0 = north, 90 =
/// east). The previous implementation treated `Position.heading == 0.0`
/// as "no fix" — but 0 is a valid heading (north) and many devices
/// report 0 when stationary. This class handles that correctly.
class HeadingSource {
  HeadingSource();

  /// The most recent trusted heading in degrees.
  double? _currentDeg;

  /// Hysteresis state — the EMA on the previous heading for jitter
  /// reduction.
  double? _emaDeg;

  /// Previous GPS fix used for bearing-derived fallback.
  double? _prevLat;
  double? _prevLng;
  DateTime? _prevAt;

  /// Acceptable heading accuracy. Out-of-band readings are ignored.
  static const double _minHeadingAccuracyDeg = 30.0;

  /// Smoothing factor for the EMA. 0.18 = ~5° hysteresis.
  static const double _alpha = 0.18;

  /// The current heading in degrees, or null if no clean reading is
  /// available yet.
  double? get currentDeg => _currentDeg;

  /// Update the heading from a fresh GPS position.
  ///
  /// Strategy:
  /// 1. If `pos.headingAccuracy > 0` and `pos.headingAccuracy < 30°` and
  ///    `pos.heading != null`, use `pos.heading` directly.
  /// 2. Else, fall back to a bearing computed from two consecutive fixes
  ///    if the previous fix is recent enough (within 5 s) and the
  ///    displacement is large enough (more than 2 m).
  /// 3. Apply a small EMA to avoid jitter.
  void onPosition(Position pos) {
    final h = pos.heading;
    final hAcc = pos.headingAccuracy;

    double? candidate;

    if (hAcc.isFinite && hAcc > 0 && hAcc < _minHeadingAccuracyDeg) {
      candidate = _normalizeDeg(h.toDouble());
    } else {
      // Fall back to GPS-derived bearing.
      final now = DateTime.now();
      if (_prevLat != null && _prevLng != null && _prevAt != null) {
        final dt = now.difference(_prevAt!).inMilliseconds;
        if (dt > 0 && dt < 5000) {
          final distance = _metresBetween(
            _prevLat!,
            _prevLng!,
            pos.latitude,
            pos.longitude,
          );
          if (distance > 2.0) {
            final bearing = _bearingBetween(
              _prevLat!,
              _prevLng!,
              pos.latitude,
              pos.longitude,
            );
            candidate = bearing;
          }
        }
      }
    }

    _prevLat = pos.latitude;
    _prevLng = pos.longitude;
    _prevAt = DateTime.now();

    if (candidate == null) {
      return;
    }

    // Apply EMA with circular interpolation.
    if (_emaDeg == null) {
      _emaDeg = candidate;
    } else {
      _emaDeg = _circularLerp(_emaDeg!, candidate, _alpha);
    }

    _currentDeg = _emaDeg;
  }

  /// Reset the heading state (e.g. when starting a new navigation or when
  /// the user changes mode).
  void reset() {
    _currentDeg = null;
    _emaDeg = null;
    _prevLat = null;
    _prevLng = null;
    _prevAt = null;
  }

  static double _normalizeDeg(double deg) {
    var d = deg % 360.0;
    if (d < 0) d += 360.0;
    return d;
  }

  /// Linearly interpolate between two angles taken as degrees, handling
  /// wrap-around at 0/360.
  static double _circularLerp(double from, double to, double t) {
    var diff = to - from;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return _normalizeDeg(from + diff * t);
  }

  static double _bearingBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final lam1 = lng1 * math.pi / 180.0;
    final lam2 = lng2 * math.pi / 180.0;
    final y = math.sin(lam2 - lam1) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(lam2 - lam1);
    final theta = math.atan2(y, x);
    return _normalizeDeg(theta * 180.0 / math.pi);
  }

  static double _metresBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final latAvg = (lat1 + lat2) / 2.0;
    final cosLat = math.cos(latAvg * math.pi / 180.0);
    final dx = (lng2 - lng1) * 111139.0 * cosLat;
    final dy = (lat2 - lat1) * 111139.0;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Extension to convert a heading to a vector, useful for HUD sprites.
extension HeadingMath on num {
  /// Project this heading into a unit vector in (lat, lng) space.
  LatLng toUnitVector({double metres = 1.0}) {
    final radians = toDouble() * math.pi / 180.0;
    final dLat = metres * math.cos(radians) / 111139.0;
    final dLng = metres * math.sin(radians) / 111139.0;
    return LatLng(dLat, dLng);
  }
}
