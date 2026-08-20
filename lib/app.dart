import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_breakpoints.dart';
import 'core/utils/language_meta.dart';
import 'core/utils/rtl.dart';
import 'blocs/auth/auth_cubit.dart';
import 'blocs/site_list/site_list_cubit.dart';
import 'blocs/site_detail/site_detail_cubit.dart';
import 'blocs/navigation/navigation_cubit.dart';
import 'blocs/user_location/user_location_cubit.dart';
import 'blocs/activity/activity_cubit.dart';
import 'data/services/firestore_service.dart';
import 'blocs/language/language_cubit.dart';
import 'blocs/localization/localization_cubit.dart';
import 'blocs/premium/premium_cubit.dart';
import 'blocs/explore/explore_cubit.dart';
import 'blocs/user/user_cubit.dart';
import 'blocs/favorites/favorites_cubit.dart';
import 'blocs/theme/theme_cubit.dart';
import 'blocs/runtime_config/runtime_config_cubit.dart';
import 'data/services/auth_service.dart';
import 'data/services/billing_provider.dart';
import 'data/services/fake_billing_provider.dart';
import 'data/services/tts_service.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/favorites_screen.dart';
import 'ui/screens/admin/admin_shell.dart';
import 'ui/screens/upgrade_screen.dart';

// Top-level so StoneTownApp can stay const. The key is stable for the
// lifetime of the process — there's only one MaterialApp at the root.
final GlobalKey<ScaffoldMessengerState> _rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class StoneTownApp extends StatefulWidget {
  const StoneTownApp({super.key});

  @override
  State<StoneTownApp> createState() => _StoneTownAppState();
}

class _StoneTownAppState extends State<StoneTownApp> {
  // TtsService is constructed once and shared across cubits via injection.
  // init() installs flutter_tts handlers (progress, completion, cancel, error)
  // and MUST be awaited before the first speak() call. We fire it in
  // initState so it runs before the first frame paints.
  final TtsService _ttsService = TtsService();
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _ttsService.init().then((_) {
      if (mounted) setState(() => _ttsReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a minimal loading scaffold while the TTS engine initialises.
    // In practice this takes < 200 ms; the splash screen covers it.
    if (!_ttsReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: SizedBox.shrink()),
      );
    }
    final ttsService = _ttsService;

    // Singleton for now; the real RevenueCat provider will own its own
    // lifecycle. Switching providers is a one-line change here.
    final BillingProvider billing = FakeBillingProvider();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(authService: AuthService()),
        ),
        BlocProvider<SiteListCubit>(create: (_) => SiteListCubit()),
        BlocProvider<NavigationCubit>(create: (_) => NavigationCubit()),
        BlocProvider<UserLocationCubit>(create: (_) => UserLocationCubit()),
        BlocProvider<LanguageCubit>(create: (_) => LanguageCubit()),
        // Registered before SiteDetailCubit: BlocProvider is lazy: false by
        // default, so each create closure runs during MultiBlocProvider's
        // first mount. SiteDetailCubit's create below reads
        // LocalizationCubit, so LocalizationCubit has to be in the scope
        // *above* it (and therefore registered earlier in the list).
        BlocProvider<LocalizationCubit>(
          create:
              (_) =>
                  LocalizationCubit(ttsService: ttsService)..loadTranslations(),
        ),
        BlocProvider<SiteDetailCubit>(
          create:
              (ctx) => SiteDetailCubit(
                ttsService: ttsService,
                localizationCubit: ctx.read<LocalizationCubit>(),
              ),
        ),
        // PremiumCubit depends on AuthCubit for post-purchase user refresh
        // and on the billing provider for store calls. Both are picked up
        // lazily inside the create callback so the AuthCubit instance above
        // is the same one used by the rest of the app. ttsService is
        // injected so a successful purchase can flip TtsService.isPremium
        // synchronously — without it, the user would still hear the 30s
        // preview chunk on the next speak() until they restarted the app.
        BlocProvider<PremiumCubit>(
          create:
              (ctx) => PremiumCubit(
                billing: billing,
                auth: ctx.read<AuthCubit>(),
                ttsService: ttsService,
              )..initialize(),
        ),
        BlocProvider<ExploreCubit>(create: (_) => ExploreCubit()),
        BlocProvider<UserCubit>(create: (_) => UserCubit()),
        BlocProvider<FavoritesCubit>(create: (_) => FavoritesCubit()),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        // RuntimeConfigCubit mirrors RuntimeConfigService. Widgets read
        // values via BlocBuilder / context.watch; the underlying service
        // is the source of truth that TtsService and RoutingService also
        // read from. Initialised here so any descendant can subscribe
        // without an extra Provider indirection.
        BlocProvider<RuntimeConfigCubit>(create: (_) => RuntimeConfigCubit()),
        BlocProvider<ActivityCubit>(
          create: (_) => ActivityCubit(firestoreService: FirestoreService()),
        ),
      ],
      child: BlocListener<LocalizationCubit, LocalizationState>(
        // Listen for four distinct signals from LocalizationCubit:
        //   1. ttsFallback — the requested voice isn't installed
        //   2. ttsPreviewEndedAt — free-tier playback hit its time cap
        //   3. ttsEngineError — native TTS plugin reported a failure
        //   4. invalidLanguageNotice — a setLanguage() call asked for an
        //      unsupported code; we silently fell back to English
        // Each emits a one-shot SnackBar; we clear the signal after so
        // rebuilds don't re-fire the listener.
        listenWhen: (prev, curr) {
          final fallbackFired =
              curr.ttsFallback != null && prev.ttsFallback != curr.ttsFallback;
          final previewFired =
              curr.ttsPreviewEndedAt != null &&
              prev.ttsPreviewEndedAt != curr.ttsPreviewEndedAt;
          final engineErrorFired =
              curr.ttsEngineError != null &&
              prev.ttsEngineError != curr.ttsEngineError;
          return fallbackFired || previewFired || engineErrorFired;
        },
        listener: (context, locState) {
          final messenger = _rootMessengerKey.currentState;
          if (messenger == null) return;
          final locCubit = context.read<LocalizationCubit>();

          // Engine errors take priority — they're the most actionable
          // ("no network", "voice unavailable") and shouldn't be
          // obscured by a softer fallback message.
          if (locState.ttsEngineError != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Audio playback failed: ${locState.ttsEngineError}',
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            locCubit.clearTtsEngineError();
            return;
          }

          if (locState.ttsPreviewEndedAt != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    '${locState.ttsPreviewEndedAt}-second preview ended — upgrade for the full tour.',
                  ),
                  // The Upgrade action turns the preview-ended notice
                  // from a passive message into the highest-converting
                  // surface for the paywall. Before this, the user had
                  // to find the persistent UpgradeBanner on the detail
                  // screen by eye — which most didn't.
                  action: SnackBarAction(
                    label: 'Upgrade',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UpgradeScreen(),
                        ),
                      );
                    },
                  ),
                  duration: const Duration(seconds: 6),
                ),
              );
            locCubit.clearTtsPreviewEnded();
            return;
          }

          if (locState.ttsFallback != null) {
            final spoken = LanguageMeta.name(locState.ttsFallback!);
            // For UI-language changes ttsFallbackRequested ==
            // currentLanguage; for audio-language changes via
            // SiteDetailCubit it can differ — use it so the message
            // names what the user actually picked.
            final requested = LanguageMeta.name(
              locState.ttsFallbackRequested ?? locState.currentLanguage,
            );
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    '$requested voice not installed — playing in $spoken.',
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            locCubit.clearTtsFallback();
            return;
          }

          // Catch up on any invalid-language notice that setLanguage
          // queued. Belt-and-braces: this fires from a BlocListener
          // (which only re-fires on a state change), so a notice set
          // between state changes is read on the next emit.
          final invalid = locCubit.consumeInvalidLanguageNotice();
          if (invalid != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('"$invalid" is not supported — using English.'),
                  duration: const Duration(seconds: 4),
                ),
              );
          }
        },
        child: BlocBuilder<LocalizationCubit, LocalizationState>(
          builder: (context, locState) {
            return BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return MaterialApp(
                  title: 'Stone Town Guide',
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  scaffoldMessengerKey: _rootMessengerKey,
                  debugShowCheckedModeBanner: false,
                  // Force RTL layout for Arabic (and any future RTL locale). The
                  // translations map is already language-specific; the locale-aware
                  // directionality wrapper makes alignment, scroll direction and
                  // icon mirroring behave correctly.
                  builder: (context, child) {
                    return ResponsiveBreakpoints.builder(
                      child: Directionality(
                        textDirection: directionFor(locState.currentLanguage),
                        child: child ?? const SizedBox.shrink(),
                      ),
                      breakpoints: [
                        const Breakpoint(
                          start: 0,
                          end: AppBreakpoints.mobile,
                          name: MOBILE,
                        ),
                        const Breakpoint(
                          start: AppBreakpoints.mobile + 1,
                          end: AppBreakpoints.tablet,
                          name: TABLET,
                        ),
                        const Breakpoint(
                          start: AppBreakpoints.tablet + 1,
                          end: AppBreakpoints.desktop,
                          name: DESKTOP,
                        ),
                        const Breakpoint(
                          start: AppBreakpoints.desktop + 1,
                          end: double.infinity,
                          name: '4K',
                        ),
                      ],
                    );
                  },
                  home: const _SystemBarsRoot(child: SplashScreen()),
                  routes: {
                    '/welcome':
                        (context) =>
                            const _SystemBarsRoot(child: WelcomeScreen()),
                    '/home':
                        (context) => const _SystemBarsRoot(child: HomeScreen()),
                    '/favorites':
                        (context) =>
                            const _SystemBarsRoot(child: FavoritesScreen()),
                    '/admin':
                        (context) => const _SystemBarsRoot(child: AdminShell()),
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Wraps [child] in an [AnnotatedRegion] whose system-bar style matches
/// the current [Theme.of] brightness. Light icons on dark surfaces, dark
/// icons on light surfaces. The status-bar background is left transparent
/// — edge-to-edge mode lets the scaffold paint behind it.
class _SystemBarsRoot extends StatelessWidget {
  const _SystemBarsRoot({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Android: dark icons when the theme is light, light icons when dark.
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      // iOS uses the inverse — `Brightness.dark` here means *dark* text.
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(value: overlay, child: child);
  }
}
