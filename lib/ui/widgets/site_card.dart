import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/site_model.dart';

class SiteCard extends StatelessWidget {

  const SiteCard({
    super.key,
    required this.site,
    required this.uiLanguage,
    required this.onTap,
    this.onNavigate,
    this.isInItinerary = false,
    this.onToggleItinerary,
    this.isFavorite = false,
    this.onToggleFavorite,
  });
  final SiteModel site;
  final String uiLanguage;
  final VoidCallback onTap;
  final VoidCallback? onNavigate;
  final bool isInItinerary;
  final VoidCallback? onToggleItinerary;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              // Card shadow — theme-aware.
              color: context.semanticColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: site.getTransformedImageUrl(
                        transformation: 'w_400,c_fill,q_auto,f_auto',
                      ),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.secondary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Icon(
                          Icons.image_not_supported,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),

                  // Favorite button — sits over the site card image. The
                  // white pill keeps the heart legible on any photo.
                  if (onToggleFavorite != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: BlocBuilder<LocalizationCubit, LocalizationState>(
                        builder: (context, locState) {
                          final label = isFavorite
                              ? (locState.translations['remove_from_favorites'] ??
                                  'Remove from favorites')
                              : (locState.translations['add_to_favorites'] ??
                                  'Add to favorites');
                          return Semantics(
                            label: label,
                            button: true,
                            child: GestureDetector(
                              onTap: onToggleFavorite,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  // Pill over the hero image — fixed white.
                                  color: context.semanticColors.onImage,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      // Pill shadow — theme-aware.
                                      color: context.semanticColors.shadow,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  // Heart is the love/like state — uses
                                  // the success semantic role; the
                                  // fallback border variant stays muted
                                  // via onSurfaceVariant for contrast on
                                  // the white pill.
                                  color: isFavorite
                                      ? context.semanticColors.success
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Itinerary badge
                  if (isInItinerary)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: BlocBuilder<LocalizationCubit, LocalizationState>(
                        builder: (context, loc) {
                          return Container(
                            padding: AppInsets.tag,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: AppRadius.mdBorder,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.onSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  loc.translations['added_to_itinerary'] ?? 'Added',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textOnAccent,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name
                    Expanded(
                      child: Text(
                        site.getName(uiLanguage),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Bottom row: rating + action
                    Row(
                      children: [
                        // Rating
                        if (site.rating != null) ...[
                          Icon(
                            Icons.star,
                            size: 14,
                            color: context.semanticColors.rating,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            site.rating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ] else
                          const SizedBox(),

                        const Spacer(),

                        // Action button
                        if (onNavigate != null)
                          GestureDetector(
                            onTap: onNavigate,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                borderRadius: AppRadius.smBorder,
                              ),
                              child: Icon(
                                Icons.navigation,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                          ),
                      ],
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
