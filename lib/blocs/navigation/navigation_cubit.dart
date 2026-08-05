import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../../data/models/navigation_state.dart';
import '../../data/services/location_service.dart';
import '../../core/utils/distance_calculator.dart' as dc;
import '../../core/utils/stone_town_bounds.dart';
import '../../core/utils/unguja_bounds.dart';
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

  /// Monotonically increasing navigation id. A new `startNavigation` call
  /// bumps this so the screen can discard stale GPS / route updates from
  /// a previous session.
  int _sessionId = 0;

  Future<void> startNavigation({
    required String siteId,
    required double siteLat,
    required double siteLng,
    double entryRadiusM = 30.0,
  }) async {
    // 1. Tear down the previous session cleanly before starting a new one.
    _sessionId += 1;
    final mySession = _sessionId;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _hasArrived = false;

    _siteLat = siteLat;
    _siteLng = siteLng;
    _entryRadiusM = entryRadiusM;

    emit(
      state.copyWith(
        currentSiteId: siteId,
        isNavigating: true,
        navigationState: const NavigationState(
          status: NavigationStatus.navigating,
        ),
      ),
    );

    // 2. Reject destinations outside Unguja up-front — the user can't
    // navigate to a place we don't cover. The island-wide box allows
    // any heritage site plus any user origin on the island.
    if (!UngujaBounds.contains(LatLng(siteLat, siteLng))) {
      _emitError(
        mySession,
        'Destination is outside Zanzibar',
        errorCode: 'destination_out_of_bounds',
      );
      return;
    }

    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      // Surface a structured errorCode so the screen can render a
      // localized "Location permission required" SnackBar with an
      // "Open Settings" CTA, rather than the previous English-only
      // free-text banner.
      _emitError(
        mySession,
        'Location permission required',
        errorCode: 'permission_denied',
      );
      return;
    }

    if (mySession != _sessionId) return; // raced with a newer session

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      _updatePosition(position);
    }

    _locationService.startListening(distanceFilter: 5);
    _positionSubscription = _locationService.positionStream.listen(
      (position) {
        if (mySession != _sessionId) return;
        _updatePosition(position);
      },
      onError: (error, _) {
        if (mySession != _sessionId) return;
        _emitError(mySession, error.toString(), errorCode: 'gps_error');
      },
    );
  }

  void _updatePosition(Position position) {
    if (_siteLat == null || _siteLng == null) return;

    final distance = dc.DistanceCalculator.calculateDistance(
      position.latitude,
      position.longitude,
      _siteLat!,
      _siteLng!,
    );

    final eta = dc.DistanceCalculator.estimateWalkingTime(distance);
    final hasArrived = distance <= _entryRadiusM;

    if (hasArrived && !_hasArrived) {
      _hasArrived = true;
      emit(
        state.copyWith(
          navigationState: NavigationState(
            status: NavigationStatus.arrived,
            currentPosition: position,
            distanceToSite: distance,
            estimatedTime: eta,
            hasArrived: true,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          navigationState: NavigationState(
            status: NavigationStatus.navigating,
            currentPosition: position,
            distanceToSite: distance,
            estimatedTime: eta,
            hasArrived: false,
          ),
        ),
      );
    }
  }

  void _emitError(int session, String message, {String? errorCode}) {
    if (session != _sessionId) return;
    // Preserve the last known position / distance so the UI keeps showing
    // something useful — only flip status + message.
    emit(
      state.copyWith(
        navigationState: state.navigationState.copyWith(
          status: NavigationStatus.error,
          errorMessage: message,
          errorCode: errorCode,
        ),
      ),
    );
  }

  void stopNavigation() {
    _sessionId += 1; // invalidate any in-flight session
    _locationService.stopListening();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _siteLat = null;
    _siteLng = null;
    _hasArrived = false;

    // Reset, but keep any terminal error message visible so a brief
    // background → foreground cycle doesn't silently mask a permission
    // failure or OSRM outage.
    final lastError = state.navigationState.errorMessage;
    emit(
      NavigationCubitState(
        navigationState: NavigationState(
          status: NavigationStatus.idle,
          errorMessage: lastError,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    stopNavigation();
    return super.close();
  }
}
