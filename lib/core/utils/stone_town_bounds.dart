import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';

/// Stone Town core bounding box and clamping utilities.
///
/// The app is **Stone Town only**. The map camera is clamped to a small box
/// around the UNESCO heritage peninsula and the routing service rejects any
/// origin or destination outside it. This file centralises the geography so
/// the constants are defined exactly once.
class StoneTownBounds {
  StoneTownBounds._();

  /// Centre of Stone Town — used as the fallback origin when the user's
  /// GPS hasn't fixed yet, and as the default `initialCenter` for the map.
  static const LatLng centre = LatLng(
    AppConstants.stoneTownCentreLat,
    AppConstants.stoneTownCentreLng,
  );

  /// The strict bounding box. The map camera is clamped to this rectangle;
  /// pan/zoom operations that try to escape it are snapped back inside.
  static LatLngBounds get cameraBounds => LatLngBounds(
    const LatLng(AppConstants.stoneTownMinLat, AppConstants.stoneTownMinLng),
    const LatLng(AppConstants.stoneTownMaxLat, AppConstants.stoneTownMaxLng),
  );

  /// True if [point] is inside the strict Stone Town box. Used by the
  /// routing service to reject up-front any request that lands outside
  /// the heritage area.
  static bool contains(LatLng point) {
    return point.latitude >= AppConstants.stoneTownMinLat &&
        point.latitude <= AppConstants.stoneTownMaxLat &&
        point.longitude >= AppConstants.stoneTownMinLng &&
        point.longitude <= AppConstants.stoneTownMaxLng;
  }

  /// Clamps [point] to the strict Stone Town box, returning the same
  /// `LatLng` if it is already inside. Used by widgets to defend against
  /// the small window between a user's GPS fix landing slightly outside
  /// the box (e.g. harbour edge) and the next fix landing inside.
  static LatLng clampPoint(LatLng point) {
    final bounds = cameraBounds;
    final lat = point.latitude.clamp(bounds.south, bounds.north).toDouble();
    final lng = point.longitude.clamp(bounds.west, bounds.east).toDouble();
    return LatLng(lat, lng);
  }
}
