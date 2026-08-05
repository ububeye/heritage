import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';

/// Unguja (Zanzibar main island) bounding box and clamping utilities.
///
/// The map viewport and routing validation are open to the whole island
/// so a customer in Nungwi can plan a route to Forodhani, and so the
/// map can pan/zoom across the whole island. Heritage sites themselves
/// remain inside the tighter [StoneTownBounds] cluster.
class UngujaBounds {
  UngujaBounds._();

  /// Centre of Unguja — used as the fallback origin when the user's GPS
  /// hasn't fixed yet, and as the default `initialCenter` for the map.
  static const LatLng centre = LatLng(
    AppConstants.ungujaCentreLat,
    AppConstants.ungujaCentreLng,
  );

  /// The island bounding box. The map camera is clamped to this rectangle;
  /// pan/zoom operations that try to escape it are snapped back inside.
  static LatLngBounds get cameraBounds => LatLngBounds(
    const LatLng(AppConstants.ungujaMinLat, AppConstants.ungujaMinLng),
    const LatLng(AppConstants.ungujaMaxLat, AppConstants.ungujaMaxLng),
  );

  /// True if [point] is inside the Unguja box.
  static bool contains(LatLng point) {
    return point.latitude >= AppConstants.ungujaMinLat &&
        point.latitude <= AppConstants.ungujaMaxLat &&
        point.longitude >= AppConstants.ungujaMinLng &&
        point.longitude <= AppConstants.ungujaMaxLng;
  }

  /// Clamps [point] to the Unguja box, returning the same `LatLng` if it
  /// is already inside.
  static LatLng clampPoint(LatLng point) {
    final bounds = cameraBounds;
    final lat = point.latitude.clamp(bounds.south, bounds.north).toDouble();
    final lng = point.longitude.clamp(bounds.west, bounds.east).toDouble();
    return LatLng(lat, lng);
  }
}
