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
import 'data/services/tts_service.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/favorites_screen.dart';
import 'ui/screens/admin/admin_shell.dart';

class StoneTownApp extends StatelessWidget {
  const StoneTownApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ttsService = TtsService();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(authService: AuthService()),
        ),
        BlocProvider<SiteListCubit>(create: (_) => SiteListCubit()),
        BlocProvider<SiteDetailCubit>(
          create: (_) => SiteDetailCubit(ttsService: ttsService),
        ),
        BlocProvider<NavigationCubit>(create: (_) => NavigationCubit()),
        BlocProvider<LanguageCubit>(create: (_) => LanguageCubit()),
        BlocProvider<LocalizationCubit>(
          create: (_) => LocalizationCubit()..loadTranslations(),
        ),
        BlocProvider<PremiumCubit>(create: (_) => PremiumCubit()),
        BlocProvider<ExploreCubit>(create: (_) => ExploreCubit()),
        BlocProvider<UserCubit>(create: (_) => UserCubit()),
        BlocProvider<FavoritesCubit>(create: (_) => FavoritesCubit()),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
      ],
      child: BlocBuilder<LocalizationCubit, LocalizationState>(
        builder: (context, locState) {
          return BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return MaterialApp(
                title: 'Stone Town Guide',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: child,
    );
  }
}
