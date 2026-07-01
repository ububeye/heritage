import 'package:flutter/material.dart';
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
                home: const SplashScreen(),
                routes: {
                  '/welcome': (context) => const WelcomeScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/favorites': (context) => const FavoritesScreen(),
                  '/admin': (context) => const AdminShell(),
                },
              );
            },
          );
        },
      ),
    );
  }
}
