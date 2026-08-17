import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../../core/constants/app_constants.dart';
import '../../data/models/navigation_state.dart';
import '../../data/services/location_service.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../core/utils/distance_calculator.dart' as dc;
import '../../core/utils/unguja_bounds.dart';
import 'navigation_state.dart';

/// Cubit that owns the live-navigation state machine: permission gating,
/// GPS subscription, arrival detection, and route-recalculation flags.
///
/// ### Arrival debounce
/// A single GPS fix inside the destination radius is not enough to fire
/// "arrived" — noisy GPS can drop the user briefly outside the radius
/// and back in. We require [_arrivalConfirmCount] consecutive fixes inside
/// the radius before firing [NavigationStatus.arrived]. Once fired, the
/// state stays "arrived" until [stopNavigation] is called.
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

  /// Number of consecutive fixes inside the destination radius required
  /// to fire [NavigationStatus.arrived]. Set at [startNavigation] time.
  int _arrivalConfirmCount = AppConstants.defaultArrivalConfirmCount;

  /// Counter used by the arrival debounce.
  int _consecutiveInsideRadius = 0;

  /// Monotonically increasing navigation id. A new `startNavigation` call
  /// bumps this so the screen can discard stale GPS / route updates from
  /// a previous session.
  int _sessionId = 0;

  Future<void> startNavigation({
    required String siteId,
    required double siteLat,
    required double siteLng,
    double entryRadiusM = 30.0,
    int? arrivalConfirmCount,
  }) async {
    // 1. Tear down the previous session cleanly before starting a new one.
    _sessionId += 1;
    final mySession = _sessionId;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _hasArrived = false;
    _consecutiveInsideRadius = 0;

    _siteLat = siteLat;
    _siteLng = siteLng;
    _entryRadiusM = entryRadiusM;
    // Larger arrival radii need more confirmation fixes — a single
    // accurate sample inside a 50 m radius is more trustworthy than
    // inside a 5 m radius.
    final largeRadius = entryRadiusM >= 50;
    _arrivalConfirmCount = arrivalConfirmCount ??
        (largeRadius ? 3 : AppConstants.defaultArrivalConfirmCount);

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

  /// Mark a route recalculation as in-flight. The UI surfaces this via the
  /// "Recalculating route…" banner. The cubit doesn't actually fetch the
  /// route — it only tracks the flag.
  void setRecalculatingRoute(bool value) {
    if (state.navigationState.recalculatingRoute == value) return;
    emit(
      state.copyWith(
        navigationState: state.navigationState.copyWith(
          recalculatingRoute: value,
        ),
      ),
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

    // Arrival debounce: count consecutive fixes inside the radius.
    final insideRadius = distance <= _entryRadiusM;
    if (insideRadius) {
      _consecutiveInsideRadius += 1;
    } else {
      _consecutiveInsideRadius = 0;
    }

    final shouldArrive = insideRadius &&
        _consecutiveInsideRadius >= _arrivalConfirmCount &&
        !_hasArrived;

    if (shouldArrive) {
      _hasArrived = true;
      emit(
        state.copyWith(
          navigationState: NavigationState(
            status: NavigationStatus.arrived,
            currentPosition: position,
            distanceToSite: distance,
            estimatedTime: eta,
            hasArrived: true,
            recalculatingRoute: state.navigationState.recalculatingRoute,
          ),
        ),
      );
      return;
    }

    // If we've already arrived, keep emitting "arrived" for every fresh
    // fix — the previous version dropped back to "navigating", which
    // flickered the Arrived banner off briefly on every GPS update.
    final alreadyArrived = _hasArrived;
    emit(
      state.copyWith(
        navigationState: NavigationState(
          status: alreadyArrived
              ? NavigationStatus.arrived
              : NavigationStatus.navigating,
          currentPosition: position,
          distanceToSite: distance,
          estimatedTime: eta,
          hasArrived: alreadyArrived,
          recalculatingRoute: state.navigationState.recalculatingRoute,
        ),
      ),
    );
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
    _consecutiveInsideRadius = 0;

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
