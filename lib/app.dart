import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/rtl.dart';
import 'blocs/auth/auth_cubit.dart';
import 'blocs/site_list/site_list_cubit.dart';
import 'blocs/site_detail/site_detail_cubit.dart';
import 'blocs/navigation/navigation_cubit.dart';
import 'blocs/language/language_cubit.dart';
import 'blocs/localization/localization_cubit.dart';
import 'blocs/premium/premium_cubit.dart';
import 'blocs/explore/explore_cubit.dart';
import 'blocs/user/user_cubit.dart';
import 'blocs/favorites/favorites_cubit.dart';
import 'blocs/theme/theme_cubit.dart';
import 'data/services/auth_service.dart';
import 'data/services/billing_provider.dart';
import 'data/services/fake_billing_provider.dart';
import 'data/services/tts_service.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/favorites_screen.dart';
import 'ui/screens/admin/admin_shell.dart';

// Top-level so StoneTownApp can stay const. The key is stable for the
// lifetime of the process — there's only one MaterialApp at the root.
final GlobalKey<ScaffoldMessengerState> _rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class StoneTownApp extends StatelessWidget {
  const StoneTownApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ttsService = TtsService();

    // Singleton for now; the real RevenueCat provider will own its own
    // lifecycle. Switching providers is a one-line change here.
    final BillingProvider billing = FakeBillingProvider();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(authService: AuthService()),
        ),
        BlocProvider<SiteListCubit>(create: (_) => SiteListCubit()),
        BlocProvider<SiteDetailCubit>(
          // LocalizationCubit is registered below; SiteDetailCubit reads
          // it lazily so the create closure here is called only when the
          // first consumer accesses it (after both providers exist).
          create: (ctx) => SiteDetailCubit(
            ttsService: ttsService,
            localizationCubit: ctx.read<LocalizationCubit>(),
          ),
        ),
        BlocProvider<NavigationCubit>(create: (_) => NavigationCubit()),
        BlocProvider<LanguageCubit>(create: (_) => LanguageCubit()),
        BlocProvider<LocalizationCubit>(
          create: (_) =>
              LocalizationCubit(ttsService: ttsService)..loadTranslations(),
        ),
        // PremiumCubit depends on AuthCubit for post-purchase user refresh
        // and on the billing provider for store calls. Both are picked up
        // lazily inside the create callback so the AuthCubit instance above
        // is the same one used by the rest of the app.
        BlocProvider<PremiumCubit>(
          create: (ctx) => PremiumCubit(
            billing: billing,
            auth: ctx.read<AuthCubit>(),
          )..initialize(),
        ),
        BlocProvider<ExploreCubit>(create: (_) => ExploreCubit()),
        BlocProvider<UserCubit>(create: (_) => UserCubit()),
        BlocProvider<FavoritesCubit>(create: (_) => FavoritesCubit()),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
      ],
      child: BlocListener<LocalizationCubit, LocalizationState>(
        // Listen for two distinct TTS signals from LocalizationCubit:
        //   1. ttsFallback — the requested voice isn't installed
        //   2. ttsPreviewEndedAt — free-tier playback hit its time cap
        // Either emits a one-shot SnackBar; we clear the signal after so
        // rebuilds don't re-fire the listener.
        listenWhen: (prev, curr) {
          final fallbackFired =
              curr.ttsFallback != null && prev.ttsFallback != curr.ttsFallback;
          final previewFired = curr.ttsPreviewEndedAt != null &&
              prev.ttsPreviewEndedAt != curr.ttsPreviewEndedAt;
          return fallbackFired || previewFired;
        },
        listener: (context, locState) {
          final messenger = _rootMessengerKey.currentState;
          if (messenger == null) return;
          final locCubit = context.read<LocalizationCubit>();

          if (locState.ttsPreviewEndedAt != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    '${locState.ttsPreviewEndedAt}-second preview ended — upgrade for the full tour.',
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            locCubit.clearTtsPreviewEnded();
            return;
          }

          if (locState.ttsFallback != null) {
            final spoken = _languageDisplayName(locState.ttsFallback!);
            // For UI-language changes ttsFallbackRequested ==
            // currentLanguage; for audio-language changes via
            // SiteDetailCubit it can differ — use it so the message
            // names what the user actually picked.
            final requested = _languageDisplayName(
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
                    return Directionality(
                      textDirection: directionFor(locState.currentLanguage),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                  home: const _SystemBarsRoot(child: SplashScreen()),
                  routes: {
                    '/welcome': (context) =>
                        const _SystemBarsRoot(child: WelcomeScreen()),
                    '/home': (context) =>
                        const _SystemBarsRoot(child: HomeScreen()),
                    '/favorites': (context) =>
                        const _SystemBarsRoot(child: FavoritesScreen()),
                    '/admin': (context) =>
                        const _SystemBarsRoot(child: AdminShell()),
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Display name for the audio-language chip — duplicated here to avoid
  /// pulling the LanguageCubit just for label rendering. Kept in sync with
  /// the chip's own switch in detail_screen.dart / navigation_screen_open.dart.
  String _languageDisplayName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'sw':
        return 'Kiswahili';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'ar':
        return 'العربية';
      case 'it':
        return 'Italiano';
      case 'es':
        return 'Español';
      default:
        return code;
    }
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: child,
    );
  }
}
