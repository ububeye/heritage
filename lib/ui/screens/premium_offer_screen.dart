import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/premium/premium_cubit.dart';
import '../widgets/pricing_card.dart';
import 'home_screen.dart';

class PremiumOfferScreen extends StatelessWidget {
  const PremiumOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withAlpha(102),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 50,
                  color: AppColors.textOnAccent,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Unlock Premium',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Get the full experience with all features',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              const _BenefitItem(
                icon: Icons.language,
                text: 'Full audio tours in 7 languages',
              ),
              const _BenefitItem(
                icon: Icons.navigation,
                text: 'GPS navigation with auto-play',
              ),
              const _BenefitItem(
                icon: Icons.replay,
                text: 'Unlimited replays',
              ),
              const _BenefitItem(
                icon: Icons.cloud_off,
                text: 'Offline access (coming soon)',
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: PricingCard(
                      title: 'Monthly',
                      price: AppConstants.monthlyPrice,
                      subtitle: '/month',
                      onTap: () => _onSubscribe(context, isMonthly: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PricingCard(
                      title: 'Yearly',
                      price: AppConstants.yearlyPrice,
                      subtitle: '/year',
                      isPopular: true,
                      onTap: () => _onSubscribe(context, isMonthly: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BlocBuilder<PremiumCubit, PremiumState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: AppConstants.minTouchTarget,
                    child: ElevatedButton(
                      onPressed: state.isLoading ? null : () => _onSubscribe(context, isMonthly: true),
                      child: state.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.textOnAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Start 3-Day Free Trial'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _onSkip(context),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _onSubscribe(BuildContext context, {required bool isMonthly}) async {
    await context.read<PremiumCubit>().subscribe();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _onSkip(BuildContext context) async {
    await context.read<PremiumCubit>().skipPremiumOffer();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}