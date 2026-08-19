// Unit tests for [RouteCacheService].
//
// These tests pin the origin-policy semantics that keep a stale
// centre-origin route from being resurrected on a subsequent session
// and presented as if it started from the user's actual position. The
// bug surfaced as a polyline visibly starting far from the user's dot:
// the Firestore cache returned a route originally fetched when the
// user's GPS was wildly outside the box (routed from the island
// centre), and the loader hardcoded `isFallback: false` so the UI
// treated it as a real route.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/data/models/site_model.dart';
import 'package:stone_town_heritage_vt_guide/data/services/routing_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/route_cache_service.dart';

void main() {
  group('FirestoreRouteCache origin-policy round-trip', () {
    test(
      'round-trips originIsApproximate: false (default for old payloads)',
      () async {
        final cache = InMemoryRouteCache();
        final original = RouteResult(
          points: const [
            LatLng(-6.162, 39.190),
            LatLng(-6.165, 39.195),
          ],
          distanceMeters: 432.0,
          durationSeconds: 311.0,
          provider: 'osrmDemo',
          originIsApproximate: false,
        );
        await cache.save('siteA', original);
        final loaded = await cache.load(_site('siteA'));
        expect(loaded, isNotNull);
        expect(loaded!.originIsApproximate, isFalse);
      },
    );

    test(
      'rejects an approximate-origin entry on load (returns null)',
      () async {
        final cache = InMemoryRouteCache();
        // This route was originally fetched when the user's GPS was
        // wildly outside the box. The service routed from the island
        // centre and tagged the result with originIsApproximate.
        // Persisting that flag means a future session can refuse to
        // resurrect it — the polyline would visibly start far from
        // the user's dot.
        final centreOrigin = RouteResult(
          points: const [
            LatLng(-6.30, 39.30), // UngujaBounds.centre
            LatLng(-6.165, 39.195),
          ],
          distanceMeters: 18000.0,
          provider: 'osrmDemo',
          originIsApproximate: true,
        );
        await cache.save('siteA', centreOrigin);
        final loaded = await cache.load(_site('siteA'));
        expect(
          loaded,
          isNull,
          reason:
              'approximate-origin entries must be rejected so the '
              'caller re-fetches from OSRM with the real GPS position',
        );
      },
    );
  });
}

// ─────────────────────────── helpers ───────────────────────────

/// In-memory [RouteCacheService] used by these tests. The production
/// `FirestoreRouteCache` writes to a real Firestore backend, which the
/// unit test runner doesn't have. Mirroring the wire format in a
/// [String] keeps the test fully synthetic.
class InMemoryRouteCache implements RouteCacheService {
  final Map<String, String> _store = {};

  @override
  Future<void> save(String siteId, RouteResult result) async {
    final feature = <String, dynamic>{
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates':
            result.points.map((p) => [p.longitude, p.latitude]).toList(),
      },
      'properties': {
        'distance': result.distanceMeters,
        if (result.durationSeconds != null)
          'duration': result.durationSeconds,
        'provider': result.provider,
        'origin_is_approximate': result.originIsApproximate,
        'steps': const <dynamic>[],
      },
    };
    _store[siteId] = jsonEncode(feature);
  }

  @override
  Future<RouteResult?> load(SiteModel site) async {
    final raw = _store[site.id];
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final geometry = json['geometry'] as Map<String, dynamic>?;
      final coords = (geometry?['coordinates'] as List<dynamic>?) ?? const [];
      if (coords.isEmpty) return null;
      final points =
          coords.map<LatLng>((c) {
            final pair = c as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          }).toList();
      final props = json['properties'] as Map<String, dynamic>?;
      final originIsApproximate =
          (props?['origin_is_approximate'] as bool?) ?? false;
      if (originIsApproximate) return null;
      return RouteResult(
        points: points,
        distanceMeters: (props?['distance'] as num?)?.toDouble() ?? 0.0,
        durationSeconds: (props?['duration'] as num?)?.toDouble(),
        isFallback: false,
        provider: (props?['provider'] as String?) ?? 'cache',
        originIsApproximate: false,
      );
    } catch (_) {
      return null;
    }
  }
}

SiteModel _site(String id) => SiteModel(
  id: id,
  nameEn: 'Test',
  nameSw: 'Mtihani',
  descriptionEn: 'Test description',
  descriptionSw: 'Maelezo ya mtihani',
  descriptionFr: 'Description de test',
  descriptionDe: 'Testbeschreibung',
  descriptionAr: 'وصف الاختبار',
  descriptionIt: 'Descrizione di prova',
  descriptionEs: 'Descripción de prueba',
  cloudinaryImageUrl: 'https://example.com/test.jpg',
  latitude: -6.165,
  longitude: 39.195,
  category: 'historic',
);
