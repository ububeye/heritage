import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/premium/premium_cubit.dart';
import '../widgets/pricing_card.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Go Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
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
              const SizedBox(height: 24),
              const Text(
                'Unlock the Full Experience',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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
              const _BenefitItem(
                icon: Icons.block,
                text: 'No ads',
              ),
              const SizedBox(height: 32),
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
                          : const Text('Start Free Trial'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Cancel anytime',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSubscribe(BuildContext context, {required bool isMonthly}) async {
    await context.read<PremiumCubit>().subscribe();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Premium!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
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
              color: AppColors.success.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.success,
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