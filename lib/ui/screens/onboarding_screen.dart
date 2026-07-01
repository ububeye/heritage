import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/services/shared_prefs_service.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {

  const OnboardingScreen({super.key, this.isFirstLaunch = false});
  final bool isFirstLaunch;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Build the page list from the current LocalizationState so the
  /// onboarding copy honours the user's chosen language.
  List<OnboardingPage> _buildPages(LocalizationState loc) => [
        OnboardingPage(
          icon: Icons.location_city,
          title: loc.translations['onboarding_p1_title'] ?? 'Explore Heritage',
          subtitle: loc.translations['onboarding_p1_subtitle'] ??
              "Discover the rich history and culture of Stone Town, Zanzibar's UNESCO World Heritage Site",
          color: AppColors.primary,
        ),
        OnboardingPage(
          icon: Icons.headphones,
          title: loc.translations['onboarding_p2_title'] ?? 'Audio Guides',
          subtitle: loc.translations['onboarding_p2_subtitle'] ??
              'Listen to fascinating stories and history in 7 languages with our audio guide',
          color: AppColors.accent,
        ),
        OnboardingPage(
          icon: Icons.navigation,
          title: loc.translations['onboarding_p3_title'] ?? 'GPS Navigation',
          subtitle: loc.translations['onboarding_p3_subtitle'] ??
              'Navigate to sites with turn-by-turn directions and auto-play audio when you arrive',
          color: AppColors.success,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    SharedPrefsService.instance.setFirstLaunchComplete();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, loc) {
        final pages = _buildPages(loc);
        final isLast = _currentPage == pages.length - 1;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      loc.translations['onboarding_skip'] ?? 'Skip',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      return _OnboardingPageWidget(page: pages[index]);
                    },
                  ),
                ),
                // Language selection
                _LanguageSelector(),
                // Bottom controls
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page indicators
                      Row(
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      // Next/Get Started button
                      ElevatedButton(
                        onPressed: isLast ? _completeOnboarding : _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          isLast
                              ? (loc.translations['onboarding_get_started'] ??
                                  'Get Started')
                              : (loc.translations['onboarding_next'] ?? 'Next'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPageWidget extends StatelessWidget {

  const _OnboardingPageWidget({required this.page});
  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),
          const SizedBox(height: 48),
          // Title
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            page.subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.language, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text(
                'Language:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.currentLanguage,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'en',
                        child: Row(
                          children: [
                            Text('🇬🇧 '),
                            Text('English'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'sw',
                        child: Row(
                          children: [
                            Text('🇹🇿 '),
                            Text('Kiswahili'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (lang) {
                      if (lang != null) {
                        context.read<LocalizationCubit>().setLanguage(lang);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OnboardingPage {

  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}