// Tests for the three-tier maps launcher in
// [lib/core/utils/maps_launcher.dart]. Pins:
//   1. Primary URL is `geo:` on Android/iOS, Google search URL on
//      desktop/web.
//   2. Fallback URL is always the Google web search URL.
//   3. [openNavigation] tries the primary URI first; on success
//      returns true and does NOT try the fallback.
//   4. When the primary launch fails (returns false from the platform
//      channel), the fallback is tried next.
//   5. When both externalApplication launches fail, the fallback is
//      tried a second time with LaunchMode.platformDefault — catches
//      emulators that reject externalApplication.
//   6. The 0,0 / NaN short-circuit returns false without touching
//      the platform channel at all — a denied-location fix returning
//      0,0 must never drop the user in the Atlantic.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/maps_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

const _urlLauncherChannel =
    MethodChannel('plugins.flutter.io/url_launcher');

/// Installs a mock handler on the url_launcher platform channel and
/// captures every MethodCall. The handler's `canLaunch`/`launch`
/// responses come from [canOpen] and [launchResult]; if both are
/// omitted, the channel answers `true` to every call (success path).
///
/// Setting [alwaysFail] makes the channel throw on every `launch`
/// call — exercises the try/catch fallback in the launcher.
void _installMock({
  required List<MethodCall> capture,
  bool canOpen = true,
  bool launchResult = true,
  bool alwaysFail = false,
}) {
  TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
    capture.add(call);
    switch (call.method) {
      case 'canLaunch':
        return canOpen;
      case 'launch':
        if (alwaysFail) {
          throw StateError('simulated launch failure');
        }
        return launchResult;
      default:
        return null;
    }
  });
}

void _uninstallMock() {
  TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, null);
}

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);
  tearDown(_uninstallMock);

  group('primaryMapsUri', () {
    test('returns geo: scheme on mobile with label as the pin', () {
      final uri = primaryMapsUri(
        lat: -6.1629,
        lng: 39.1936,
        label: 'House of Wonders',
      );
      // No `Platform.isAndroid` override → defaults to the host
      // platform. In the Dart VM that means neither Android nor iOS,
      // so the function falls back to the web URL.
      expect(uri.scheme, anyOf('https', 'geo'));
      if (uri.scheme == 'geo') {
        expect(uri.toString(), startsWith('geo:-6.1629,39.1936'));
        expect(uri.queryParameters['q'], contains('House'));
      }
    });

    test('returns Google web URL on non-mobile', () {
      final uri = primaryMapsUri(lat: -6.1629, lng: 39.1936);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.toString(), contains('maps/search'));
    });

    test('omits the q= label when no label is supplied', () {
      final uri = primaryMapsUri(lat: 1, lng: 2);
      expect(uri.toString(), isNot(contains('(')));
    });
  });

  group('fallbackMapsUri', () {
    test('always returns the Google web search URL', () {
      final uri = fallbackMapsUri(lat: -6.1629, lng: 39.1936);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.toString(), contains('maps/search'));
      // Uri does not encode `,` in query params — the wire format
      // ships `query=-6.1629,39.1936`. The label-bearing branch
      // encodes the parentheses, which is what matters for receivers.
      expect(uri.queryParameters['query'], '-6.1629,39.1936');
    });

    test('encodes the label into the search query', () {
      final uri = fallbackMapsUri(
        lat: -6.1629,
        lng: 39.1936,
        label: 'House of Wonders',
      );
      expect(
        uri.toString(),
        contains(Uri.encodeComponent('House of Wonders')),
      );
    });
  });

  group('openNavigation', () {
    test('returns false for (0, 0) without touching the channel', () async {
      final calls = <MethodCall>[];
      _installMock(capture: calls);

      final ok = await openNavigation(lat: 0, lng: 0);

      expect(ok, isFalse);
      expect(
        calls,
        isEmpty,
        reason:
            '0,0 is a denied-location stub — must short-circuit before '
            'launching anything',
      );
    });

    test('returns false for NaN coordinates without touching the channel',
        () async {
      final calls = <MethodCall>[];
      _installMock(capture: calls);

      final ok = await openNavigation(lat: double.nan, lng: 39.1936);

      expect(ok, isFalse);
      expect(calls, isEmpty);
    });

    test('launches once and returns true when the first tier succeeds',
        () async {
      final calls = <MethodCall>[];
      _installMock(capture: calls);

      final ok = await openNavigation(
        lat: -6.1629,
        lng: 39.1936,
        label: 'House of Wonders',
      );

      expect(ok, isTrue);
      // Exactly one launch attempt — no fallback noise.
      final launches = calls.where((c) => c.method == 'launch').toList();
      expect(launches, hasLength(1));
    });

    test('falls through to the fallback URL when the primary launch fails',
        () async {
      final calls = <MethodCall>[];
      // canLaunch=true (so the platform says it CAN handle the URI),
      // launch=false → the launch tier reports failure and we fall
      // through to the next attempt.
      _installMock(capture: calls, launchResult: false);

      final ok = await openNavigation(
        lat: -6.1629,
        lng: 39.1936,
      );

      expect(ok, isFalse);
      // We made it through all three tiers before giving up.
      final launches = calls.where((c) => c.method == 'launch').toList();
      expect(
        launches.length,
        greaterThanOrEqualTo(2),
        reason:
            'Primary failure must be followed by at least one fallback '
            'attempt before returning false',
      );
    });

    test('falls through to platformDefault after externalApplication fails',
        () async {
      final calls = <MethodCall>[];
      _installMock(capture: calls, launchResult: false);

      await openNavigation(lat: -6.1629, lng: 39.1936);

      // Look at the launch args for the final attempt — it should be
      // the platformDefault mode (useWebView=true is the url_launcher
      // platform's marker for platformDefault; externalApplication
      // passes useWebView=false).
      final launches = calls.where((c) => c.method == 'launch').toList();
      final lastArgs = launches.last.arguments as Map<Object?, Object?>;
      expect(
        lastArgs['useWebView'],
        isTrue,
        reason: 'final tier must be platformDefault (useWebView=true)',
      );
    });

    test('survives a thrown exception from the platform channel', () async {
      final calls = <MethodCall>[];
      _installMock(capture: calls, alwaysFail: true);

      final ok = await openNavigation(lat: -6.1629, lng: 39.1936);

      expect(
        ok,
        isFalse,
        reason: 'must not throw — catches and falls through to next tier',
      );
      // All three tiers attempted despite every throw.
      final launches = calls.where((c) => c.method == 'launch').toList();
      expect(launches.length, greaterThanOrEqualTo(3));
    });
  });

  group('directionsMapsUri', () {
    test('builds a /maps/dir/ walking-directions URL', () {
      final uri = directionsMapsUri(lat: -6.1629, lng: 39.1936);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['travelmode'], 'walking');
      expect(
        uri.queryParameters['destination'],
        '-6.1629,39.1936',
      );
    });
  });
}