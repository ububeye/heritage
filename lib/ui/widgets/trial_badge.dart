import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';

import '../../blocs/premium/premium_state.dart';

/// Front-loaded trial copy on the upgrade screen.
///
/// Renders two visual modes:
///   - pitch       — before the user taps subscribe. Shows the trial
///                   length and the price-after-trial.
///   - active      — after a successful purchase. Shows the trial time
///                   remaining and a calmer tone.
class TrialBadge extends StatelessWidget {
  const TrialBadge({
    super.key,
    required this.planId,
    required this.afterPrice,
    required this.afterPriceSubtitle,
    this.trialActiveUntil,
    required this.trialDays,
  });

  final PlanId planId;
  final double afterPrice;
  final String afterPriceSubtitle;
  final DateTime? trialActiveUntil;
  final int trialDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isActive = trialActiveUntil != null;

    final accent = scheme.secondary;
    final accentOn = scheme.onSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: AppRadius.badgeBorder,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.20),
              borderRadius: AppRadius.bannerBorder,
            ),
            child: Icon(Icons.card_giftcard, color: accentOn, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? 'Your free trial is active'
                      : 'Try free for $trialDays days',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _body(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _body() {
    if (trialActiveUntil != null) {
      final remaining = trialActiveUntil!.difference(DateTime.now());
      if (remaining.isNegative) {
        return 'Trial ended — you\'re on the ${planId == PlanId.yearly ? "yearly" : "monthly"} plan.';
      }
      final days = remaining.inHours ~/ 24;
      final hours = remaining.inHours % 24;
      return 'Renews in ${days > 0 ? "$days day${days == 1 ? "" : "s"} " : ""}${hours}h. Cancel anytime.';
    }
    return 'Then \$${afterPrice.toStringAsFixed(2)} $afterPriceSubtitle. Cancel anytime.';
  }
}
