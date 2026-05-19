import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'blocs/auth/auth_cubit.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/site_list/site_list_cubit.dart';
import 'blocs/site_detail/site_detail_cubit.dart';
import 'blocs/navigation/navigation_cubit.dart';
import 'blocs/language/language_cubit.dart';
import 'blocs/premium/premium_cubit.dart';
import 'blocs/explore/explore_cubit.dart';
import 'data/services/auth_service.dart';
import 'data/services/tts_service.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/admin/admin_dashboard_screen.dart';

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
        BlocProvider<SiteListCubit>(
          create: (_) => SiteListCubit(),
        ),
        BlocProvider<SiteDetailCubit>(
          create: (_) => SiteDetailCubit(ttsService: ttsService),
        ),
        BlocProvider<NavigationCubit>(
          create: (_) => NavigationCubit(),
        ),
        BlocProvider<LanguageCubit>(
          create: (_) => LanguageCubit(),
        ),
        BlocProvider<PremiumCubit>(
          create: (_) => PremiumCubit(),
        ),
        BlocProvider<ExploreCubit>(
          create: (_) => ExploreCubit(),
        ),
      ],
      child: MaterialApp(
        title: 'Stone Town Guide',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/home': (context) => const HomeScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
        },
        builder: (context, child) {
          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state.status == AuthStatus.unauthenticated) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/welcome',
                  (route) => false,
                );
              } else if (state.status == AuthStatus.authenticated) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              }
            },
            child: child,
          );
        },
      ),
    );
  }
}