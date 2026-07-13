// Unit tests for turn-by-turn step handling.
//
// Covers:
//   * RoutingService.currentStepIndex — picks the closest step start.
//   * RouteStep.localizedDescription — human-readable summary across the
//     maneuver / modifier combinations we care about, in English via a
//     stub translation map (mirrors what the UI does with
//     LocalizationCubit.translate).
//   * ManeuverIcon.forManeuver — icon mapping for the common cases.
//
// We do not exercise the private OSRM response parser directly; instead
// the parser is exercised through `currentStepIndex` and the public
// RouteStep API, which is what callers actually depend on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stone_town_heritage_vt_guide/data/services/routing_service.dart';

/// Stub translation map mirroring the English localization file for the
/// keys RouteStep.localizedDescription consults. Falls back to the key
/// itself for anything missing so an untranslated key surfaces as
/// `'<key>'` in the test expectation.
String Function(String) _tr(Map<String, String> dict) =>
    (String key) => dict[key] ?? key;

void main() {
  group('RoutingService.currentStepIndex', () {
    final steps = [
      const RouteStep(
        maneuver: 'depart',
        name: 'Creek Road',
        distanceMeters: 100,
        startLocation: LatLng(-6.1600, 39.1936),
        endLocation: LatLng(-6.1610, 39.1936),
      ),
      const RouteStep(
        maneuver: 'turn left',
        name: 'Kenyatta Road',
        distanceMeters: 250,
        startLocation: LatLng(-6.1610, 39.1936),
        endLocation: LatLng(-6.1610, 39.1920),
      ),
      const RouteStep(
        maneuver: 'arrive',
        name: '',
        distanceMeters: 30,
        startLocation: LatLng(-6.1610, 39.1920),
        endLocation: LatLng(-6.1610, 39.1920),
      ),
    ];

    test('returns 0 when the user is on the first step', () {
      expect(
        RoutingService.currentStepIndex(steps, const LatLng(-6.1600, 39.1936)),
        0,
      );
    });

    test('advances to the second step when the user is near its start', () {
      expect(
        RoutingService.currentStepIndex(steps, const LatLng(-6.1610, 39.1936)),
        1,
      );
    });

    test('reaches the final arrive step', () {
      expect(
        RoutingService.currentStepIndex(steps, const LatLng(-6.1610, 39.1920)),
        2,
      );
    });

    test('handles an empty step list without crashing', () {
      expect(RoutingService.currentStepIndex(const [], const LatLng(0, 0)), 0);
    });
  });

  group('RouteStep.localizedDescription', () {
    // Minimal English translation table for the keys consulted by
    // RouteStep.localizedDescription. Adding new modifiers here in
    // step with assets/localization/en.json keeps these tests honest.
    final en = <String, String>{
      'turn_left': 'Turn left',
      'turn_right': 'Turn right',
      'continue_straight': 'Continue straight',
      'continue_on': 'Continue on',
      'onto': 'onto',
      'arrive_at_destination': 'Arrive at destination',
      'at_the_fork': 'At the fork',
      'merge_ahead': 'Merge',
      'enter_roundabout': 'Enter the roundabout',
      'make_uturn': 'Make a U-turn',
    };
    final tr = _tr(en);

    test('turn + street name produces "Turn left onto Kenyatta Road"', () {
      const step = RouteStep(
        maneuver: 'turn left',
        name: 'Kenyatta Road',
        distanceMeters: 100,
        startLocation: LatLng(0, 0),
        endLocation: LatLng(0, 0),
      );
      expect(step.localizedDescription(tr), 'Turn left onto Kenyatta Road');
    });

    test('continue without modifier falls back to "Continue on <name>"', () {
      const step = RouteStep(
        maneuver: 'continue',
        name: 'Creek Road',
        distanceMeters: 80,
        startLocation: LatLng(0, 0),
        endLocation: LatLng(0, 0),
      );
      expect(step.localizedDescription(tr), 'Continue on Creek Road');
    });

    test('modifier-only (no street) renders the modifier alone', () {
      const step = RouteStep(
        maneuver: 'turn right',
        name: '',
        distanceMeters: 40,
        startLocation: LatLng(0, 0),
        endLocation: LatLng(0, 0),
      );
      expect(step.localizedDescription(tr), 'Turn right');
    });

    test('depart without modifier returns generic Continue straight', () {
      // Depart steps don't carry useful UI text — the next step is what
      // the user actually acts on.
      const step = RouteStep(
        maneuver: 'depart',
        name: 'Creek Road',
        distanceMeters: 0,
        startLocation: LatLng(0, 0),
        endLocation: LatLng(0, 0),
      );
      expect(step.localizedDescription(tr), 'Continue on Creek Road');
    });

    test('arrive step is labelled explicitly', () {
      const step = RouteStep(
        maneuver: 'arrive',
        name: '',
        distanceMeters: 0,
        startLocation: LatLng(0, 0),
        endLocation: LatLng(0, 0),
      );
      expect(step.localizedDescription(tr), 'Arrive at destination');
    });
  });

  group('ManeuverIcon.forManeuver', () {
    test('turn left → Icons.turn_left', () {
      expect(ManeuverIcon.forManeuver('turn left'), Icons.turn_left);
    });

    test('turn right → Icons.turn_right', () {
      expect(ManeuverIcon.forManeuver('turn right'), Icons.turn_right);
    });

    test('slight left → Icons.turn_slight_left', () {
      // IconData equality compares the underlying codepoint, which is
      // stable across Material versions for the same logical icon.
      expect(
        ManeuverIcon.forManeuver('turn slight left').codePoint,
        Icons.turn_slight_left.codePoint,
      );
    });

    test('fork left → Icons.fork_left', () {
      expect(ManeuverIcon.forManeuver('fork left'), Icons.fork_left);
    });

    test('roundabout → Icons.roundabout_left', () {
      expect(ManeuverIcon.forManeuver('roundabout'), Icons.roundabout_left);
    });

    test('depart → Icons.play_arrow', () {
      expect(ManeuverIcon.forManeuver('depart'), Icons.play_arrow);
    });

    test('arrive → Icons.flag', () {
      expect(ManeuverIcon.forManeuver('arrive'), Icons.flag);
    });

    test('unknown modifier falls back to Icons.straight', () {
      expect(ManeuverIcon.forManeuver('continue'), Icons.straight,);
    });
  });

  group('RouteResult', () {
    test('fallback returns a 2-point polyline and empty steps', () {
      final r = RouteResult.fallback(
        from: const LatLng(-6.1600, 39.1936),
        to: const LatLng(-6.1620, 39.1940),
        distanceMeters: 50,
        provider: 'none',
        errorMessage: 'offline',
      );
      expect(r.points.length, 2);
      expect(r.steps, isEmpty);
      expect(r.isFallback, isTrue);
      expect(r.errorMessage, 'offline');
    });
  });
}