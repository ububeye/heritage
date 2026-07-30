import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class DistanceCalculator {
  DistanceCalculator._();

  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  static String formatDistance(double meters, {bool isImperial = false}) {
    if (isImperial) {
      final feet = meters * 3.28084;
      if (feet < 1000) {
        return '${feet.round()} ft';
      } else {
        final miles = feet / 5280;
        return '${miles.toStringAsFixed(1)} mi';
      }
    } else {
      if (meters < 1000) {
        return '${meters.round()} m';
      } else {
        final km = meters / 1000;
        return '${km.toStringAsFixed(1)} km';
      }
    }
  }

  static String formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '< 1 min';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} min';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
  }

  static Duration estimateWalkingTime(double distanceMeters) {
    const walkingSpeedMps = 1.4; // ~5 km/h
    final seconds = (distanceMeters / walkingSpeedMps).round();
    return Duration(seconds: seconds);
  }

  static bool isWithinRadius(
    double userLat,
    double userLng,
    double siteLat,
    double siteLng,
    double radiusMeters,
  ) {
    final distance = calculateDistance(userLat, userLng, siteLat, siteLng);
    return distance <= radiusMeters;
  }

  static double calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final lat1 = _toRadians(startLat);
    final lat2 = _toRadians(endLat);
    final dLng = _toRadians(endLng - startLng);

    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final bearing = math.atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
  static double _toDegrees(double radians) => radians * 180 / math.pi;

  static Position calculateIntermediatePoint(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
    double fraction,
  ) {
    final lat1 = _toRadians(startLat);
    final lng1 = _toRadians(startLng);
    final lat2 = _toRadians(endLat);
    final lng2 = _toRadians(endLng);

    final d = calculateDistance(startLat, startLng, endLat, endLng);
    final A = math.sin((1 - fraction) * d / 6371000) / math.sin(d / 6371000);
    final B = math.sin(fraction * d / 6371000) / math.sin(d / 6371000);

    final x =
        A * math.cos(lat1) * math.cos(lng1) +
        B * math.cos(lat2) * math.cos(lng2);
    final y =
        A * math.cos(lat1) * math.sin(lng1) +
        B * math.cos(lat2) * math.sin(lng2);
    final z = A * math.sin(lat1) + B * math.sin(lat2);

    final lat = math.atan2(z, math.sqrt(x * x + y * y));
    final lng = math.atan2(y, x);

    return Position(
      latitude: _toDegrees(lat),
      longitude: _toDegrees(lng),
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
