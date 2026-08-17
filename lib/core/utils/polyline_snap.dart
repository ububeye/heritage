import 'dart:math' as math;
import 'package:latlong2/latlong.dart' show LatLng;
import 'distance_calculator.dart' as dc;

/// Result of projecting a geographic point onto a polyline.
class PolylineProjectionResult {
  const PolylineProjectionResult({
    required this.point,
    required this.snappedPoint,
    required this.distanceToPolylineMeters,
    required this.segmentIndex,
    required this.remainingDistanceMeters,
    required this.isOffRoute,
  });

  /// The original input coordinate.
  final LatLng point;

  /// The closest point along the polyline segments (orthogonal projection).
  final LatLng snappedPoint;

  /// Perpendicular (cross-track) distance from [point] to [snappedPoint] in meters.
  final double distanceToPolylineMeters;

  /// Index of the polyline segment containing [snappedPoint] (0 to polyline.length - 2).
  final int segmentIndex;

  /// Total remaining distance in meters from [snappedPoint] to the end of the polyline.
  final double remainingDistanceMeters;

  /// True if [distanceToPolylineMeters] exceeds the configured threshold.
  final bool isOffRoute;
}

/// Robust geometric projection and snapping for navigation polylines.
///
/// Features:
/// - True orthogonal point-to-line-segment projection (not just vertex snapping).
/// - Accurate cross-track error measurement in meters.
/// - Along-track remaining distance calculation.
/// - Off-route deviation detection.
class PolylineSnap {
  PolylineSnap._();

  /// Default off-route tolerance threshold in meters.
  /// Kept as a constant for backward compatibility; the canonical
  /// value lives in `AppConstants.offRouteThresholdMeters`.
  static const double defaultOffRouteThresholdMeters = 30.0;

  /// Snaps [point] to the closest point along the segments of [polyline].
  ///
  /// If [polyline] is empty, returns [point] unchanged.
  /// If [polyline] has only 1 point, returns that point.
  static LatLng snapToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return point;
    if (polyline.length == 1) return polyline.first;
    return projectPoint(point, polyline).snappedPoint;
  }

  /// Detailed orthogonal projection of [point] onto [polyline].
  static PolylineProjectionResult projectPoint(
    LatLng point,
    List<LatLng> polyline, {
    double offRouteThresholdMeters = defaultOffRouteThresholdMeters,
  }) {
    if (polyline.isEmpty) {
      return PolylineProjectionResult(
        point: point,
        snappedPoint: point,
        distanceToPolylineMeters: 0,
        segmentIndex: -1,
        remainingDistanceMeters: 0,
        isOffRoute: false,
      );
    }

    if (polyline.length == 1) {
      final single = polyline.first;
      final dist = dc.DistanceCalculator.calculateDistance(
        point.latitude,
        point.longitude,
        single.latitude,
        single.longitude,
      );
      return PolylineProjectionResult(
        point: point,
        snappedPoint: single,
        distanceToPolylineMeters: dist,
        segmentIndex: -1,
        remainingDistanceMeters: 0,
        isOffRoute: dist > offRouteThresholdMeters,
      );
    }

    int bestSegmentIndex = 0;
    LatLng bestSnapped = polyline.first;
    double minDistanceMeters = double.infinity;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];

      final proj = _projectOntoSegment(point, a, b);
      final dist = dc.DistanceCalculator.calculateDistance(
        point.latitude,
        point.longitude,
        proj.latitude,
        proj.longitude,
      );

      if (dist < minDistanceMeters) {
        minDistanceMeters = dist;
        bestSnapped = proj;
        bestSegmentIndex = i;
      }
    }

    // Compute remaining distance from bestSnapped along the polyline to the end
    double remainingDist = dc.DistanceCalculator.calculateDistance(
      bestSnapped.latitude,
      bestSnapped.longitude,
      polyline[bestSegmentIndex + 1].latitude,
      polyline[bestSegmentIndex + 1].longitude,
    );

    for (int i = bestSegmentIndex + 1; i < polyline.length - 1; i++) {
      remainingDist += dc.DistanceCalculator.calculateDistance(
        polyline[i].latitude,
        polyline[i].longitude,
        polyline[i + 1].latitude,
        polyline[i + 1].longitude,
      );
    }

    return PolylineProjectionResult(
      point: point,
      snappedPoint: bestSnapped,
      distanceToPolylineMeters: minDistanceMeters,
      segmentIndex: bestSegmentIndex,
      remainingDistanceMeters: remainingDist,
      isOffRoute: minDistanceMeters > offRouteThresholdMeters,
    );
  }

  /// Checks if [point] is off the [polyline] by more than [thresholdMeters].
  static bool isOffRoute(
    LatLng point,
    List<LatLng> polyline, {
    double thresholdMeters = defaultOffRouteThresholdMeters,
  }) {
    if (polyline.length < 2) return false;
    final res = projectPoint(
      point,
      polyline,
      offRouteThresholdMeters: thresholdMeters,
    );
    return res.isOffRoute;
  }

  /// Orthogonal projection of [p] onto segment $[a, b]$.
  /// Uses equirectangular planar projection scaled by local latitude.
  static LatLng _projectOntoSegment(LatLng p, LatLng a, LatLng b) {
    final latAvg = (a.latitude + b.latitude + p.latitude) / 3.0;
    final cosLat = math.cos(latAvg * math.pi / 180.0);

    // Convert to local meter-scaled coordinates relative to 'a'
    const metersPerDegreeLat = 111139.0;
    final metersPerDegreeLng = 111139.0 * cosLat;

    final bx = (b.longitude - a.longitude) * metersPerDegreeLng;
    final by = (b.latitude - a.latitude) * metersPerDegreeLat;

    final px = (p.longitude - a.longitude) * metersPerDegreeLng;
    final py = (p.latitude - a.latitude) * metersPerDegreeLat;

    final segLenSq = bx * bx + by * by;
    if (segLenSq < 1e-6) {
      // Degenerate segment: a and b are identical
      return a;
    }

    // Parametric t for projection along segment a->b: t = dot(p-a, b-a) / |b-a|^2
    final dot = px * bx + py * by;
    final t = (dot / segLenSq).clamp(0.0, 1.0);

    // Interpolate back to LatLng
    final projLat = a.latitude + t * (b.latitude - a.latitude);
    final projLng = a.longitude + t * (b.longitude - a.longitude);

    return LatLng(projLat, projLng);
  }
}

/// Tracks an off-route condition across multiple consecutive GPS fixes so
/// the navigation screen can ignore single-fix "spikes" but still react
/// to a sustained deviation.
///
/// Without this, GPS noise in Stone Town's narrow alleys can flip the
/// off-route flag on and off rapidly, causing the routing engine to be
/// hammered with redundant requests.
class OffRouteHysteresis {
  OffRouteHysteresis({
    this.thresholdMeters = 30.0,
    this.requiredSustained = const Duration(milliseconds: 1500),
  });

  /// Cross-track distance that must be exceeded to even consider an
  /// off-route event.
  final double thresholdMeters;

  /// How long the cross-track must be sustained above the threshold
  /// before the flag flips to `true`.
  final Duration requiredSustained;

  DateTime? _offRouteSince;

  /// Feed a new GPS fix. Returns `true` if the user is, in a sustained
  /// sense, off the route.
  bool onSample(PolylineProjectionResult projection) {
    final off = projection.distanceToPolylineMeters > thresholdMeters;
    if (!off) {
      _offRouteSince = null;
      return false;
    }
    _offRouteSince ??= DateTime.now();
    return DateTime.now().difference(_offRouteSince!) >= requiredSustained;
  }

  /// Reset the hysteresis state (e.g. after a successful reroute).
  void reset() {
    _offRouteSince = null;
  }
}
