import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/utils/unguja_bounds.dart';
import '../../data/services/location_service.dart';
import 'user_location_state.dart';

/// Cubit that owns the always-on user-position stream consumed by the
/// tourist-facing maps (Explore + SiteDetail). Independent of
/// [NavigationCubit], which only emits a position inside an active
/// navigation session.
///
/// ### Lifecycle
/// The cubit uses a refcount so multiple map screens can share a single
/// GPS subscription. Each map calls [ref] in `initState` and [unref] in
/// `dispose`. The first `ref` (0 → 1) starts the stream; the last `unref`
/// (1 → 0) tears it down.
///
///### Permission
/// The cubit does NOT request permission itself. Callers invoke
/// [ensurePermissionAndStart] which delegates to
/// [LocationService.checkPermission]. The cubit is happy to run without
/// permission — it just emits `hasPermission == false` and never
/// receives a fix.
class UserLocationCubit extends Cubit<UserLocationState> {
  UserLocationCubit({LocationService? locationService})
      : _locationService = locationService ?? LocationService(),
        super(const UserLocationState());

  final LocationService _locationService;
  StreamSubscription<Position>? _subscription;

  /// Monotonically increasing session id. A new [ref] call bumps this so
  /// the listener can discard stale fixes from a previous subscription.
  int _sessionId = 0;

  /// Number of active map screens holding a ref. The stream is started
  /// on 0→1 and stopped on 1→0.
  int _refCount = 0;

  /// Request location permission and, if granted, start the GPS stream.
  ///
  /// On permission denial the cubit emits `hasPermission == false` and
  /// the UI surfaces a snackbar. No re-prompt is attempted until the user
  /// next toggles location services on.
  Future<void> ensurePermissionAndStart({int distanceFilter = 5}) async {
    final granted = await _locationService.checkPermission();
    if (!granted) {
      emit(state.copyWith(hasPermission: false));
      return;
    }
    // Surface permission immediately so the UI can update before the
    // first GPS fix arrives (cold start can take 5–10 s on Android).
    emit(state.copyWith(hasPermission: true));
    ref(distanceFilter: distanceFilter);
  }

  /// Increment the refcount. Starts the GPS subscription on 0→1.
  void ref({int distanceFilter = 5}) {
    _refCount += 1;
    if (_refCount == 1) {
      _sessionId += 1;
      final mySession = _sessionId;
      _subscription?.cancel();
      _locationService.startListening(distanceFilter: distanceFilter);
      _subscription = _locationService.positionStream.listen(
        (position) {
          if (mySession != _sessionId) return;
          _onPosition(position);
        },
        onError: (error, _) {
          if (mySession != _sessionId) return;
          emit(state.copyWith(errorMessage: error.toString()));
        },
      );
    }
  }

  /// Decrement the refcount. Stops the GPS subscription on 1→0. The
  /// emitted `position` is nulled so the map clears the dot; `hasPermission`
  /// is preserved.
  void unref() {
    if (_refCount == 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _sessionId += 1; // invalidate any in-flight emits
      _subscription?.cancel();
      _subscription = null;
      _locationService.stopListening();
      emit(state.copyWith(clearPosition: true));
    }
  }

  /// Alias for [unref] that always tears down. Used by tests; the public
  /// [unref] is refcount-safe and a no-op when already stopped.
  void stop() {
    while (_refCount > 0) {
      unref();
    }
  }

  void _onPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    final inside = UngujaBounds.contains(point);
    emit(
      state.copyWith(
        position: position,
        hasPermission: true,
        isInUnguja: inside,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}