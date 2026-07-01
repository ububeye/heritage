import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/navigation_state.dart';
import '../../data/services/location_service.dart';
import '../../core/utils/distance_calculator.dart';
import 'navigation_state.dart';

class NavigationCubit extends Cubit<NavigationCubitState> {

  NavigationCubit({LocationService? locationService})
      : _locationService = locationService ?? LocationService(),
        super(const NavigationCubitState());
  final LocationService _locationService;
  StreamSubscription<Position>? _positionSubscription;

  double? _siteLat;
  double? _siteLng;
  double _entryRadiusM = 30.0;
  bool _hasArrived = false;

  Future<void> startNavigation({
    required String siteId,
    required double siteLat,
    required double siteLng,
    double entryRadiusM = 30.0,
  }) async {
    _siteLat = siteLat;
    _siteLng = siteLng;
    _entryRadiusM = entryRadiusM;
    _hasArrived = false;

    emit(state.copyWith(
      currentSiteId: siteId,
      isNavigating: true,
      navigationState: const NavigationState(status: NavigationStatus.navigating),
    ),);

    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      emit(state.copyWith(
        navigationState: state.navigationState.copyWith(
          status: NavigationStatus.error,
          errorMessage: 'Location permission required',
        ),
      ),);
      return;
    }

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      _updatePosition(position);
    }

    _locationService.startListening(distanceFilter: 5);
    _positionSubscription = _locationService.positionStream.listen((position) {
      _updatePosition(position);
    });
  }

  void _updatePosition(Position position) {
    if (_siteLat == null || _siteLng == null) return;

    final distance = DistanceCalculator.calculateDistance(
      position.latitude,
      position.longitude,
      _siteLat!,
      _siteLng!,
    );

    final eta = DistanceCalculator.estimateWalkingTime(distance);

    final hasArrived = distance <= _entryRadiusM;

    if (hasArrived && !_hasArrived) {
      _hasArrived = true;
      emit(state.copyWith(
        navigationState: NavigationState(
          status: NavigationStatus.arrived,
          currentPosition: position,
          distanceToSite: distance,
          estimatedTime: eta,
          hasArrived: true,
        ),
      ),);
    } else {
      emit(state.copyWith(
        navigationState: NavigationState(
          status: NavigationStatus.navigating,
          currentPosition: position,
          distanceToSite: distance,
          estimatedTime: eta,
          hasArrived: false,
        ),
      ),);
    }
  }

  void stopNavigation() {
    _locationService.stopListening();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _siteLat = null;
    _siteLng = null;
    _hasArrived = false;

    emit(const NavigationCubitState());
  }

  @override
  Future<void> close() {
    stopNavigation();
    return super.close();
  }
}