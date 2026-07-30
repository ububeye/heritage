import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Selection-aware pricing card. Used on the upgrade screen for both
/// the monthly and yearly plan.
///
/// Visual states:
///   - unselected / not popular  → subtle outlined card, neutral text
///   - popular (recommended)     → primary-tinted border + soft glow
///   - selected                  → thicker primary border + checkmark
///                                 regardless of "popular"
class PricingCard extends StatelessWidget {
  const PricingCard({
    super.key,
    required this.title,
    required this.price,
    required this.priceSubtitle,
    this.badge,
    required this.onTap,
    this.selected = false,
    this.secondaryLine,
  });

  /// 'Monthly' / 'Yearly'
  final String title;

  /// e.g. 4.99
  final double price;

  /// e.g. '/month'
  final String priceSubtitle;

  /// Optional small badge — 'Popular' for the default recommended plan,
  /// 'Best value' for yearly, etc.
  final String? badge;

  /// Secondary line under the price — for yearly we show
  /// 'Just $2.49 / month'.
  final String? secondaryLine;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPrimary = selected;
    final bg = isPrimary
        ? scheme.primary
        : scheme.surface;
    final fg = isPrimary ? scheme.onPrimary : scheme.onSurface;
    final muted = isPrimary
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurface.withValues(alpha: 0.7);
    final borderColor = isPrimary ? scheme.primary : theme.dividerColor;
    final borderWidth = isPrimary ? 2.0 : 1.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.circular(AppRadius.card),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: AppInsets.pillTiny,
                    decoration: BoxDecoration(
                      color: scheme.secondary,
                      borderRadius: AppRadius.bannerBorder,
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSecondary,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 28,
                        color: fg,
                      ),
                ),
                const SizedBox(width: 2),
                Text(
                  priceSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: muted,
                      ),
                ),
              ],
            ),
            if (secondaryLine != null) ...[
              const SizedBox(height: 6),
              Text(
                secondaryLine!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
