import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/utils/distance_calculator.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      // Permissions denied / GPS off / timeout all surface as null here.
      // The cubit picks up null and falls back to the Stone Town centre.
      return null;
    }
  }

  void startListening({int distanceFilter = 5}) {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      (position) {
        _positionController.add(position);
      },
      onError: (error, stackTrace) {
        // Surface GPS errors through the broadcast stream so the cubit can
        // show a visible error state instead of silently swallowing them.
        _positionController.addError(error, stackTrace);
      },
    );
  }

  void stopListening() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return DistanceCalculator.calculateDistance(
      startLat,
      startLng,
      endLat,
      endLng,
    );
  }

  bool isWithinRadius(
    double userLat,
    double userLng,
    double siteLat,
    double siteLng,
    double radiusMeters,
  ) {
    return DistanceCalculator.isWithinRadius(
      userLat,
      userLng,
      siteLat,
      siteLng,
      radiusMeters,
    );
  }

  String formatDistance(double meters) {
    return DistanceCalculator.formatDistance(meters);
  }

  Duration estimateWalkingTime(double distanceMeters) {
    return DistanceCalculator.estimateWalkingTime(distanceMeters);
  }

  void dispose() {
    stopListening();
    _positionController.close();
  }
}
