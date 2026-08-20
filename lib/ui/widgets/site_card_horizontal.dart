import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/site_model.dart';

/// Compact vertical card for horizontal-scroll rows on the Home screen.
///
/// Dimensions: 164 × 220 px. Shows the site image, a translucent gradient
/// scrim at the bottom, the site name, category badge, and a small navigate
/// button. Designed to feel like the Airbnb / Google Travel card style.
class SiteCardHorizontal extends StatelessWidget {
  const SiteCardHorizontal({
    super.key,
    required this.site,
    required this.uiLanguage,
    required this.onTap,
    this.onNavigate,
    this.badge,
  });

  final SiteModel site;
  final String uiLanguage;
  final VoidCallback onTap;
  final VoidCallback? onNavigate;

  /// Optional badge text drawn over the image (e.g. "New", "Top Rated").
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 164,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgBorder,
          boxShadow: AppShadows.mediumFor(Theme.of(context).brightness),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.lgBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Hero image ──────────────────────────────────────────────
              CachedNetworkImage(
                imageUrl: site.getTransformedImageUrl(
                  transformation: 'w_400,c_fill,q_auto,f_auto',
                ),
                fit: BoxFit.cover,
                placeholder:
                    (_, __) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.secondary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                errorWidget:
                    (_, __, ___) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
              ),

              // ── Bottom gradient scrim ────────────────────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        context.semanticColors.imageScrim,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Top-left badge (New / Top Rated / etc.) ─────────────────
              if (badge != null)
                Positioned(
                  top: AppSpacing.xs,
                  left: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

              // ── Top-right rating pill ─────────────────────────────────────
              if (site.rating != null)
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: context.semanticColors.imageScrim,
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsFill.star,
                          size: 11,
                          color: context.semanticColors.rating,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          site.rating!.toStringAsFixed(1),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: context.semanticColors.onImage,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom content row ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    0,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category pill
                      if (site.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: AppRadius.xsBorder,
                          ),
                          child: Text(
                            SiteCategories.getLabel(site.category!),
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: context.semanticColors.onImage,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      // Name + navigate button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              site.getName(uiLanguage),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: context.semanticColors.onImage,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (onNavigate != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: onNavigate,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: AppShadows.lowFor(
                                    Theme.of(context).brightness,
                                  ),
                                ),
                                child: Icon(
                                  PhosphorIconsFill.navigationArrow,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
