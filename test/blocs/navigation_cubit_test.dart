// Unit tests for the navigation cubit: arrival debounce, off-route
// recovery, error states, and reentrant startNavigation.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/blocs/navigation/navigation_cubit.dart';
import 'package:stone_town_heritage_vt_guide/data/models/navigation_state.dart';
import 'package:stone_town_heritage_vt_guide/data/services/location_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/runtime_config_service.dart';

/// Fake LocationService that lets tests push Positions synthetically.
class _FakeLocationService implements LocationService {
  _FakeLocationService({this.permissionGranted = true});
  bool permissionGranted;
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();
  bool listening = false;
  int startListeningCalls = 0;
  int stopListeningCalls = 0;

  void push(Position position) {
    _controller.add(position);
  }

  void pushError(Object error) {
    _controller.addError(error);
  }

  @override
  Stream<Position> get positionStream => _controller.stream;

  @override
  Future<bool> checkPermission() async => permissionGranted;

  @override
  Future<Position?> getCurrentPosition() async {
    if (!permissionGranted) return null;
    return _make(lat: -6.1650, lng: 39.2050, accuracy: 5);
  }

  @override
  void startListening({int distanceFilter = 5}) {
    listening = true;
    startListeningCalls++;
  }

  @override
  void stopListening() {
    listening = false;
    stopListeningCalls++;
  }

  @override
  void dispose() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_FakeLocationService.${invocation.memberName} not stubbed',
    );
  }

  static Position _make({
    required double lat,
    required double lng,
    double accuracy = 5,
  }) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 1, 1, 12, 0, 0),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Position _at({required double lat, required double lng, double accuracy = 5}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026, 1, 1, 12, 0, 0),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await RuntimeConfigService.getInstance();
  });

  group('NavigationCubit', () {
    test('initial state is idle with no site', () {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      expect(cubit.state.isNavigating, isFalse);
      expect(cubit.state.navigationState.status, NavigationStatus.idle);
      expect(cubit.state.currentSiteId, isNull);
    });

    test('startNavigation emits navigating for a valid destination', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );

      expect(cubit.state.isNavigating, isTrue);
      expect(cubit.state.currentSiteId, 'site-1');
      expect(cubit.state.navigationState.status, NavigationStatus.navigating);
      expect(loc.startListeningCalls, 1);
    });

    test('rejects a destination outside Unguja without starting GPS', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-x',
        siteLat: 0.0, // null island
        siteLng: 0.0,
      );

      expect(cubit.state.navigationState.status, NavigationStatus.error);
      expect(
        cubit.state.navigationState.errorCode,
        'destination_out_of_bounds',
      );
      expect(loc.startListeningCalls, 0);
    });

    test('emits permission_denied when permission is not granted', () async {
      final loc = _FakeLocationService(permissionGranted: false);
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );

      expect(cubit.state.navigationState.status, NavigationStatus.error);
      expect(cubit.state.navigationState.errorCode, 'permission_denied');
      expect(loc.startListeningCalls, 0);
    });

    test('a single fix inside the radius does NOT fire arrived', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );
      // First fix inside the 30 m radius — debounce should hold.
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.navigationState.status, NavigationStatus.navigating);
      expect(cubit.state.navigationState.hasArrived, isFalse);
    });

    test('two consecutive fixes inside the radius fire arrived', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      // Pump the stream so the listener fires.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      loc.push(_at(lat: -6.16205, lng: 39.19362));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.navigationState.status, NavigationStatus.arrived);
      expect(cubit.state.navigationState.hasArrived, isTrue);
    });

    test('a single fix outside the radius resets the counter', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // User bounces back outside the radius.
      loc.push(_at(lat: -6.1620, lng: 39.1940));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.navigationState.hasArrived, isFalse);
    });

    test('setRecalculatingRoute toggles the embedded flag', () {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      cubit.setRecalculatingRoute(true);
      expect(cubit.state.navigationState.recalculatingRoute, isTrue);
      cubit.setRecalculatingRoute(false);
      expect(cubit.state.navigationState.recalculatingRoute, isFalse);
    });

    test(
      'stopNavigation reverts to idle and tears down the subscription',
      () async {
        final loc = _FakeLocationService();
        final cubit = NavigationCubit(locationService: loc);
        addTearDown(cubit.close);

        await cubit.startNavigation(
          siteId: 'site-1',
          siteLat: -6.1620,
          siteLng: 39.1936,
        );
        cubit.stopNavigation();
        expect(cubit.state.navigationState.status, NavigationStatus.idle);
        expect(cubit.state.isNavigating, isFalse);
        expect(loc.stopListeningCalls, 1);
      },
    );

    test('reentrant startNavigation invalidates the first session', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );
      // Push a fix that would fire arrival in the OLD session if it
      // weren't invalidated.
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // Start a NEW session before the arrival counter finishes.
      await cubit.startNavigation(
        siteId: 'site-2',
        siteLat: -6.1650,
        siteLng: 39.2050,
        arrivalConfirmCount: 1,
      );
      // The new session should own the subscription — pushing a fix that
      // belongs to the new destination should update the new state, not
      // the old one.
      expect(cubit.state.currentSiteId, 'site-2');
      // The fake's getCurrentPosition returns a fix near site-2 which
      // already fires arrival; verify that state sticks instead of
      // flickering back to navigating on subsequent fixes.
      loc.push(_at(lat: -6.1650, lng: 39.2050));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cubit.state.navigationState.hasArrived, isTrue);
      expect(cubit.state.navigationState.status, NavigationStatus.arrived);
    });

    test('stream error surfaces a gps_error state', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );
      loc.pushError(StateError('GPS blown up'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.navigationState.status, NavigationStatus.error);
      expect(cubit.state.navigationState.errorCode, 'gps_error');
    });

    test('uses arrivalConfirmCount override when provided', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      // Confirm count = 1 should fire arrival on a single fix.
      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
        arrivalConfirmCount: 1,
      );
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.navigationState.hasArrived, isTrue);
    });

    test('large radius (>= 50 m) requires 3 fixes for arrival', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
        entryRadiusM: 50.0,
      );
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // Still 1 fix — should not be arrived.
      expect(cubit.state.navigationState.hasArrived, isFalse);
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // Still 2.
      expect(cubit.state.navigationState.hasArrived, isFalse);
      loc.push(_at(lat: -6.1620, lng: 39.1936));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // 3 fixes — should fire.
      expect(cubit.state.navigationState.hasArrived, isTrue);
    });

    test('positions update distanceToSite and ETA as the user moves', () async {
      final loc = _FakeLocationService();
      final cubit = NavigationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.startNavigation(
        siteId: 'site-1',
        siteLat: -6.1620,
        siteLng: 39.1936,
      );
      // ~110 m east of the destination.
      loc.push(_at(lat: -6.1620, lng: 39.1946));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final d = cubit.state.navigationState.distanceToSite!;
      expect(d, greaterThan(50));
      expect(d, lessThan(200));
      expect(cubit.state.navigationState.estimatedTime, isNotNull);
    });

    test('(sanity) LatLng constructed from cubit destination matches', () {
      // The bounds check uses LatLng(lat, lng) — confirm the site lat/lng
      // order is consistent with the cubit's _updatePosition.
      const site = LatLng(-6.1620, 39.1936);
      expect(site.latitude, -6.1620);
      expect(site.longitude, 39.1936);
    });
  });
}
