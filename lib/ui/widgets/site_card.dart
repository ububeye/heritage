import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/colors.dart';
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
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
                      top: Radius.circular(AppConstants.cardBorderRadius),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: site.getTransformedImageUrl(
                        transformation: 'w_400,c_fill,q_auto,f_auto',
                      ),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surfaceDark,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surfaceDark,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),

                  // Favorite button
                  if (onToggleFavorite != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onToggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppColors.textOnAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  loc.translations['added_to_itinerary'] ?? 'Added',
                                  style: const TextStyle(
                                    fontSize: 10,
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.rating,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            site.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.navigation,
                                size: 16,
                                color: AppColors.textOnAccent,
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
