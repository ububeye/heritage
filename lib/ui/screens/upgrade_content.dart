import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/premium/premium_cubit.dart';
import '../../blocs/premium/premium_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/faq_accordion.dart';
import '../widgets/payment_method_icons.dart';
import '../widgets/trial_badge.dart';
import 'payment_sheet.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Controls secondary copy + which buttons appear on the upgrade screen.
enum UpgradeMode {
  /// Reached from Settings.
  settings,

  /// Reached from the first-login paywall.
  onboarding,
}

/// Shared content for the upgrade screen. Both [UpgradeScreen] (settings)
/// and [PremiumOfferScreen] (onboarding) render this.
class UpgradeContent extends StatelessWidget {
  const UpgradeContent({super.key, required this.mode, this.onSuccessDismiss});

  final UpgradeMode mode;
  final VoidCallback? onSuccessDismiss;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PremiumCubit, PremiumState>(
      listenWhen: (prev, next) =>
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
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final muted = scheme.onSurface.withValues(alpha: 0.65);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero gradient banner ──────────────────────────────────────
              _GradientHero(scheme: scheme),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),

                    // ── Headline ────────────────────────────────────────────
                    Text(
                      'Unlock the Full Stone Town Guide',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Audio tours in 7 languages · GPS turn-by-turn navigation\n'
                      'Auto-play audio on arrival · No ads, ever',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.6,
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

                    const SizedBox(height: 32),

                    // ── 3-Plan cards ────────────────────────────────────────
                    _SectionLabel(text: 'Choose your plan'),
                    const SizedBox(height: 14),
                    _ThreePlanRow(
                      selected: state.selectedPlanId,
                      onSelect: (id) => cubit.selectPlan(id),
                    ),

                    const SizedBox(height: 32),

                    // ── Benefits list ───────────────────────────────────────
                    _BenefitsList(scheme: scheme, muted: muted),
                    const SizedBox(height: 28),

                    // ── FAQ ─────────────────────────────────────────────────
                    FaqAccordion(entries: _buildFaqEntries()),
                    const SizedBox(height: 28),

                    // ── Error banner ────────────────────────────────────────
                    if (state.hasError) _ErrorBanner(message: state.errorMessage!),

                    // ── Primary CTA ─────────────────────────────────────────
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed:
                            state.isPremium
                                ? null
                                : () => PaymentSheet.push(
                                  context,
                                  state.selectedPlanId,
                                ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.lgBorder,
                          ),
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          elevation: 2,
                        ),
                        child:
                            state.isPremium
                                ? const Text(
                                  'Premium active ✓',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.lock,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _ctaLabel(state.selectedPlanId),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      _legalCopy(state.selectedPlanId),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),

                    const SizedBox(height: 20),

                    // ── Payment brand icons ──────────────────────────────────
                    const PaymentBrandRow(iconHeight: 28),

                    const SizedBox(height: 20),

                    // ── Secondary actions ────────────────────────────────────
                    if (mode == UpgradeMode.settings) _SettingsSecondaryRow(),
                    if (mode == UpgradeMode.onboarding)
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            await cubit.skipPremiumOffer();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: Text(
                            'Maybe later',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _afterPrice(PlanId id) {
    switch (id) {
      case PlanId.monthly:
        return AppConstants.explorerMonthlyPrice;
      case PlanId.yearly:
        return AppConstants.explorerYearlyPrice;
      case PlanId.proMonthly:
        return AppConstants.proMonthlyPrice;
      case PlanId.proYearly:
        return AppConstants.proYearlyPrice;
      case PlanId.lifetime:
        return AppConstants.lifetimePrice;
    }
  }

  String _afterPriceSubtitle(PlanId id) {
    if (id == PlanId.lifetime) return 'one-time';
    return id == PlanId.yearly || id == PlanId.proYearly ? '/year' : '/month';
  }

  String _ctaLabel(PlanId id) {
    if (id == PlanId.lifetime) return 'Get Lifetime Access';
    return 'Start ${AppConstants.trialDays}-day free trial';
  }

  String _legalCopy(PlanId id) {
    if (id == PlanId.lifetime) {
      return 'One-time purchase · No recurring charges · Instant access';
    }
    final unit = (id == PlanId.yearly || id == PlanId.proYearly) ? '/year' : '/month';
    final price = _afterPrice(id);
    return 'Then \$${price.toStringAsFixed(2)}$unit after the trial. Cancel anytime.';
  }

  List<FaqEntry> _buildFaqEntries() {
    return [
      const FaqEntry(
        question: 'What plans are available?',
        answer:
            'Explorer (\$4.99/mo) for casual visitors, Pro (\$9.99/mo or '
            '\$59.99/yr) for researchers and repeat visitors, and Lifetime '
            '(\$49.99) for local guides and superfans who want permanent access.',
        icon: Icons.layers,
      ),
      const FaqEntry(
        question: 'Can I cancel anytime?',
        answer:
            'Yes — cancel from your device\'s subscription manager any time '
            'before the next billing date. Access continues until the period ends.',
        icon: Icons.event_busy,
      ),
      const FaqEntry(
        question: 'How do I restore my purchase?',
        answer:
            'Tap "Restore purchases" below. We\'ll detect any active subscription '
            'and re-apply premium access.',
        icon: Icons.restore,
      ),
      FaqEntry(
        question: 'What payment methods do you accept?',
        answer:
            '${AppConstants.acceptedPaymentMethods.join(', ')} — '
            'all transactions are encrypted and secure.',
        icon: PhosphorIconsRegular.creditCard,
      ),
      FaqEntry(
        question: 'What happens after the trial?',
        answer:
            'After ${AppConstants.trialDays} days you\'ll be charged the plan '
            'price unless you cancel first. We\'ll send a reminder 48 hours before.',
        icon: Icons.alarm,
      ),
    ];
  }

  Future<void> _showSuccessDialog(BuildContext context) async {
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
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Welcome to Premium!',
                style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'All 7 audio languages are now unlocked.\nGPS navigation and offline guides are active.',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 18),
              // Unlocked language chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: const [
                  _LangChip('🇬🇧 English'),
                  _LangChip('🇹🇿 Swahili'),
                  _LangChip('🇫🇷 French'),
                  _LangChip('🇩🇪 German'),
                  _LangChip('🇸🇦 Arabic'),
                  _LangChip('🇮🇹 Italian'),
                  _LangChip('🇪🇸 Spanish'),
                ],
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
                  backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                  foregroundColor:
                      Theme.of(dialogContext).colorScheme.onPrimary,
                ),
                child: const Text(
                  'Start Exploring',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Hero gradient banner
// ─────────────────────────────────────────────────────────────────────────────

class _GradientHero extends StatelessWidget {
  const _GradientHero({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.7),
            scheme.secondary,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: _DecoCircle(size: 140, opacity: 0.12),
          ),
          Positioned(
            bottom: -20,
            left: -10,
            child: _DecoCircle(size: 100, opacity: 0.10),
          ),
          Positioned(
            top: 30,
            left: 60,
            child: _DecoCircle(size: 60, opacity: 0.08),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '✦ STONE TOWN PREMIUM ✦',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecoCircle extends StatelessWidget {
  const _DecoCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-plan card row
// ─────────────────────────────────────────────────────────────────────────────

class _ThreePlanRow extends StatelessWidget {
  const _ThreePlanRow({required this.selected, required this.onSelect});
  final PlanId selected;
  final ValueChanged<PlanId> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top row: Explorer (month+year) — 2 compact cards side-by-side
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                tier: 'EXPLORER',
                title: 'Monthly',
                priceLabel: '\$${AppConstants.explorerMonthlyPrice.toStringAsFixed(2)}',
                period: '/month',
                selected: selected == PlanId.monthly,
                onTap: () => onSelect(PlanId.monthly),
                color: const Color(0xFF6366F1),
                features: const ['7 languages', 'GPS nav', 'No ads'],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PlanCard(
                tier: 'EXPLORER',
                title: 'Yearly',
                priceLabel: '\$${AppConstants.explorerYearlyPrice.toStringAsFixed(2)}',
                period: '/year',
                badge: 'Save 17%',
                selected: selected == PlanId.yearly,
                onTap: () => onSelect(PlanId.yearly),
                color: const Color(0xFF6366F1),
                features: const ['7 languages', 'GPS nav', 'No ads'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Pro — full-width, highlighted (recommended)
        _PlanCardFeatured(
          selected: selected == PlanId.proMonthly || selected == PlanId.proYearly,
          selectedId: selected,
          onSelectMonthly: () => onSelect(PlanId.proMonthly),
          onSelectYearly: () => onSelect(PlanId.proYearly),
        ),

        const SizedBox(height: 12),

        // Lifetime — full-width
        _LifetimeCard(
          selected: selected == PlanId.lifetime,
          onTap: () => onSelect(PlanId.lifetime),
        ),
      ],
    );
  }
}

// ── Small plan card ───────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.title,
    required this.priceLabel,
    required this.period,
    required this.selected,
    required this.onTap,
    required this.color,
    required this.features,
    this.badge,
  });
  final String tier;
  final String title;
  final String priceLabel;
  final String period;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final List<String> features;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: selected ? color : scheme.outline.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: AppRadius.xsBorder,
                  ),
                  child: Text(
                    tier,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondary,
                      borderRadius: AppRadius.xsBorder,
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: scheme.onSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: priceLabel,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: selected ? color : scheme.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: period,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      f,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pro featured card (full-width with monthly/yearly toggle) ─────────────────

class _PlanCardFeatured extends StatelessWidget {
  const _PlanCardFeatured({
    required this.selected,
    required this.selectedId,
    required this.onSelectMonthly,
    required this.onSelectYearly,
  });
  final bool selected;
  final PlanId selectedId;
  final VoidCallback onSelectMonthly;
  final VoidCallback onSelectYearly;

  static const _color = Color(0xFFF59E0B); // amber

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMonthly = selectedId == PlanId.proMonthly;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? _color.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(
          color: selected ? _color : scheme.outline.withValues(alpha: 0.35),
          width: selected ? 2.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _color.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIconsFill.star, size: 13, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'MOST POPULAR — PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 6),
                Icon(PhosphorIconsFill.star, size: 13, color: Colors.white),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                // Price toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onSelectMonthly,
                        child: _PriceToggleChip(
                          label: 'Monthly',
                          price:
                              '\$${AppConstants.proMonthlyPrice.toStringAsFixed(2)}/mo',
                          selected: selected && isMonthly,
                          color: _color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onSelectYearly,
                        child: _PriceToggleChip(
                          label: 'Yearly',
                          price:
                              '\$${AppConstants.proYearlyPrice.toStringAsFixed(2)}/yr',
                          selected: selected && !isMonthly,
                          color: _color,
                          badge: 'Save 50%',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Features grid
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    _FeatureChip('7 languages'),
                    _FeatureChip('GPS navigation'),
                    _FeatureChip('Auto-play audio'),
                    _FeatureChip('Offline mode'),
                    _FeatureChip('No ads'),
                    _FeatureChip('Unlimited replays'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceToggleChip extends StatelessWidget {
  const _PriceToggleChip({
    required this.label,
    required this.price,
    required this.selected,
    required this.color,
    this.badge,
  });
  final String label;
  final String price;
  final bool selected;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? color : scheme.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: selected ? color : scheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : scheme.onSurface,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: AppRadius.xsBorder,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white.withValues(alpha: 0.9)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: AppRadius.fullBorder,
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_rounded,
            size: 12,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lifetime card ─────────────────────────────────────────────────────────────

class _LifetimeCard extends StatelessWidget {
  const _LifetimeCard({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  static const _color = Color(0xFF8B5CF6); // purple

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? _color.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: selected ? _color : scheme.outline.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.all_inclusive, color: _color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'LIFETIME',
                        style: TextStyle(
                          color: _color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.15),
                          borderRadius: AppRadius.xsBorder,
                        ),
                        child: const Text(
                          'BEST VALUE',
                          style: TextStyle(
                            color: _color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '\$${AppConstants.lifetimePrice.toStringAsFixed(2)} ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: selected ? _color : scheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: 'one-time',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Full access forever. No renewals.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _color : scheme.outline,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.10),
        borderRadius: AppRadius.fullBorder,
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF22C55E),
        ),
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList({required this.scheme, required this.muted});
  final ColorScheme scheme;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (PhosphorIconsRegular.globe, 'Full audio tours in 7 languages'),
      (PhosphorIconsRegular.personSimpleWalk, 'GPS walking directions, turn-by-turn'),
      (Icons.play_circle_filled, 'Auto-play audio the moment you arrive'),
      (Icons.replay, 'Unlimited replays of every guide'),
      (Icons.cloud_off, 'Offline access — caches tiles & audio'),
      (PhosphorIconsRegular.prohibit, 'No ads, ever'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'What you\'ll get'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(items[i].$1, color: scheme.primary, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          items[i].$2,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
          Icon(PhosphorIconsRegular.warningCircle, color: scheme.error, size: 20),
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
