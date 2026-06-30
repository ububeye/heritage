import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result of a routing request.
class RouteResult {
  /// Ordered list of coordinates forming the route polyline.
  final List<LatLng> points;

  /// Total route distance in meters (engine-reported when available,
  /// otherwise a great-circle fallback).
  final double distanceMeters;

  /// Estimated travel duration in seconds (if provided by the engine).
  final double? durationSeconds;

  /// True when the engine returned no usable geometry and we fell back to
  /// a straight line between origin and destination.
  final bool isFallback;

  /// Optional human-readable error from the upstream engine (success path
  /// has this as null).
  final String? errorMessage;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    this.durationSeconds,
    this.isFallback = false,
    this.errorMessage,
  });

  static RouteResult fallback({
    required LatLng from,
    required LatLng to,
    required double distanceMeters,
    String? errorMessage,
  }) {
    return RouteResult(
      points: [from, to],
      distanceMeters: distanceMeters,
      isFallback: true,
      errorMessage: errorMessage,
    );
  }
}

/// Open-source routing client.
///
/// Defaults to the public **OSRM demo** endpoint (`router.project-osrm.org`),
/// which is FOSS, requires no API key, and supports the `foot` profile — a
/// good fit for walking tourists in Stone Town. If the demo is unreachable
/// (or returns no usable geometry), the service silently degrades to a
/// straight-line polyline so the navigation screen keeps working.
///
/// For production, self-host OSRM, GraphHopper, or Valhalla and swap
/// [_baseUrl] / [_profile].
class RoutingService {
  /// Public OSRM demo. Free for low-volume demos — please self-host for
  /// production. See https://project-osrm.org/ for the usage policy.
  static const String _baseUrl = 'https://router.project-osrm.org';
  static const String _profile = 'foot';

  final http.Client _client;
  final Duration timeout;

  RoutingService({http.Client? client, this.timeout = const Duration(seconds: 6)})
      : _client = client ?? http.Client();

  /// Fetch a walking route from [from] to [to].
  ///
  /// On any network / parse error, returns a [RouteResult.fallback] with
  /// just the two endpoints joined by a straight line. Callers should
  /// treat [RouteResult.isFallback] as informational.
  Future<RouteResult> getRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    // Haversine straight-line distance — used as the fallback baseline and
    // also as a sanity check when the engine returns no geometry.
    final straightLineMeters = _haversineMeters(from, to);

    final uri = Uri.parse(
      '$_baseUrl/route/v1/$_profile/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=false',
    );

    try {
      final resp = await _client.get(uri).timeout(timeout);
      if (resp.statusCode != 200) {
        return RouteResult.fallback(
          from: from,
          to: to,
          distanceMeters: straightLineMeters,
          errorMessage: 'HTTP ${resp.statusCode}',
        );
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') {
        return RouteResult.fallback(
          from: from,
          to: to,
          distanceMeters: straightLineMeters,
          errorMessage: body['code']?.toString(),
        );
      }

      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return RouteResult.fallback(
          from: from,
          to: to,
          distanceMeters: straightLineMeters,
          errorMessage: 'No routes returned',
        );
      }

      final first = routes.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final coords = (geometry?['coordinates'] as List<dynamic>?) ?? const [];

      if (coords.isEmpty) {
        return RouteResult.fallback(
          from: from,
          to: to,
          distanceMeters: straightLineMeters,
          errorMessage: 'Empty geometry',
        );
      }

      final points = coords.map<LatLng>((c) {
        final pair = c as List<dynamic>;
        // GeoJSON convention is [lng, lat]; latlong2 wants LatLng(lat, lng).
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();

      final engineDistance = (first['distance'] as num?)?.toDouble();
      final engineDuration = (first['duration'] as num?)?.toDouble();

      return RouteResult(
        points: points,
        distanceMeters: engineDistance ?? straightLineMeters,
        durationSeconds: engineDuration,
        isFallback: false,
      );
    } on TimeoutException {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        errorMessage: 'Timeout',
      );
    } catch (e) {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        errorMessage: e.toString(),
      );
    }
  }

  /// Great-circle distance between two coordinates, in meters. Used as the
  /// fallback baseline and as a sanity check on the engine response.
  static double _haversineMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLng)) / 2;
    return 2 * earthRadius * math.asin(h.clamp(0.0, 1.0));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  void dispose() {
    _client.close();
  }
}
