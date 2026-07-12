import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../models/site_model.dart';
import 'routing_service.dart' show RouteResult, RouteStep;

/// Persists `RouteResult` geometry and turn-steps to Firestore so that
/// repeat navigations to the same site skip OSRM and re-render from cache.
///
/// Why a separate service rather than storing on `FirestoreService`?
///
///   * The cache write is best-effort and fire-and-forget — calling code
///     can `unawaited(routeCache.save(...))` and move on. Keeping the
///     surface narrow avoids widening `FirestoreService`'s API for a
///     feature that only the routing layer cares about.
///   * Test harness can swap in a fake by passing a different
///     [RouteCacheService] at construction.
///
/// Wire format stored at `sites/{id}.route_geometry`:
///
///   {
///     "type": "Feature",
///     "geometry": { "type": "LineString", "coordinates": [[lng,lat],...] },
///     "properties": {
///       "distance": 12.5,
///       "duration": 35.0,
///       "provider": "osrmDemo",
///       "steps": [
///         {"maneuver":"depart","name":"...","distance":45.2,
///          "duration":32.0,
///          "start":[lng,lat],"end":[lng,lat],
///          "bearing_before":0,"bearing_after":270}
///       ]
///     }
///   }
abstract class RouteCacheService {
  Future<void> save(String siteId, RouteResult result);

  /// Loads a cached geometry. Returns null when nothing is stored, the
  /// stored payload is malformed, or it has exceeded
  /// [AppConstants.routeCacheMaxAgeDays].
  Future<RouteResult?> load(SiteModel site);
}

/// Production implementation backed by Firestore.
class FirestoreRouteCache implements RouteCacheService {

  FirestoreRouteCache({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference get _sites =>
      _firestore.collection(AppConstants.sitesCollection);

  @override
  Future<void> save(String siteId, RouteResult result) async {
    if (result.points.length < 2) return;
    try {
      final feature = <String, dynamic>{
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          // GeoJSON convention: [lng, lat].
          'coordinates': result.points
              .map((p) => [p.longitude, p.latitude])
              .toList(),
        },
        'properties': {
          'distance': result.distanceMeters,
          if (result.durationSeconds != null)
            'duration': result.durationSeconds,
          'provider': result.provider,
          'steps': result.steps.map(_encodeStep).toList(),
        },
      };
      await _sites.doc(siteId).update({
        'route_geometry': jsonEncode(feature),
        'route_geometry_updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort — a failed write just means the next navigation will
      // re-fetch from OSRM. Never let cache-write failures bubble up and
      // break navigation.
    }
  }

  @override
  Future<RouteResult?> load(SiteModel site) async {
    final raw = site.routeGeometry;
    if (raw == null || raw.isEmpty) return null;

    // Optional TTL check. Cache geometry older than this is treated as a
    // miss so admin-moved doorways don't keep pointing at the old road.
    final updatedAt = site.routeGeometryUpdatedAt;
    if (updatedAt != null) {
      final ageDays = DateTime.now().difference(updatedAt).inDays;
      if (ageDays >= AppConstants.routeCacheMaxAgeDays) return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final geometry = json['geometry'] as Map<String, dynamic>?;
      final coords = (geometry?['coordinates'] as List<dynamic>?) ?? const [];
      if (coords.isEmpty) return null;

      final points = coords.map<LatLng>((c) {
        final pair = c as List<dynamic>;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();

      final props = json['properties'] as Map<String, dynamic>?;
      final distance = (props?['distance'] as num?)?.toDouble() ??
          _polylineLengthMeters(points);
      final duration = (props?['duration'] as num?)?.toDouble();
      final provider = (props?['provider'] as String?) ?? 'cache';
      final rawSteps = (props?['steps'] as List<dynamic>?) ?? const [];
      final steps = rawSteps
          .map((s) => _decodeStep(s as Map<String, dynamic>))
          .whereType<RouteStep>()
          .toList();

      return RouteResult(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
        isFallback: false,
        provider: provider,
        steps: steps,
      );
    } catch (_) {
      // Malformed payload — treat as a cache miss.
      return null;
    }
  }
}

/// Sum of segment lengths — used as a fallback when cached payloads are
/// missing the engine-reported `distance` (e.g. payloads written before
/// the field was added). Cheap because Stone Town polylines have <500
/// vertices.
double _polylineLengthMeters(List<LatLng> pts) {
  if (pts.length < 2) return 0;
  const r = 6371000.0;
  double total = 0;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h = (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) *
            math.cos(lat2) *
            (1 - math.cos(dLng)) /
            2;
    total += 2 * r * math.asin(h.clamp(0.0, 1.0));
  }
  return total;
}

Map<String, dynamic> _encodeStep(RouteStep s) => {
      'maneuver': s.maneuver,
      'name': s.name,
      'distance': s.distanceMeters,
      if (s.durationSeconds != null) 'duration': s.durationSeconds,
      'start': [s.startLocation.longitude, s.startLocation.latitude],
      'end': [s.endLocation.longitude, s.endLocation.latitude],
      if (s.bearingBefore != null) 'bearing_before': s.bearingBefore,
      if (s.bearingAfter != null) 'bearing_after': s.bearingAfter,
    };

RouteStep? _decodeStep(Map<String, dynamic> s) {
  try {
    final start = (s['start'] as List).cast<num>();
    final end = (s['end'] as List).cast<num>();
    return RouteStep(
      maneuver: s['maneuver'] as String? ?? 'continue',
      name: s['name'] as String? ?? '',
      distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (s['duration'] as num?)?.toDouble(),
      startLocation: LatLng(start[1].toDouble(), start[0].toDouble()),
      endLocation: LatLng(end[1].toDouble(), end[0].toDouble()),
      bearingBefore: (s['bearing_before'] as num?)?.toInt(),
      bearingAfter: (s['bearing_after'] as num?)?.toInt(),
    );
  } catch (_) {
    return null;
  }
}
