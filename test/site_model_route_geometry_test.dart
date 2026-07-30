// Round-trip tests for `routeGeometry` and `routeGeometryUpdatedAt` on
// SiteModel. These cover the persistence layer of the route-cache
// feature: whatever we read from Firestore should survive a parse +
// re-serialise cycle without losing data.

import 'package:flutter_test/flutter_test.dart';
import 'package:stone_town_heritage_vt_guide/data/models/site_model.dart';

void main() {
  group('SiteModel route geometry', () {
    test('fromMap parses route_geometry and route_geometry_updated_at', () {
      final site = SiteModel.fromMap({
        'id': 'forodhani',
        'name_en': 'Forodhani Gardens',
        'name_sw': 'Bustani la Forodhani',
        'description_en': 'Waterfront park',
        'description_sw': 'Bustani ya pwani',
        'cloudinary_image_url': 'https://example.com/img.jpg',
        'latitude': -6.1619,
        'longitude': 39.1936,
        'route_geometry':
            '{"type":"Feature","geometry":{"type":"LineString",'
            '"coordinates":[[39.1936,-6.1619],[39.1940,-6.1620]]}}',
        'route_geometry_updated_at': '2026-07-11T10:30:00.000Z',
      });

      expect(site.routeGeometry, isNotNull);
      expect(site.routeGeometry, contains('LineString'));
      expect(site.routeGeometryUpdatedAt, isNotNull);
      expect(site.routeGeometryUpdatedAt!.year, 2026);
      expect(site.routeGeometryUpdatedAt!.month, 7);
      expect(site.routeGeometryUpdatedAt!.day, 11);
    });

    test('fromMap tolerates missing route geometry (older documents)', () {
      final site = SiteModel.fromMap({
        'id': 'old_fort',
        'name_en': 'Old Fort',
        'name_sw': 'Bomani la Kale',
        'description_en': 'Old fort',
        'description_sw': 'Bomani',
        'cloudinary_image_url': 'https://example.com/old.jpg',
        'latitude': -6.1620,
        'longitude': 39.1930,
      });

      expect(site.routeGeometry, isNull);
      expect(site.routeGeometryUpdatedAt, isNull);
    });

    test('toMap includes route geometry fields for Firestore write-back', () {
      final site = SiteModel(
        id: 'house_of_wonders',
        nameEn: 'House of Wonders',
        nameSw: 'Nyumba ya Ajabu',
        descriptionEn: 'Historic landmark',
        descriptionSw: 'Alama ya kihistoria',
        descriptionFr: '',
        descriptionDe: '',
        descriptionAr: '',
        descriptionIt: '',
        descriptionEs: '',
        cloudinaryImageUrl: 'https://example.com/how.jpg',
        latitude: -6.1625,
        longitude: 39.1925,
        routeGeometry: '{"type":"Feature"}',
        routeGeometryUpdatedAt: DateTime.utc(2026, 7, 11, 10, 30),
      );

      final map = site.toMap();
      expect(map['route_geometry'], '{"type":"Feature"}');
      expect(map['route_geometry_updated_at'], '2026-07-11T10:30:00.000Z');
    });

    test('copyWith updates route geometry fields', () {
      final original = SiteModel(
        id: 'a',
        nameEn: 'A',
        nameSw: 'A',
        descriptionEn: 'desc',
        descriptionSw: 'desc',
        descriptionFr: '',
        descriptionDe: '',
        descriptionAr: '',
        descriptionIt: '',
        descriptionEs: '',
        cloudinaryImageUrl: 'https://example.com/a.jpg',
        latitude: 0,
        longitude: 0,
      );
      final updated = original.copyWith(
        routeGeometry: '{"x":1}',
        routeGeometryUpdatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(updated.routeGeometry, '{"x":1}');
      expect(updated.routeGeometryUpdatedAt, DateTime.utc(2026, 1, 1));
      // Untouched fields still match the original.
      expect(updated.id, original.id);
      expect(updated.latitude, original.latitude);
    });
  });
}
