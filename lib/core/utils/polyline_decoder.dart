import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Decode a Google-style encoded polyline string into a list of
/// [LatLng]. Standard 5-bit ASCII encoding with sign-bit twos-
/// complement deltas.
///
/// Spec: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
///
/// [precision] is the divisor for the integer values — Valhalla uses
/// 6 (1e-6 degree resolution), Google Maps uses 5. The default of 5
/// matches Google's spec.
///
/// Inlined to avoid pulling in `flutter_polyline_points` — the
/// algorithm is ~30 lines and the encoding is public-domain. Used by
/// [RoutingService] to decode Valhalla responses (which always return
/// encoded polylines, not GeoJSON).
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  final points = <LatLng>[];
  if (encoded.isEmpty) return points;
  int index = 0;
  int lat = 0;
  int lng = 0;
  final factor = math.pow(10, precision).toInt();
  while (index < encoded.length) {
    int shift = 0;
    int result = 0;
    int b;
    do {
      if (index >= encoded.length) break;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      if (index >= encoded.length) break;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}
