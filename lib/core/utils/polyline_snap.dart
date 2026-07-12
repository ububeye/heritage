import 'package:latlong2/latlong.dart';

/// Snap a coordinate to the closest vertex on a polyline.
///
/// Used by the navigation screen to place the destination marker exactly
/// on the road-walking path rather than at the raw doorway coordinate
/// (which is often a couple of metres off the road in Stone Town's
/// narrow alleys).
///
/// The math is squared-euclidean distance on (lat, lng) — fine at the
/// scale of a heritage peninsula (≈1.5 km). Skipping the `sqrt` and the
/// haversine conversion keeps the hot-path cheap; the visible error is
/// well under a pixel at zoom 17+ when the camera is centred anywhere
/// within Stone Town.
class PolylineSnap {
  PolylineSnap._();

  /// Returns the polyline vertex nearest to [point]. If [polyline] is
  /// empty, returns [point] unchanged so callers never have to guard
  /// against null.
  static LatLng snapToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return point;
    LatLng best = polyline.first;
    double bestSq = _sqDist(best, point);
    for (var i = 1; i < polyline.length; i++) {
      final candidate = polyline[i];
      final sq = _sqDist(candidate, point);
      if (sq < bestSq) {
        bestSq = sq;
        best = candidate;
      }
    }
    return best;
  }

  static double _sqDist(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }
}
