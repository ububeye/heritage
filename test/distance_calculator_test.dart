import 'package:flutter_test/flutter_test.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/distance_calculator.dart';

void main() {
  group('DistanceCalculator', () {
    test('calculateDistance should return roughly correct distance', () {
      // Coordinates of House of Wonders and Old Fort in Stone Town
      final lat1 = -6.1609;
      final lng1 = 39.1901;
      final lat2 = -6.1620;
      final lng2 = 39.1891;

      final distance = DistanceCalculator.calculateDistance(
        lat1,
        lng1,
        lat2,
        lng2,
      );
      // It should be around 160 meters
      expect(distance, greaterThan(100));
      expect(distance, lessThan(300));
    });

    test('formatDistance formats correctly', () {
      expect(DistanceCalculator.formatDistance(50), '50 m');
      expect(DistanceCalculator.formatDistance(1500), '1.5 km');
    });

    test('estimateWalkingTime uses roughly 1.4 m/s', () {
      final time = DistanceCalculator.estimateWalkingTime(140);
      // 140 meters / 1.4 m/s = 100 seconds = 1.6 minutes
      expect(time.inMinutes, 1);
    });
  });
}
