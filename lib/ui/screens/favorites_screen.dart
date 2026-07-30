import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../blocs/favorites/favorites_cubit.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/site_model.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: BlocBuilder<LocalizationCubit, LocalizationState>(
          builder: (context, loc) => Text(
            loc.translations['favorites'] ?? 'Favorites',
          ),
        ),
      ),
      body: BlocBuilder<FavoritesCubit, FavoritesState>(
        builder: (context, favState) {
          if (favState.favoriteIds.isEmpty) {
            return BlocBuilder<LocalizationCubit, LocalizationState>(
              builder: (context, loc) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translations['no_favorites'] ?? 'No favorites yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          loc.translations['no_favorites_hint'] ??
                              'Tap the heart icon on any site to add it to your favorites',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }

          return BlocBuilder<SiteListCubit, SiteListState>(
            builder: (context, siteState) {
              if (siteState.status == SiteListStatus.loading) {
                return Center(
                  child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary),
                );
              }

              // Use O(1) lookups to build the favorites list
              final favoriteSites = favState.favoriteIds
                  .map((id) => siteState.sitesById[id])
                  .whereType<SiteModel>()
                  .toList();

              if (favoriteSites.isEmpty) {
                return BlocBuilder<LocalizationCubit, LocalizationState>(
                  builder: (context, loc) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 80,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loc.translations['no_favorites'] ?? 'No favorites yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.translations['no_favorites_hint'] ??
                                'Tap the heart icon on any site to add it to your favorites',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: favoriteSites.length,
                itemBuilder: (context, index) {
                  final site = favoriteSites[index];
                  final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;
                  final loc = context.read<LocalizationCubit>().state;

                  return _FavoriteSiteCard(
                    site: site,
                    uiLanguage: uiLanguage,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(siteId: site.id),
                        ),
                      );
                    },
                    onRemove: () {
                      context.read<FavoritesCubit>().removeFavorite(site.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc.translations['removed_from_favorites'] ??
                                '${site.getName(uiLanguage)} removed from favorites',
                          ),
                          action: SnackBarAction(
                            label: loc.translations['undo'] ?? 'Undo',
                            onPressed: () {
                              context.read<FavoritesCubit>().addFavorite(site.id);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteSiteCard extends StatelessWidget {

  const _FavoriteSiteCard({
    required this.site,
    required this.uiLanguage,
    required this.onTap,
    required this.onRemove,
  });
  final SiteModel site;
  final String uiLanguage;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // Card shadow uses the theme-aware semantic shadow tone.
              color: context.semanticColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: site.primaryImage,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 120,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.secondary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                // Remove button — sits over the hero image. The white
                // pill background and red heart render the love-state on
                // top of any photograph.
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        // Solid white pill sits over the hero image so
                        // the heart stays legible on any photograph.
                        color: context.semanticColors.onImage,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite,
                        // Heart = love/like state — mapped to the success
                        // semantic role per the migration rules.
                        color: context.semanticColors.success,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // Category badge
                if (site.category != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // Badge sits over the photo — scrim background
                        // and fixed-content foreground for legibility.
                        color: context.semanticColors.imageScrim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        site.category!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: context.semanticColors.onImage),
                      ),
                    ),
                  ),
              ],
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.getName(uiLanguage),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            site.displayAddress,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
