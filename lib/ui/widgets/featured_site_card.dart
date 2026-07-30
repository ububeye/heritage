import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/site_model.dart';

class FeaturedSiteCard extends StatelessWidget {
  const FeaturedSiteCard({
    super.key,
    required this.site,
    required this.uiLanguage,
    required this.onTap,
    required this.onViewMap,
    required this.onStartAudio,
  });
  final SiteModel site;
  final String uiLanguage;
  final VoidCallback onTap;
  final VoidCallback onViewMap;
  final VoidCallback onStartAudio;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            // TODO(#pr-follow-up): migrate to AppShadows.* with custom blur/offset
            BoxShadow(
              // Featured-card shadow — theme-aware.
              color: context.semanticColors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: CachedNetworkImage(
                imageUrl: site.getTransformedImageUrl(
                  transformation: 'w_800,c_fill,q_auto,f_auto',
                ),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Theme.of(context).colorScheme.outline,
                        size: 48,
                      ),
                    ),
              ),
            ),
            // Hero gradient overlay — fixed scrim tone so foreground
            // colours stay legible on any photograph.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.semanticColors.imageScrim.withValues(alpha: 0.0),
                    context.semanticColors.imageScrim,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: AppInsets.pillSm,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: AppRadius.sheetBorderSmBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Featured',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        color: AppColors.textOnAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: AppInsets.tag,
                decoration: BoxDecoration(
                  // Rating pill sits over the hero image — scrim
                  // background and fixed-content foreground.
                  color: context.semanticColors.imageScrim,
                  borderRadius: AppRadius.mdBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: context.semanticColors.rating,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      site.rating?.toStringAsFixed(1) ?? '4.8',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        color: context.semanticColors.onImage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: AppInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.getName(uiLanguage),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.semanticColors.onImage,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onViewMap,
                            style: OutlinedButton.styleFrom(
                              // Button border + foreground over hero
                              // image — fixed white.
                              foregroundColor: context.semanticColors.onImage,
                              side: BorderSide(
                                color: context.semanticColors.onImage,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('View on Map'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onStartAudio,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Start Audio Guide'),
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
