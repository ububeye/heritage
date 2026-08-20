// Widget tests for the navigate-chooser bottom sheet that the heritage-site
// detail screen opens when the user taps "Navigate".
//
// Pins:
//   1. Both options ("Google Maps" and "In-app map (OSRM)") are present,
//      and the Google Maps row carries the "Recommended" badge.
//   2. Tapping the Google Maps row launches the universal
//      `https://www.google.com/maps/dir/?api=1&destination=LAT,LNG&travelmode=walking`
//      URL via the url_launcher plugin's platform channel, with
//      LaunchMode.externalApplication.
//   3. If `canLaunch` reports `false`, the sheet shows the snackbar
//      "Couldn't open Google Maps on this device." instead of launching.
//   4. Tapping the OSRM row pops the sheet and pushes NavigationScreenOpen.
//   5. Sites with lat=0, lng=0 (the SiteModel default for missing coords)
//      disable the Google Maps row so its tap is a no-op.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/blocs/localization/localization_cubit.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/navigate_chooser.dart';
import 'package:stone_town_heritage_vt_guide/data/models/site_model.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/tts_service.dart';

/// Navigator observer that records the runtime type of the most
/// recently pushed route. Used by the OSRM-tap test to prove
/// `safePushNavigation` was invoked without forcing the
/// `NavigationScreenOpen` provider graph to build.
///
/// `safePushNavigation` pushes a bare `MaterialPageRoute`, so we just
/// assert the runtimeType. We deliberately do NOT call the route's
/// builder here — that's the part that crashes on missing providers.
class _RecordingNavigatorObserver extends NavigatorObserver {
  Type? pushedRouteType;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteType = route.runtimeType;
    super.didPush(route, previousRoute);
  }
}

const _urlLauncherChannel =
    MethodChannel('plugins.flutter.io/url_launcher');

const _englishTranslations = <String, String>{
  'navigate_chooser_title': 'Choose how to navigate',
  'navigate_google_maps': 'Google Maps',
  'navigate_google_maps_subtitle':
      "Opens your phone's Google Maps app with this location as the destination",
  'navigate_osrm': 'In-app map (OSRM)',
  'navigate_osrm_subtitle':
      'Use the in-app open-source map — no app switch.',
  'recommended': 'Recommended',
  'navigate_external_failed':
      "Couldn't open a maps app on this device.",
};

SiteModel _site({
  double lat = -6.1629,
  double lng = 39.1936,
}) {
  return SiteModel(
    id: 's1',
    nameEn: 'House of Wonders',
    nameSw: 'Nyumba ya Ajabu',
    descriptionEn: 'desc',
    descriptionSw: 'maelezo',
    descriptionFr: '',
    descriptionDe: '',
    descriptionAr: '',
    descriptionIt: '',
    descriptionEs: '',
    cloudinaryImageUrl: '',
    latitude: lat,
    longitude: lng,
  );
}

class _FakeLocalizationCubit extends LocalizationCubit {
  _FakeLocalizationCubit()
      : super(
          ttsService: TtsService(),
        );

  void seedEnglish() {
    emit(
      LocalizationState(
        currentLanguage: 'en',
        translations: _englishTranslations,
      ),
    );
  }
}

Future<void> _pumpChooser(
  WidgetTester tester, {
  required SiteModel site,
  _RecordingNavigatorObserver? navigatorObserver,
}) async {
  final cubit = _FakeLocalizationCubit()..seedEnglish();
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: navigatorObserver == null
          ? const <NavigatorObserver>[]
          : <NavigatorObserver>[navigatorObserver],
      home: BlocProvider<LocalizationCubit>.value(
        value: cubit,
        child: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showNavigateChooser(ctx, site),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Installs a mock handler for the url_launcher platform channel and
/// captures every MethodCall so tests can assert the launched URL.
///
/// The url_launcher public API (`launchUrl` / `canLaunchUrl`) routes to
/// the platform's `launch` / `canLaunch` methods on the
/// `plugins.flutter.io/url_launcher` channel (see
/// url_launcher_platform_interface's MethodChannelUrlLauncher). The
/// `launchUrl` Dart name does NOT appear on the platform channel — the
/// method is named `launch`.
void _installUrlLauncherMock({
  bool canOpen = true,
  bool launchResult = true,
  List<MethodCall>? capture,
}) {
  TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
    capture?.add(call);
    switch (call.method) {
      case 'canLaunch':
        return canOpen;
      case 'launch':
        return launchResult;
      default:
        return null;
    }
  });
}

void _uninstallUrlLauncherMock() {
  TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, null);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.getInstance();
  });

  tearDown(_uninstallUrlLauncherMock);

  testWidgets('renders both options and the Recommended badge',
      (tester) async {
    _installUrlLauncherMock();

    await _pumpChooser(tester, site: _site());

    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('In-app map (OSRM)'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Choose how to navigate'), findsOneWidget);
  });

  testWidgets(
      'Google Maps tap launches via the three-tier maps_launcher',
      (tester) async {
    final calls = <MethodCall>[];
    _installUrlLauncherMock(capture: calls);

    await _pumpChooser(tester, site: _site(lat: -6.1629, lng: 39.1936));

    await tester.tap(find.text('Google Maps'));
    // canLaunchUrl + launchUrl await platform-channel futures. Wrap in
    // runAsync so the real microtask queue completes instead of being
    // swallowed by the fake-async test clock.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final launchCalls =
        calls.where((c) => c.method == 'launch').toList();
    expect(
      launchCalls,
      hasLength(1),
      reason: 'Exactly one launch when the first tier succeeds',
    );

    // On the Dart VM (test host) primaryMapsUri returns the Google
    // search URL — there's no Android/iOS platform to resolve the
    // `geo:` scheme. The exact URL shape is covered in
    // test/core/utils/maps_launcher_test.dart; here we only pin the
    // chooser's intent (a URL containing the destination coords).
    final args = launchCalls.first.arguments as Map<Object?, Object?>;
    final url = args['url'] as String;
    expect(url, contains('google.com/maps'));
    expect(url, contains('-6.1629'));
    expect(url, contains('39.1936'));
    // LaunchMode.externalApplication → useWebView=false.
    expect(args['useWebView'], isFalse);
  });

  testWidgets(
      'shows the snackbar when no maps app is installed (every tier fails)',
      (tester) async {
    // Simulate a phone with no maps app: every `launch` call returns
    // false (the platform has no handler). The three-tier chain runs
    // to exhaustion, then the chooser surfaces the snackbar.
    final calls = <MethodCall>[];
    _installUrlLauncherMock(capture: calls, launchResult: false);

    await _pumpChooser(tester, site: _site());

    await tester.tap(find.text('Google Maps'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(
      find.text("Couldn't open a maps app on this device."),
      findsOneWidget,
    );
  });

  testWidgets('OSRM tap pops the sheet and pushes NavigationScreenOpen',
      (tester) async {
    // url_launcher should not be touched on this path.
    final calls = <MethodCall>[];
    _installUrlLauncherMock(capture: calls);

    // The real NavigationScreenOpen needs a wide provider graph
    // (NavigationCubit, AuthCubit, SiteDetailCubit, …) we don't want
    // to construct just for this test. The observer fires BEFORE the
    // pushed page builds, so we can pin the intent without the build
    // crashing on missing providers.
    final observer = _RecordingNavigatorObserver();

    await _pumpChooser(
      tester,
      site: _site(),
      navigatorObserver: observer,
    );

    await tester.tap(find.text('In-app map (OSRM)'));
    // safePushNavigation synchronously pushes NavigationScreenOpen,
    // which crashes on missing providers. The observer fires before
    // build, so we already have the proof of intent. Swallow the
    // expected provider exception so the test doesn't fail.
    await tester.pumpAndSettle();
    final exception = tester.takeException();
    expect(
      exception,
      isA<ProviderNotFoundException>(),
      reason:
          'OSRM path must invoke safePushNavigation (which throws '
          'ProviderNotFoundException only because the test harness '
          'omits the real provider graph)',
    );

    expect(calls, isEmpty, reason: 'OSRM path must not touch url_launcher');
    // After pop+push the sheet is gone — assert that.
    expect(
      find.text('In-app map (OSRM)'),
      findsNothing,
      reason: 'Sheet should have popped',
    );
    expect(
      observer.pushedRouteType,
      isNotNull,
      reason: 'safePushNavigation must have pushed a route',
    );
    expect(
      observer.pushedRouteType,
      MaterialPageRoute,
      reason:
          'safePushNavigation pushes a MaterialPageRoute, not a modal '
          'sheet or dialog',
    );
  });

  testWidgets('zero-coord site disables the Google Maps tile',
      (tester) async {
    final calls = <MethodCall>[];
    _installUrlLauncherMock(capture: calls);

    await _pumpChooser(tester, site: _site(lat: 0.0, lng: 0.0));

    // Google Maps row is still rendered but enabled=false → tap is a
    // no-op (no launch, no snackbar).
    final googleTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Google Maps'),
        matching: find.byType(ListTile),
      ),
    );
    expect(googleTile.enabled, isFalse);

    await tester.tap(find.text('Google Maps'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(calls, isEmpty);
  });
}