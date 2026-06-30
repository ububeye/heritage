import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';

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

  /// Which provider actually produced this result. Useful in logs and in
  /// the on-screen banner to tell the user *why* a fallback is showing.
  final String provider;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    this.durationSeconds,
    this.isFallback = false,
    this.errorMessage,
    this.provider = 'none',
  });

  static RouteResult fallback({
    required LatLng from,
    required LatLng to,
    required double distanceMeters,
    required String provider,
    String? errorMessage,
  }) {
    return RouteResult(
      points: [from, to],
      distanceMeters: distanceMeters,
      isFallback: true,
      errorMessage: errorMessage,
      provider: provider,
    );
  }
}

/// Which routing engine served the [RouteResult].
///
/// The service tries OpenRouteService first (when an API key is supplied),
/// then falls back to the public OSRM demo. Both are open source / free
/// tier; no billing account required for the demo.
enum _RoutingProvider {
  /// POST to `ORS_BASE_URL` with a GeoJSON body. Requires an API key.
  openRouteService,

  /// GET `OSRM_BASE_URL` with `foot` profile. No auth required.
  osrmDemo,
}

/// Routing request lifecycle:
///
///   1. Check the 30-minute in-memory cache → short-circuit if warm.
///   2. Try the highest-priority provider that this build supports
///      (ORS if a key was supplied, else OSRM directly).
///   3. On any error, drop to the next provider.
///   4. Return a [RouteResult.fallback] only when *every* provider failed.
///
/// Both providers return GeoJSON LineString geometry of the same shape,
/// so a single parser handles both responses.
class RoutingService {
  final http.Client _client;
  final Duration timeout;

  /// 30-minute TTL on successful routes. Re-asking for the same
  /// `(from, to)` tuple reuses the cached [RouteResult] without
  /// contacting the network — critical when the user re-enters the
  /// navigation screen or moves a few metres and the polyline is
  /// refetched.
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// In-memory cache. LatLngs are rounded to 5 decimals (~1.1 m at the
  /// equator) so micro-GPS jitter doesn't bust the entry.
  final Map<String, _CacheEntry> _cache = {};

  RoutingService({
    http.Client? client,
    this.timeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client();

  /// Fetch a walking route from [from] to [to].
  ///
  /// On any network / parse error, returns a [RouteResult.fallback] with
  /// just the two endpoints joined by a straight line. Callers should
  /// treat [RouteResult.isFallback] as informational.
  Future<RouteResult> getRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    // 1. Cached path.
    final cacheKey = _cacheKey(from, to);
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.result;
    }

    final straightLineMeters = _haversineMeters(from, to);

    // 2. Provider chain. We try ORS first only when a key is configured —
    // otherwise the public endpoint will reject every request and we'd
    // burn the timeout twice for nothing.
    final providers = AppConstants.orsApiKey.isNotEmpty
        ? const [_RoutingProvider.openRouteService, _RoutingProvider.osrmDemo]
        : const [_RoutingProvider.osrmDemo];

    Object? lastError;
    for (final provider in providers) {
      try {
        final result = await _dispatch(provider, from, to);
        if (!result.isFallback) {
          // 3a. Sanity-clip the polyline. Engines sometimes return
          // long-distance geometry on bad inputs; the navigation screen
          // would render a transcontinental line. Treat anything longer
          // than [maxRouteDistanceMeters] as a fallback.
          final distance = result.distanceMeters;
          if (distance > AppConstants.maxRouteDistanceMeters) {
            final clipped = RouteResult.fallback(
              from: from,
              to: to,
              distanceMeters: straightLineMeters,
              provider: result.provider,
              errorMessage:
                  'Route too long (${distance.round()} m), clipped to direct line',
            );
            _cache[cacheKey] = _CacheEntry(clipped, DateTime.now());
            return clipped;
          }

          _cache[cacheKey] = _CacheEntry(result, DateTime.now());
          return result;
        }
        lastError = result.errorMessage;
      } on TimeoutException catch (e) {
        lastError = 'Timeout: $e';
      } catch (e) {
        lastError = e.toString();
      }
    }

    // 4. Every provider failed — straight line.
    return RouteResult.fallback(
      from: from,
      to: to,
      distanceMeters: straightLineMeters,
      provider: 'none',
      errorMessage: lastError?.toString() ?? 'No provider responded',
    );
  }

  /// Dispatch to the underlying provider and normalise the response into
  /// a [RouteResult].
  Future<RouteResult> _dispatch(
    _RoutingProvider provider,
    LatLng from,
    LatLng to,
  ) async {
    switch (provider) {
      case _RoutingProvider.openRouteService:
        return _routeFromORS(from, to);
      case _RoutingProvider.osrmDemo:
        return _routeFromOSRM(from, to);
    }
  }

  /// OpenRouteService — `POST {baseUrl}` with a GeoJSON `LineString`
  /// body, GeoJSON `FeatureCollection` response.
  ///
  /// Shape of the response we care about:
  ///
  ///   {
  ///     "type": "FeatureCollection",
  ///     "features": [
  ///       { "type": "Feature",
  ///         "geometry": { "type": "LineString",
  ///                       "coordinates": [[lng,lat], ...] },
  ///         "properties": { "summary": { "distance": m, "duration": s },
  ///                          "segments": [...] } }
  ///     ]
  ///   }
  Future<RouteResult> _routeFromORS(LatLng from, LatLng to) async {
    final straightLineMeters = _haversineMeters(from, to);
    final body = jsonEncode({
      'coordinates': [
        [from.longitude, from.latitude],
        [to.longitude, to.latitude],
      ],
    });

    final resp = await _client
        .post(
          Uri.parse(AppConstants.orsBaseUrl),
          headers: {
            'Authorization': AppConstants.orsApiKey,
            'Content-Type': 'application/json',
            'Accept':
                'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
          },
          body: body,
        )
        .timeout(timeout);

    if (resp.statusCode != 200) {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        provider: 'openRouteService',
        errorMessage: 'HTTP ${resp.statusCode}',
      );
    }

    return _parseGeoJson(
      from: from,
      to: to,
      straightLineMeters: straightLineMeters,
      body: resp.body,
      provider: 'openRouteService',
    );
  }

  /// Public OSRM demo — `GET {baseUrl}/route/v1/{profile}/{a};{b}` with
  /// `radiuses=25;25` to cap the "snap-to-nearest-road" search to 25 m.
  /// This is the parameter that closes the cross-country routing bug —
  /// without it, OSRM will happily jump to a motorway thousands of
  /// kilometres away when the supplied origin is unresolvable.
  Future<RouteResult> _routeFromOSRM(LatLng from, LatLng to) async {
    final straightLineMeters = _haversineMeters(from, to);

    final uri = Uri.parse(
      '${AppConstants.osrmBaseUrl}/route/v1/foot/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=false&radiuses=25;25',
    );

    final resp = await _client.get(uri).timeout(timeout);
    if (resp.statusCode != 200) {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        provider: 'osrmDemo',
        errorMessage: 'HTTP ${resp.statusCode}',
      );
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        provider: 'osrmDemo',
        errorMessage: body['code']?.toString(),
      );
    }

    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        provider: 'osrmDemo',
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
        provider: 'osrmDemo',
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
      provider: 'osrmDemo',
    );
  }

  /// Parse an ORS GeoJSON `FeatureCollection` (with a `LineString` feature)
  /// into a [RouteResult]. Used by the ORS path; kept shared because OSRM
  /// responses parse into the same shape after extraction.
  RouteResult _parseGeoJson({
    required LatLng from,
    required LatLng to,
    required double straightLineMeters,
    required String body,
    required String provider,
  }) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        return RouteResult.fallback(
          from: from,
          to: to,
          distanceMeters: straightLineMeters,
          provider: provider,
          errorMessage: 'No features returned',
        );
      }

      final first = features.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final coords = (geometry?['coordinates'] as List<dynamic>?) ?? const [];
      if (coords.isEmpty) {
        return RouteResult.fallback(
          from: from,
          to: to,
          distanceMeters: straightLineMeters,
          provider: provider,
          errorMessage: 'Empty geometry',
        );
      }

      final points = coords.map<LatLng>((c) {
        final pair = c as List<dynamic>;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();

      final props = first['properties'] as Map<String, dynamic>?;
      final summary = props?['summary'] as Map<String, dynamic>?;
      final engineDistance = (summary?['distance'] as num?)?.toDouble();
      final engineDuration = (summary?['duration'] as num?)?.toDouble();

      return RouteResult(
        points: points,
        distanceMeters: engineDistance ?? straightLineMeters,
        durationSeconds: engineDuration,
        isFallback: false,
        provider: provider,
      );
    } catch (e) {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        provider: provider,
        errorMessage: 'Parse error: $e',
      );
    }
  }

  /// Cache key — quantised coords. Quantising the lat/lng to 5 decimals
  /// (~1.1 m precision) means a GPS jitter of a few metres doesn't bust
  /// the cache, which keeps the same route warm while the user walks.
  ///
  /// Note: the helper must be invoked *outside* string interpolation —
  /// `'$q(x)'` would interpolate the closure's `toString`, not the
  /// result of calling it.
  String _cacheKey(LatLng from, LatLng to) {
    String q(double d) => d.toStringAsFixed(5);
    final fromPart = '${q(from.latitude)},${q(from.longitude)}';
    final toPart = '${q(to.latitude)},${q(to.longitude)}';
    return '$fromPart|$toPart';
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

class _CacheEntry {
  final RouteResult result;
  final DateTime at;
  _CacheEntry(this.result, this.at);
}
