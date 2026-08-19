// Unit tests for the UserLocationCubit: refcount lifecycle, permission
// flow, position emission, and stale-session invalidation.
//
// The fake mirrors the canonical _FakeLocationService pattern used by
// navigation_cubit_test.dart — Dart unit tests don't share private
// fixtures across files.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/blocs/user_location/user_location_cubit.dart';
import 'package:stone_town_heritage_vt_guide/data/services/location_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/runtime_config_service.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService({this.permissionGranted = true});
  bool permissionGranted;
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();
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
    return _make(lat: -6.1650, lng: 39.2050);
  }

  @override
  void startListening({int distanceFilter = 5}) {
    startListeningCalls++;
  }

  @override
  void stopListening() {
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

  static Position _make({required double lat, required double lng}) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 1, 1, 12, 0, 0),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Position _at({required double lat, required double lng}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime(2026, 1, 1, 12, 0, 0),
    accuracy: 5,
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

  group('UserLocationCubit', () {
    test('initial state is idle with no permission and no position', () {
      final loc = _FakeLocationService();
      final cubit = UserLocationCubit(locationService: loc);
      addTearDown(cubit.close);

      expect(cubit.state.position, isNull);
      expect(cubit.state.hasPermission, isFalse);
      expect(cubit.state.isInUnguja, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(loc.startListeningCalls, 0);
    });

    test(
      'permission granted → refcount starts the stream and emits the fix',
      () async {
        final loc = _FakeLocationService();
        final cubit = UserLocationCubit(locationService: loc);
        addTearDown(cubit.close);

        await cubit.ensurePermissionAndStart();
        expect(loc.startListeningCalls, 1);
        expect(cubit.state.hasPermission, isTrue);

        // Pump a fix that should appear inside Unguja.
        loc.push(_at(lat: -6.1650, lng: 39.2050));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(cubit.state.position, isNotNull);
        expect(cubit.state.isInUnguja, isTrue);
      },
    );

    test(
      'permission denied → hasPermission flips false and stream does not start',
      () async {
        final loc = _FakeLocationService(permissionGranted: false);
        final cubit = UserLocationCubit(locationService: loc);
        addTearDown(cubit.close);

        await cubit.ensurePermissionAndStart();
        expect(cubit.state.hasPermission, isFalse);
        expect(loc.startListeningCalls, 0);
        expect(cubit.state.position, isNull);
      },
    );

    test('a fix at (0, 0) marks isInUnguja false', () async {
      final loc = _FakeLocationService();
      final cubit = UserLocationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.ensurePermissionAndStart();
      loc.push(_at(lat: 0.0, lng: 0.0));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.position, isNotNull);
      expect(cubit.state.isInUnguja, isFalse);
    });

    test('stream errors surface in errorMessage', () async {
      final loc = _FakeLocationService();
      final cubit = UserLocationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.ensurePermissionAndStart();
      loc.pushError(StateError('GPS blown up'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.errorMessage, contains('GPS blown up'));
    });

    test('a clean fix after an error clears errorMessage', () async {
      final loc = _FakeLocationService();
      final cubit = UserLocationCubit(locationService: loc);
      addTearDown(cubit.close);

      await cubit.ensurePermissionAndStart();
      loc.pushError(StateError('GPS blown up'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.errorMessage, isNotNull);

      loc.push(_at(lat: -6.1650, lng: 39.2050));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.errorMessage, isNull);
    });

    test(
      'reentrant ref() invalidates the first session',
      () async {
        final loc = _FakeLocationService();
        final cubit = UserLocationCubit(locationService: loc);
        addTearDown(cubit.close);

        cubit.ref();
        expect(loc.startListeningCalls, 1);
        cubit.ref();
        // Second ref must NOT call startListening again.
        expect(loc.startListeningCalls, 1);
      },
    );

    test(
      'refcount: two ref() calls = one startListening; two unref() calls = one stopListening',
      () async {
        final loc = _FakeLocationService();
        final cubit = UserLocationCubit(locationService: loc);
        addTearDown(cubit.close);

        cubit.ref();
        cubit.ref();
        expect(loc.startListeningCalls, 1);
        expect(loc.stopListeningCalls, 0);

        cubit.unref();
        expect(loc.stopListeningCalls, 0);
        cubit.unref();
        expect(loc.stopListeningCalls, 1);
      },
    );

    test(
      'unref clears the position but preserves hasPermission',
      () async {
        final loc = _FakeLocationService();
        final cubit = UserLocationCubit(locationService: loc);
        addTearDown(cubit.close);

        cubit.ref();
        loc.push(_at(lat: -6.1650, lng: 39.2050));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(cubit.state.position, isNotNull);
        expect(cubit.state.hasPermission, isTrue);

        cubit.unref();
        expect(cubit.state.position, isNull);
        expect(cubit.state.hasPermission, isTrue);
      },
    );

    test(
      'stop() always tears down regardless of refcount balance',
      () async {
        final loc = _FakeLocationService();
        final cubit = UserLocationCubit(locationService: loc);
        addTearDown(cubit.close);

        cubit.ref();
        cubit.ref();
        cubit.ref();
        cubit.stop();
        // Stopped via repeated unref() — the count must reach zero and
        // startListening must have been called exactly once.
        expect(loc.startListeningCalls, 1);
        expect(loc.stopListeningCalls, 1);
      },
    );

    test('close() then a stream push does not crash', () async {
      final loc = _FakeLocationService();
      final cubit = UserLocationCubit(locationService: loc);
      await cubit.ensurePermissionAndStart();
      await cubit.close();
      // Push to the still-open fake — must not throw.
      loc.push(_at(lat: -6.1650, lng: 39.2050));
      await Future<void>.delayed(const Duration(milliseconds: 5));
    });
  });
}