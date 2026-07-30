import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/user_model.dart';
import '../../data/services/runtime_config_service.dart';
import '../../data/services/shared_prefs_service.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'admin/admin_shell.dart';
import 'maintenance_screen.dart';
import 'onboarding_screen.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_durations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.splash,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    // Capture cubits before any await so we don't use BuildContext across gaps.
    final languageCubit = context.read<LanguageCubit>();
    final localizationCubit = context.read<LocalizationCubit>();
    final authCubit = context.read<AuthCubit>();
    try {
      // Load language and translations
      await languageCubit.loadLanguage();
      await localizationCubit.loadTranslations();
      // Check if user was previously logged in
      await authCubit.checkAuthStatus();
    } catch (e) {
      // Continue even if there's an error
    }
  }

  void _navigateBasedOnAuth(AuthState authState) {
    if (!mounted) return;

    // Maintenance gate takes precedence over every other route so a
    // freshly-launched non-admin user never sees the explore screen
    // while maintenance is active. Admins bypass the gate — they need
    // to keep using the admin shell to disable the flag.
    //
    // We re-read on every navigation decision (not just init) so a user
    // who opens the app, leaves it for a while, and re-launches during
    // an active maintenance window still lands on the maintenance
    // screen instead of their cached route.
    final inMaintenance = RuntimeConfigService.instance.maintenanceMode;
    final isAdmin =
        authState.user?.role == UserRole.admin;
    if (inMaintenance && !isAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
      );
      return;
    }

    // First-launch onboarding takes precedence over auth routing so the
    // user sees the app intro before any sign-in screen.
    if (SharedPrefsService.instance.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen(isFirstLaunch: true)),
      );
      return;
    }

    if (authState.status == AuthStatus.authenticated && authState.user != null) {
      // User is logged in - navigate to appropriate screen
      if (authState.user!.role == UserRole.admin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminShell()),
        );
      } else {
        // For regular users, check premium offer status
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      // User not logged in - show welcome screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Navigate when auth state changes to authenticated/unauthenticated
        if (state.status == AuthStatus.authenticated ||
            state.status == AuthStatus.unauthenticated) {
          _navigateBasedOnAuth(state);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: AppRadius.heroImageBorder,
                              boxShadow: [
                                // TODO(#pr-follow-up): migrate to AppShadows.* with custom blur/offset
                                BoxShadow(
                                  // Logo shadow — theme-aware.
                                  color: context.semanticColors.shadow,
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: AppRadius.heroImageBorder,
                              child: Image.asset(
                                'assets/images/logo.jpeg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Text(
                            'Stone Town Guide',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: 32,
                                  color: Theme.of(context).textTheme.displayLarge?.color,
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Text(
                            'Explore Zanzibar\'s Heritage',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                  letterSpacing: 0.5,
                                ),
                          ),
                        ),
                        const SizedBox(height: 80),
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
