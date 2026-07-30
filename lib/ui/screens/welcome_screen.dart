import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../core/theme/app_semantic_colors.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../../core/theme/app_radius.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showLanguageSelector(BuildContext context, LocalizationState locState) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_tr(locState, 'choose_language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageOption(
                languageCode: 'en',
                languageName: 'English',
                flagEmoji: '🇬🇧',
                isSelected: locState.currentLanguage == 'en',
                onTap: () {
                  context.read<LocalizationCubit>().setLanguage('en');
                  Navigator.of(dialogContext).pop();
                },
              ),
              const SizedBox(height: 8),
              _LanguageOption(
                languageCode: 'sw',
                languageName: 'Kiswahili',
                flagEmoji: '🇹🇿',
                isSelected: locState.currentLanguage == 'sw',
                onTap: () {
                  context.read<LocalizationCubit>().setLanguage('sw');
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tr(locState, 'cancel')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use a scroll view when the viewport is too short to fit
                // logo + two spacers + buttons. Two `Spacer`s in a fixed
                // Column overflow on small / landscape phones.
                final isCompact = constraints.maxHeight < 700;
                final content = AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Language selector at top
                            Align(
                              alignment: Alignment.topRight,
                              child: Transform.translate(
                                offset: Offset(0, _slideAnimation.value),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showLanguageSelector(
                                      context,
                                      locState,
                                    ),
                                    borderRadius: AppRadius.ctaButtonBorder,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        borderRadius: AppRadius.ctaButtonBorder,
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.language,
                                            color: Theme.of(context)
                                                .iconTheme
                                                .color,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            locState.currentLanguage == 'en'
                                                ? 'EN'
                                                : 'SW',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(fontSize: 13),
                                          ),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            color: Theme.of(context)
                                                .iconTheme
                                                .color
                                                ?.withValues(alpha: 0.8),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isCompact) const Spacer(),
                            Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: AppRadius.heroGreetingBorder,
                                  boxShadow: [
                                    BoxShadow(
                                      // Logo shadow — theme-aware.
                                      color: context.semanticColors.shadow,
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: AppRadius.heroGreetingBorder,
                                  child: Image.asset(
                                    'assets/images/logo.jpeg',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),
                            Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Text(
                                _tr(locState, 'stone_town_guide'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(letterSpacing: 1.2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Text(
                                _tr(locState, 'welcome_subtitle'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.8),
                                      height: 1.5,
                                    ),
                              ),
                            ),
                            if (!isCompact) const Spacer() else
                              const SizedBox(height: 32),
                            Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.of(context)
                                          .push(
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              AppRadius.lgBorder,
                                        ),
                                      ),
                                      child: Text(_tr(locState, 'login')),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context)
                                          .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              AppRadius.lgBorder,
                                        ),
                                      ),
                                      child: Text(_tr(locState, 'register')),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    );
                  },
                );

                return isCompact
                    ? SingleChildScrollView(child: content)
                    : content;
              },
            ),
          ),
        );
      },
    );
  }

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.languageCode,
    required this.languageName,
    required this.flagEmoji,
    required this.isSelected,
    required this.onTap,
  });
  final String languageCode;
  final String languageName;
  final String flagEmoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.mdBorder,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              flagEmoji,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontSize: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                languageName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
