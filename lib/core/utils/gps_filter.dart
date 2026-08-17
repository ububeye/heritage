import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Smooths a noisy GPS stream using an exponential moving average weighted
/// by reported accuracy. Rejects fixes that are obvious outliers (more than
/// 3 σ from the running mean).
///
/// Stone Town has narrow alleys and dense stone walls where the GPS
/// signal is poor. Without smoothing, raw positions can jump 50–100 m
/// between fixes, causing the camera to "drift" and the off-route
/// detector to fire spuriously.
class GpsFilter {
  GpsFilter({this.alpha = 0.35});

  /// Maximum number of recent fixes retained for outlier detection.
  static const int _windowSize = 5;

  /// Outlier rejection threshold in standard deviations.
  static const double _outlierSigma = 3.0;

  /// Weight for the EMA. Higher = more responsive, less smoothing.
  final double alpha;

  /// Running weighted mean (lat, lng). Stays in geographic coordinates
  /// since the smoothing is small enough that the equirectangular
  /// assumption holds for Stone Town (~1.4 km × 1.7 km).
  double? _meanLat;
  double? _meanLng;

  /// Sliding window of recent fixes (lat, lng) for outlier detection.
  final List<_LatLngFix> _window = <_LatLngFix>[];

  /// Smooth the supplied GPS fix. Returns the filtered LatLng, or `null`
  /// if the fix was rejected as an outlier.
  LatLng? filter(Position pos) {
    final lat = pos.latitude;
    final lng = pos.longitude;

    // Reject obviously invalid fixes.
    if (lat.isNaN || lng.isNaN || (lat == 0.0 && lng == 0.0)) {
      return null;
    }

    // Reject low-accuracy fixes that we cannot reasonably integrate.
    if (pos.accuracy > 100) {
      return null;
    }

    // Adopt an accuracy-weighted alpha: better fixes get more weight.
    final adaptiveAlpha = _adaptiveAlpha(pos.accuracy);

    // Outlier detection on the first few fixes we don't have a sample
    // window yet, so we let everything through.
    if (_window.length >= 3) {
      final sd = _standardDeviation();
      if (sd > 0) {
        final dx = _metresBetween(lat, lng, _meanLat!, _meanLng!).abs();
        if (dx > _outlierSigma * sd) {
          return null;
        }
      }
    }

    // Push the new fix into the sliding window.
    _window.add(_LatLngFix(lat, lng));
    if (_window.length > _windowSize) {
      _window.removeAt(0);
    }

    // Update the EMA.
    _meanLat = _meanLat == null
        ? lat
        : (_meanLat! * (1.0 - adaptiveAlpha) + lat * adaptiveAlpha);
    _meanLng = _meanLng == null
        ? lng
        : (_meanLng! * (1.0 - adaptiveAlpha) + lng * adaptiveAlpha);

    return LatLng(_meanLat!, _meanLng!);
  }

  /// Reset the filter (e.g. when the user starts a new navigation).
  void reset() {
    _meanLat = null;
    _meanLng = null;
    _window.clear();
  }

  double _adaptiveAlpha(double accuracy) {
    if (accuracy < 10) return math.min(0.55, alpha + 0.15);
    if (accuracy < 30) return alpha;
    return math.max(0.10, alpha - 0.20);
  }

  double _standardDeviation() {
    if (_window.length < 2) return 0;
    double sum = 0;
    for (final f in _window) {
      sum += _metresBetween(f.lat, f.lng, _meanLat!, _meanLng!);
    }
    final mean = sum / _window.length;
    double variance = 0;
    for (final f in _window) {
      final d = _metresBetween(f.lat, f.lng, _meanLat!, _meanLng!) - mean;
      variance += d * d;
    }
    return math.sqrt(variance / _window.length);
  }

  /// Approximate metres between two lat/lng points. Sufficient for
  /// outlier detection at Stone Town scale.
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

class _LatLngFix {
  const _LatLngFix(this.lat, this.lng);
  final double lat;
  final double lng;
}
