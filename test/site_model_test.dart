import 'package:flutter_test/flutter_test.dart';
import 'package:stone_town_heritage_vt_guide/data/models/site_model.dart';

void main() {
  group('SiteModel', () {
    test('toMap and fromMap should be consistent', () {
      final site = SiteModel(
        id: '1',
        nameEn: 'Old Fort',
        nameSw: 'Ngome Kongwe',
        nameFr: 'Vieux Fort',
        nameDe: 'Alte Festung',
        nameAr: 'الحصن القديم',
        nameIt: 'Vecchio Forte',
        nameEs: 'Fuerte Viejo',
        descriptionEn: 'The oldest building in Stone Town.',
        descriptionSw: 'Jengo kongwe zaidi katika Mji Mkongwe.',
        descriptionFr: 'Le plus vieux bâtiment de Stone Town.',
        descriptionDe: 'Das älteste Gebäude in Stone Town.',
        descriptionAr: 'أقدم مبنى في المدينة الحجرية.',
        descriptionIt: 'L\'edificio più antico di Stone Town.',
        descriptionEs: 'El edificio más antiguo de Stone Town.',
        latitude: -6.162,
        longitude: 39.184,
        category: 'historic',
        cloudinaryImageUrl: '',
        imageUrls: const ['img1.jpg'],
        featured: true,
        address: 'Forodhani, Zanzibar',
      );

      final map = site.toMap();
      final fromMapSite = SiteModel.fromMap(map);

      expect(fromMapSite.id, site.id);
      expect(fromMapSite.nameEn, site.nameEn);
      expect(fromMapSite.latitude, site.latitude);
      expect(fromMapSite.imageUrls.first, 'img1.jpg');
      expect(fromMapSite.featured, true);
      expect(fromMapSite.address, 'Forodhani, Zanzibar');
    });

    test('getName and getDescription should return correct language', () {
      final site = SiteModel(
        id: '2',
        nameEn: 'Test Name EN',
        nameSw: 'Test Name SW',
        nameFr: 'Test Name FR',
        nameDe: 'Test Name DE',
        nameAr: 'Test Name AR',
        nameIt: 'Test Name IT',
        nameEs: 'Test Name ES',
        descriptionEn: 'Test Desc EN',
        descriptionSw: 'Test Desc SW',
        descriptionFr: 'Test Desc FR',
        descriptionDe: 'Test Desc DE',
        descriptionAr: 'Test Desc AR',
        descriptionIt: 'Test Desc IT',
        descriptionEs: 'Test Desc ES',
        latitude: 0.0,
        longitude: 0.0,
        cloudinaryImageUrl: '',
        imageUrls: const [],
      );

      expect(site.getName('en'), 'Test Name EN');
      expect(site.getName('sw'), 'Test Name SW');
      expect(site.getDescription('fr'), 'Test Desc FR');
      // Fallback
      expect(site.getName('unknown'), 'Test Name EN');
    });
  });
}
