import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

import '../../blocs/premium/premium_cubit.dart';
import '../../blocs/premium/premium_state.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/faq_accordion.dart';
import '../widgets/pricing_card.dart';
import '../widgets/trial_badge.dart';

/// Controls secondary copy + which buttons appear on the upgrade screen.
enum UpgradeMode {
  /// Reached from Settings. Has a back/close button in the AppBar and
  /// shows "Restore purchases" + "Already a member? Sign in".
  settings,

  /// Reached from the first-login paywall. AppBar shows "Skip" / "Maybe
  /// later"; no restore / sign-in link.
  onboarding,
}

/// Shared content for the upgrade screen. Both [UpgradeScreen] (settings)
/// and [PremiumOfferScreen] (onboarding) render this — only the AppBar
/// and the bottom dismiss link differ by [mode].
class UpgradeContent extends StatelessWidget {
  const UpgradeContent({super.key, required this.mode, this.onSuccessDismiss});

  final UpgradeMode mode;
  final VoidCallback? onSuccessDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final onSurfaceMuted = onSurface.withValues(alpha: 0.75);

    return BlocConsumer<PremiumCubit, PremiumState>(
      listenWhen:
          (prev, next) =>
              prev.lastOutcome != next.lastOutcome ||
              (next.lastOutcome == PurchaseOutcome.success &&
                  next.lastReceiptId != prev.lastReceiptId),
      listener: (context, state) {
        if (state.lastOutcome == PurchaseOutcome.success) {
          _showSuccessDialog(context);
        }
      },
      builder: (context, state) {
        final cubit = context.read<PremiumCubit>();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(scheme: scheme),
              const SizedBox(height: 24),
              Text(
                'Unlock the full Stone Town Guide',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Audio tours in 7 languages. Turn-by-turn walking directions. '
                'Audio auto-plays the moment you arrive at a site.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onSurfaceMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TrialBadge(
                planId: state.selectedPlanId,
                afterPrice: _afterPrice(state.selectedPlanId),
                afterPriceSubtitle: _afterPriceSubtitle(state.selectedPlanId),
                trialActiveUntil: state.trialActiveUntil,
                trialDays: AppConstants.trialDays,
              ),
              const SizedBox(height: 28),
              _SectionLabel(text: 'Choose a plan'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PricingCard(
                      title: 'Monthly',
                      price: AppConstants.monthlyPrice,
                      priceSubtitle: '/month',
                      selected: state.selectedPlanId == PlanId.monthly,
                      onTap: () => cubit.selectPlan(PlanId.monthly),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PricingCard(
                      title: 'Yearly',
                      price: AppConstants.yearlyPrice,
                      priceSubtitle: '/year',
                      badge: 'Save 50%',
                      secondaryLine:
                          'Just \$${_yearlyMonthlyEquivalent().toStringAsFixed(2)} / month',
                      selected: state.selectedPlanId == PlanId.yearly,
                      onTap: () => cubit.selectPlan(PlanId.yearly),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _BenefitsList(scheme: scheme, onSurfaceMuted: onSurfaceMuted),
              const SizedBox(height: 28),
              FaqAccordion(entries: _buildFaqEntries()),
              const SizedBox(height: 24),
              if (state.hasError) _ErrorBanner(message: state.errorMessage!),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      state.isPremium || state.isLoading
                          ? null
                          : () => cubit.purchase(),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.lgBorder,
                    ),
                  ),
                  child:
                      state.isLoading
                          ? _LoadingCta(
                            label:
                                state.lastOutcome == PurchaseOutcome.pending
                                    ? 'Waiting for payment...'
                                    : 'Connecting payment...',
                          )
                          : Text(
                            state.isPremium
                                ? 'Premium active'
                                : _ctaLabel(state.selectedPlanId),
                          ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _legalCopy(state.selectedPlanId),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 16),
              if (mode == UpgradeMode.settings) _SettingsSecondaryRow(),
              if (mode == UpgradeMode.onboarding)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await cubit.skipPremiumOffer();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      'Maybe later',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------- helpers --------------------------------

  double _afterPrice(PlanId id) =>
      id == PlanId.yearly
          ? AppConstants.yearlyPrice
          : AppConstants.monthlyPrice;

  String _afterPriceSubtitle(PlanId id) =>
      id == PlanId.yearly ? '/year' : '/month';

  double _yearlyMonthlyEquivalent() => AppConstants.yearlyPrice / 12.0;

  String _ctaLabel(PlanId id) =>
      id == PlanId.yearly
          ? 'Start your 3-day free trial'
          : 'Start your 3-day free trial';

  String _legalCopy(PlanId id) {
    final unit = id == PlanId.yearly ? '/year' : '/month';
    final price =
        id == PlanId.yearly
            ? AppConstants.yearlyPrice
            : AppConstants.monthlyPrice;
    return 'Then \$${price.toStringAsFixed(2)}$unit after the trial. '
        'Cancel anytime in Google Play.';
  }

  List<FaqEntry> _buildFaqEntries() {
    return [
      const FaqEntry(
        question: 'Can I cancel anytime?',
        answer:
            'Yes — cancel from your Google Play account any time before the '
            'next billing date. Your access continues until the period ends, '
            'then the subscription stops.',
        icon: Icons.event_busy,
      ),
      const FaqEntry(
        question: 'How do I restore my purchase?',
        answer:
            'Tap "Restore purchases" below. We\'ll detect any active '
            'subscription linked to your Google account and re-apply the '
            'premium entitlement.',
        icon: Icons.restore,
      ),
      FaqEntry(
        question: 'What payment methods do you accept?',
        answer:
            '${AppConstants.acceptedPaymentMethods.join(', ')} — '
            'processed by Google Play Billing. Payment details never touch '
            'our servers.',
        icon: Icons.payment,
      ),
      FaqEntry(
        question: 'What happens after the trial?',
        answer:
            'After ${AppConstants.trialDays} days you\'ll be charged the plan '
            'price unless you cancel before. We\'ll send a reminder 48 '
            'hours before the first charge.',
        icon: Icons.alarm,
      ),
    ];
  }

  Future<void> _showSuccessDialog(BuildContext context) async {
    // Capture NavigatorState before the await so we don't reuse a
    // potentially deactivated BuildContext after the dialog returns.
    final navigator = Navigator.of(context);
    final customDismiss = onSuccessDismiss;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.sheetBorderSmBorder,
          ),
          backgroundColor: scheme.surface,
          contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 48,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to Premium',
                style: Theme.of(
                  dialogContext,
                ).textTheme.headlineLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You now have full access to audio tours, GPS '
                'navigation and offline guides.',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdBorder,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        );
      },
    );
    if (result == true) {
      if (customDismiss != null) {
        customDismiss();
      } else if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}

// ----------------------------- sub-widgets ----------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.ctaButtonBorder,
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
        ),
        child: Icon(
          Icons.workspace_premium,
          size: 60,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList({required this.scheme, required this.onSurfaceMuted});
  final ColorScheme scheme;
  final Color onSurfaceMuted;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (
        Icons.language,
        'Full audio tours in 7 languages (en, sw, fr, de, ar, it, es)',
      ),
      (Icons.directions_walk, 'GPS walking directions, turn-by-turn'),
      (Icons.play_circle_filled, 'Auto-play audio the moment you arrive'),
      (Icons.replay, 'Unlimited replays of every guide'),
      (Icons.cloud_off, 'Offline access — caches tiles & audio'),
      (Icons.block, 'No ads, ever'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'What you\'ll get',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.badgeBorder,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                _BenefitRow(
                  icon: items[i].$1,
                  text: items[i].$2,
                  scheme: scheme,
                  fg: scheme.onSurface,
                  mutedFg: onSurfaceMuted,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
    required this.scheme,
    required this.fg,
    required this.mutedFg,
  });
  final IconData icon;
  final String text;
  final ColorScheme scheme;
  final Color fg;
  final Color mutedFg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                color: fg,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppInsets.bannerInner,
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.bannerBorder,
        border: Border.all(color: scheme.error.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCta extends StatelessWidget {
  const _LoadingCta({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: scheme.onPrimary,
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _SettingsSecondaryRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<PremiumCubit>();
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => cubit.restore(),
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('Restore'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Cancel anytime · Manage subscription',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}
