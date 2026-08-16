import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/stone_town_bounds.dart';
import '../../core/utils/unguja_bounds.dart';
import '../models/site_model.dart';
import 'route_cache_service.dart';
import 'runtime_config_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A single turn-by-turn instruction returned by the routing engine.
///
/// OSRM reports one [RouteStep] per "maneuver" — typically:
///   * `depart` (or `null` modifier) at the start of the route,
///   * `turn` modifiers: `left`/`right`/`straight`/`slight left`/...
///   * `new name`/`continue`/`fork`/`merge`/`roundabout`,
///   * `arrive` at the destination.
///
/// We persist this whole list to Firestore so cold starts don't have to
/// re-hit OSRM just to render instructions.
class RouteStep {
  const RouteStep({
    required this.maneuver,
    required this.name,
    required this.distanceMeters,
    required this.startLocation,
    required this.endLocation,
    this.durationSeconds,
    this.bearingBefore,
    this.bearingAfter,
  });
  final String maneuver;
  final String name;
  final double distanceMeters;
  final double? durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final int? bearingBefore;
  final int? bearingAfter;

  /// Map an OSRM maneuver string to the closest Flutter icon. This is the
  /// single source of truth for instruction iconography across the app.
  IconData get icon => ManeuverIcon.forManeuver(maneuver);

  /// Localized, human-readable summary of the step. [tr] is a lookup
  /// callback (typically `LocalizationCubit.translate`) that takes a
  /// translation key and returns the localized string. The previous
  /// `description` getter hardcoded English — Arabic users on this app
  /// saw mixed English/Arabic turn-by-turn, which the audit flagged.
  String localizedDescription(String Function(String key) tr) {
    final main = mainManeuver;
    final modifier = modifierManeuver;
    // Arrival is a special case — there is no next street to name.
    if (main == 'arrive') return tr('arrive_at_destination');

    final modifierKey = _modifierTranslationKey(main, modifier);
    final prettyModifier = modifierKey != null ? tr(modifierKey) : null;

    if (name.isNotEmpty) {
      return prettyModifier != null
          ? '$prettyModifier ${tr('onto')} $name'
          : '${tr('continue_on')} $name';
    }
    return prettyModifier ?? tr('continue_straight');
  }

  /// Main maneuver word (`'turn'`, `'arrive'`, `'fork'`, ...). Splits
  /// the OSRM maneuver string on the first space so the modifier (if
  /// any) lands in [modifierManeuver].
  String get mainManeuver {
    final parts = maneuver.split(' ');
    return parts.first;
  }

  /// Modifier token from the OSRM maneuver string (`'left'`,
  /// `'slight left'`, etc.), or null when the maneuver has no
  /// modifier. Multi-word modifiers are joined with a space, matching
  /// OSRM's spelling.
  String? get modifierManeuver {
    final parts = maneuver.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : null;
  }

  /// Map OSRM maneuver (main + modifier) to a translation key. The UI
  /// is responsible for fetching the localized string via [tr]; the
  /// service stays in English-free code paths so it can be unit-tested
  /// without a LocalizationCubit.
  static String? _modifierTranslationKey(String main, String? modifier) {
    if (main == 'depart') return null;
    if (main == 'arrive') return 'arrive_at_destination';
    if (main == 'fork') return 'at_the_fork';
    if (main == 'merge') return 'merge_ahead';
    if (main == 'roundabout' || main == 'rotary') {
      return 'enter_roundabout';
    }
    if (main == 'uturn' || modifier == 'uturn') return 'make_uturn';
    switch (modifier) {
      case 'left':
        return 'turn_left';
      case 'right':
        return 'turn_right';
      case 'slight left':
        return 'turn_slight_left';
      case 'slight right':
        return 'turn_slight_right';
      case 'sharp left':
        return 'turn_sharp_left';
      case 'sharp right':
        return 'turn_sharp_right';
      case 'straight':
        return 'continue_straight';
      default:
        // Unknown modifier — fall back to the raw OSRM text rather
        // than dumping the snake_case string into the UI.
        return null;
    }
  }
}

/// Single source of truth for "what icon represents an OSRM maneuver".
/// The mapping is forgiving — OSRM commonly emits modifiers we haven't
/// seen, so the default branch picks a reasonable directional icon from
/// the modifier text.
class ManeuverIcon {
  ManeuverIcon._();

  static IconData forManeuver(String maneuver) {
    final parts = maneuver.split(' ');
    final main = parts.first;
    // Modifier can be 1 or 2 words ("left" / "slight left" / "sharp right").
    // We pass both to the switch below so it can match multi-word modifiers
    // exactly.
    final mod1 = parts.length > 1 ? parts[1] : null;
    final mod2 = parts.length > 2 ? parts.sublist(1).join(' ') : null;

    // Special main-word cases first — these don't follow the
    // "modifier is the second word" pattern.
    if (main == 'depart') return PhosphorIconsRegular.play;
    if (main == 'arrive') return Icons.flag;
    if (main == 'fork') {
      return mod1 == 'left' ? Icons.fork_left : Icons.fork_right;
    }
    if (main == 'merge') return Icons.merge_type;
    if (main == 'roundabout' || main == 'rotary') {
      return Icons.roundabout_left;
    }
    if (main == 'uturn' || mod1 == 'uturn') {
      return Icons.u_turn_left;
    }

    // Prefer the two-word form when present, fall back to single-word.
    final modifier = mod2 ?? mod1;
    switch (modifier) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'slight left':
        return Icons.turn_slight_left;
      case 'slight right':
        return Icons.turn_slight_right;
      case 'sharp left':
        return Icons.turn_sharp_left;
      case 'sharp right':
        return Icons.turn_sharp_right;
      case 'straight':
        return Icons.straight;
      default:
        return Icons.straight;
    }
  }
}

/// Result of a routing request.
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    this.durationSeconds,
    this.isFallback = false,
    this.errorMessage,
    this.provider = 'none',
    this.steps = const [],
  });

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

  /// Ordered turn-by-turn instructions parsed from OSRM. Empty when the
  /// result is a fallback (no engine data).
  final List<RouteStep> steps;

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
///   0. Check the persistent Firestore cache (per-site) → bypass the
///      engine if a recent geometry is stored.
///   1. Check the 30-minute in-memory cache → short-circuit if warm.
///   2. Try the highest-priority provider that this build supports
///      (ORS if a key was supplied, else OSRM directly).
///   3. On any error, drop to the next provider.
///   4. Return a [RouteResult.fallback] only when *every* provider failed.
///
/// Both providers return GeoJSON LineString geometry of the same shape,
/// so a single parser handles both responses.
class RoutingService {
  RoutingService({
    http.Client? client,
    RouteCacheService? routeCache,
    this.timeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client(),
       _routeCache = routeCache;
  final http.Client _client;
  final RouteCacheService? _routeCache;
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

  /// Fetch a walking route from [from] to [to].
  ///
  /// On any network / parse error, returns a [RouteResult.fallback] with
  /// just the two endpoints joined by a straight line. Callers should
  /// treat [RouteResult.isFallback] as informational.
  ///
  /// Pass [site] to opt into the persistent route cache: a hit skips the
  /// network entirely and a successful engine response writes the
  /// geometry back to Firestore for future visits.
  Future<RouteResult> getRoute({
    required LatLng from,
    required LatLng to,
    SiteModel? site,
  }) async {
    // 0. Unguja only — reject anything outside the island up-front. We
    //    don't want to burn network requests or render a route to a
    //    place we don't cover. Routing is open to the whole island so a
    //    customer in Nungwi can plan a trip to Forodhani.
    if (!UngujaBounds.contains(to)) {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: _haversineMeters(from, to),
        provider: 'none',
        errorMessage: 'Destination is outside Zanzibar',
      );
    }
    if (!UngujaBounds.contains(from)) {
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: _haversineMeters(from, to),
        provider: 'none',
        errorMessage: 'Origin is outside Zanzibar',
      );
    }

    // 0a. Persistent cache hit — bypass both the in-memory cache and the
    //     network. Saves OSRM requests on repeat visits within the cache
    //     age window. The cache layer treats stale / malformed entries
    //     as a miss, so this branch is safe to attempt unconditionally.
    if (site != null && _routeCache != null) {
      final cached = await _routeCache.load(site);
      if (cached != null) {
        // Also warm the in-memory cache so the next refetch in the same
        // session skips the Firestore round-trip too.
        _cache[_cacheKey(from, to)] = _CacheEntry(cached, DateTime.now());
        return cached;
      }
    }

    // 1. Cached path.
    final cacheKey = _cacheKey(from, to);
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.result;
    }

    final straightLineMeters = _haversineMeters(from, to);

    // 2. Provider chain. We try ORS first only when a key is configured —
    // otherwise the public endpoint will reject every request and we'd
    // burn the timeout twice for nothing. The key is read fresh on each
    // call so admin-side runtime changes take effect on the next request
    // without recreating this service.
    final providers =
        RuntimeConfigService.instance.orsApiKey.isNotEmpty
            ? const [
              _RoutingProvider.openRouteService,
              _RoutingProvider.osrmDemo,
            ]
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

          // 3b. Best-effort write to Firestore. Fire-and-forget — a
          //     failed write just means the next cold start re-fetches.
          if (site != null && _routeCache != null) {
            unawaited(_routeCache.save(site.id, result));
          }
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
            'Authorization': RuntimeConfigService.instance.orsApiKey,
            'Content-Type': 'application/json',
            'Accept':
                'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
          },
          body: body,
        )
        .timeout(timeout);

    if (resp.statusCode != 200) {
      // Distinguish auth / config errors from transient engine errors
      // so the operator can see a useful message instead of the
      // generic "Routing offline" banner. The chain still falls
      // through to OSRM by design (the caller can override), but the
      // errorMessage now carries enough signal for the banner to
      // surface "check your ORS API key" specifically.
      final authFailure = resp.statusCode == 401 || resp.statusCode == 403;
      final errorMessage =
          authFailure
              ? 'routing_api_key_invalid' // localized key; UI swaps to text
              : 'HTTP ${resp.statusCode}';
      return RouteResult.fallback(
        from: from,
        to: to,
        distanceMeters: straightLineMeters,
        provider: 'openRouteService',
        errorMessage: errorMessage,
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

    // 1. Try with initial 25m radius constraint.
    var res = await _fetchOsrmUrl(
      '${AppConstants.osrmBaseUrl}/route/v1/foot/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson'
      '&steps=true&annotations=false'
      '&radiuses=25;25',
      from,
      to,
      straightLineMeters,
    );

    // 2. If 25m radius fails because a doorway/courtyard is slightly off-road,
    // retry with adaptive 60m radius before failing to a straight line.
    if (res.isFallback && res.errorMessage != null && res.errorMessage!.contains('NoSegment')) {
      final retryRes = await _fetchOsrmUrl(
        '${AppConstants.osrmBaseUrl}/route/v1/foot/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson'
        '&steps=true&annotations=false'
        '&radiuses=60;60',
        from,
        to,
        straightLineMeters,
      );
      if (!retryRes.isFallback) {
        return retryRes;
      }
    }

    return res;
  }

  Future<RouteResult> _fetchOsrmUrl(
    String url,
    LatLng from,
    LatLng to,
    double straightLineMeters,
  ) async {
    final uri = Uri.parse(url);
    final resp = await _client
        .get(
          uri,
          headers: const {
            'User-Agent':
                'com.example.stone_town_heritage_vt_guide/1.0 (Flutter)',
          },
        )
        .timeout(timeout);
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

    final points =
        coords.map<LatLng>((c) {
          final pair = c as List<dynamic>;
          // GeoJSON convention is [lng, lat]; latlong2 wants LatLng(lat, lng).
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        }).toList();

    final engineDistance = (first['distance'] as num?)?.toDouble();
    final engineDuration = (first['duration'] as num?)?.toDouble();
    final steps = _parseOsrmSteps(first);

    return RouteResult(
      points: points,
      distanceMeters: engineDistance ?? straightLineMeters,
      durationSeconds: engineDuration,
      isFallback: false,
      provider: 'osrmDemo',
      steps: steps,
    );
  }

  /// Parse `routes[0].legs[0].steps[]` into a list of [RouteStep]s.
  ///
  /// OSRM structure (with `steps=true`):
  ///
  ///   {
  ///     "routes": [{
  ///       "legs": [{
  ///         "steps": [{
  ///           "maneuver": { "type": "turn", "modifier": "left",
  ///                         "bearing_before": 180, "bearing_after": 90,
  ///                         "location": [lng, lat] },
  ///           "name": "Kenyatta Rd",
  ///           "distance": 142.7,
  ///           "duration": 102.0,
  ///           "geometry": { "coordinates": [[lng,lat],...] }
  ///         }, ...]
  ///       }]
  ///     }]
  ///   }
  ///
  /// We collapse each step's geometry into a single (start, end) pair —
  /// we don't render sub-step polylines, only the step-level "next
  /// maneuver" instruction, so a 50-vertex array isn't worth retaining
  /// for memory.
  static List<RouteStep> _parseOsrmSteps(Map<String, dynamic> route) {
    try {
      final legs = route['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) return const [];
      final leg = legs.first as Map<String, dynamic>;
      final rawSteps = (leg['steps'] as List<dynamic>?) ?? const [];
      final result = <RouteStep>[];
      for (final s in rawSteps) {
        final step = s as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        final type = maneuver?['type'] as String? ?? 'continue';
        final modifier = maneuver?['modifier'] as String?;
        final maneuverString =
            modifier != null && modifier.isNotEmpty ? '$type $modifier' : type;
        final name = step['name'] as String? ?? '';
        final distance = (step['distance'] as num?)?.toDouble() ?? 0;
        final duration = (step['duration'] as num?)?.toDouble();
        final loc = maneuver?['location'] as List<dynamic>?;
        final startLatLng =
            (loc != null && loc.length >= 2)
                ? LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble())
                : LatLng(0, 0);
        // The end of step N is the start of step N+1, by construction.
        // For the last step we approximate with the same start location —
        // exact arrival coords aren't needed for instruction rendering.
        result.add(
          RouteStep(
            maneuver: maneuverString,
            name: name,
            distanceMeters: distance,
            durationSeconds: duration,
            startLocation: startLatLng,
            endLocation: startLatLng, // populated below in a second pass
            bearingBefore: (maneuver?['bearing_before'] as num?)?.toInt(),
            bearingAfter: (maneuver?['bearing_after'] as num?)?.toInt(),
          ),
        );
      }
      // Second pass: end of step N = start of step N+1.
      for (var i = 0; i < result.length - 1; i++) {
        result[i] = RouteStep(
          maneuver: result[i].maneuver,
          name: result[i].name,
          distanceMeters: result[i].distanceMeters,
          durationSeconds: result[i].durationSeconds,
          startLocation: result[i].startLocation,
          endLocation: result[i + 1].startLocation,
          bearingBefore: result[i].bearingBefore,
          bearingAfter: result[i].bearingAfter,
        );
      }
      return result;
    } catch (_) {
      // A malformed step list shouldn't take down the whole route — fall
      // back to "no turn instructions" mode.
      return const [];
    }
  }

  /// Returns the index of the [RouteStep] the user is currently on,
  /// based on which step's [RouteStep.endLocation] is closest to
  /// [userPos].
  ///
  /// Strategy: pick the step whose start is the *closest* point on the
  /// route to the user. The step's [RouteStep.endLocation] is where the
  /// next maneuver happens; the user is "on" whichever step that
  /// maneuver belongs to.
  ///
  /// O(n) scan — Stone Town routes have <20 steps total.
  static int currentStepIndex(List<RouteStep> steps, LatLng userPos) {
    if (steps.isEmpty) return 0;
    int bestIdx = 0;
    double bestDist = _sqDist(steps.first.startLocation, userPos);
    for (var i = 1; i < steps.length; i++) {
      final d = _sqDist(steps[i].startLocation, userPos);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Squared euclidean distance between two coordinates. Skipping the
  /// `sqrt` is fine because we only compare magnitudes to find the
  /// minimum — close enough at Stone Town latitudes.
  static double _sqDist(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
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

      final points =
          coords.map<LatLng>((c) {
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
    final h =
        (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLng)) / 2;
    return 2 * earthRadius * math.asin(h.clamp(0.0, 1.0));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  void dispose() {
    _client.close();
  }
}

class _CacheEntry {
  _CacheEntry(this.result, this.at);
  final RouteResult result;
  final DateTime at;
}
