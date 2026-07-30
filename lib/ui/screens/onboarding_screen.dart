import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/services/shared_prefs_service.dart';
import 'welcome_screen.dart';
import '../../core/theme/app_radius.dart';

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
  List<OnboardingPage> _buildPages(BuildContext context, LocalizationState loc) => [
        OnboardingPage(
          icon: Icons.location_city,
          title: loc.translations['onboarding_p1_title'] ?? 'Explore Heritage',
          subtitle: loc.translations['onboarding_p1_subtitle'] ??
              "Discover the rich history and culture of Stone Town, Zanzibar's UNESCO World Heritage Site",
          color: Theme.of(context).colorScheme.primary,
        ),
        OnboardingPage(
          icon: Icons.headphones,
          title: loc.translations['onboarding_p2_title'] ?? 'Audio Guides',
          subtitle: loc.translations['onboarding_p2_subtitle'] ??
              'Listen to fascinating stories and history in 7 languages with our audio guide',
          color: Theme.of(context).colorScheme.secondary,
        ),
        OnboardingPage(
          icon: Icons.navigation,
          title: loc.translations['onboarding_p3_title'] ?? 'GPS Navigation',
          subtitle: loc.translations['onboarding_p3_subtitle'] ??
              'Navigate to sites with turn-by-turn directions and auto-play audio when you arrive',
          color: context.semanticColors.success,
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
        final pages = _buildPages(context, loc);
        final isLast = _currentPage == pages.length - 1;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
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
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                              borderRadius: AppRadius.xsBorder,
                            ),
                          ),
                        ),
                      ),
                      // Next/Get Started button
                      ElevatedButton(
                        onPressed: isLast ? _completeOnboarding : _nextPage,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.ctaButtonBorder,
                          ),
                        ),
                        child: Text(
                          isLast
                              ? (loc.translations['onboarding_get_started'] ??
                                  'Get Started')
                              : (loc.translations['onboarding_next'] ?? 'Next'),
                          style: Theme.of(context).textTheme.labelLarge,
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
            style: Theme.of(context).textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            page.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.mdBorder,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Language:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
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
