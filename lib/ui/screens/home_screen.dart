import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/explore/explore_cubit.dart';
import '../../blocs/favorites/favorites_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/site_model.dart';
import 'detail_screen.dart';
import 'explore_screen.dart';
import 'settings_screen.dart';
import '../widgets/home_section_header.dart';
import '../widgets/site_card.dart';
import '../widgets/site_card_horizontal.dart';
import '../../core/utils/nav_guard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToExplore() {
    setState(() => _currentIndex = 1);
    _pageController.jumpToPage(1);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        return Scaffold(
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: [
              KeepAlivePage(
                child: _HomeContent(
                  onNavigateToSite: _navigateToSite,
                  onGoToExplore: _goToExplore,
                  locState: locState,
                ),
              ),
              const KeepAlivePage(child: ExploreScreen()),
              const KeepAlivePage(child: SettingsScreen()),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              _pageController.jumpToPage(index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(PhosphorIconsRegular.house),
                selectedIcon: const Icon(PhosphorIconsRegular.house),
                label: _tr(locState, 'home'),
                tooltip: _tr(locState, 'home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: _tr(locState, 'explore'),
                tooltip: _tr(locState, 'explore'),
              ),
              NavigationDestination(
                icon: const Icon(PhosphorIconsRegular.gear),
                selectedIcon: const Icon(PhosphorIconsRegular.gear),
                label: _tr(locState, 'settings'),
                tooltip: _tr(locState, 'settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _tr(LocalizationState state, String key) =>
      state.translations[key] ?? key;

  void _navigateToSite(SiteModel site) {
    safePushNavigation(context, site);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Home content — discovery feed
// ─────────────────────────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.onNavigateToSite,
    required this.onGoToExplore,
    required this.locState,
  });

  final Function(SiteModel) onNavigateToSite;
  final VoidCallback onGoToExplore;
  final LocalizationState locState;

  String _tr(String key) => locState.translations[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SiteListCubit, SiteListState>(
      builder: (context, state) {
        // ── Loading ──────────────────────────────────────────────────────────
        if (state.status == SiteListStatus.loading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: _buildAppBar(context),
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        // ── Error ────────────────────────────────────────────────────────────
        if (state.status == SiteListStatus.error) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: _buildAppBar(context),
            body: _ErrorBody(
              message: state.errorMessage ?? _tr('error_generic'),
              retryLabel: _tr('retry'),
            ),
          );
        }

        final sites = state.sites;

        // ── Derive section data ───────────────────────────────────────────────
        SiteModel? featured;
        try {
          featured = sites.firstWhere((s) => s.featured);
        } catch (_) {
          featured = sites.isNotEmpty ? sites.first : null;
        }

        // Recently Added — sort by createdAt desc, take 6.
        final recentlySorted = List<SiteModel>.from(sites)
          ..sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });
        final recentlyAdded = recentlySorted.take(6).toList();

        // Recommended — sort by rating desc (nulls last), take 6.
        final recommendedSorted = List<SiteModel>.from(sites)
          ..sort((a, b) {
            if (a.rating == null && b.rating == null) return 0;
            if (a.rating == null) return 1;
            if (b.rating == null) return -1;
            return b.rating!.compareTo(a.rating!);
          });
        final recommended =
            recommendedSorted
                .where((s) => s.rating != null)
                .take(6)
                .toList();

        return BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, favState) {
            final favourites =
                sites
                    .where((s) => favState.favoriteIds.contains(s.id))
                    .toList();

            final uiLanguage = locState.currentLanguage;

            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: RefreshIndicator(
                onRefresh: () => context.read<SiteListCubit>().loadSites(),
                color: Theme.of(context).colorScheme.primary,
                child: CustomScrollView(
                  slivers: [
                    // ── Sticky SliverAppBar ─────────────────────────────────
                    SliverAppBar(
                      automaticallyImplyLeading: false,
                      pinned: true,
                      floating: false,
                      title: Text(_tr('stone_town_guide')),
                      actions: [
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.heart),
                          tooltip: _tr('favorites'),
                          onPressed:
                              () => Navigator.of(context).pushNamed(
                                '/favorites',
                              ),
                        ),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(56),
                        child: _SearchShortcut(
                          hint: _tr('search_places'),
                          onTap: onGoToExplore,
                        ),
                      ),
                    ),

                    // ── Hero Banner ─────────────────────────────────────────
                    if (featured != null)
                      SliverToBoxAdapter(
                        child: _HeroBanner(
                          site: featured,
                          uiLanguage: uiLanguage,
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => DetailScreen(siteId: featured!.id),
                                ),
                              ),
                          onNavigate: () => onNavigateToSite(featured!),
                        ),
                      ),

                    // ── Category Quick-Picks ────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                          bottom: AppSpacing.xs,
                        ),
                        child: _CategoryRow(onGoToExplore: onGoToExplore),
                      ),
                    ),

                    // ── Recently Added ──────────────────────────────────────
                    if (recentlyAdded.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.lg,
                            bottom: AppSpacing.sm,
                          ),
                          child: HomeSectionHeader(
                            title: 'Recently Added',
                            seeAllLabel: 'See all',
                            onSeeAll: onGoToExplore,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _HorizontalSiteRow(
                          sites: recentlyAdded,
                          uiLanguage: uiLanguage,
                          badge: 'New',
                          onTap:
                              (s) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DetailScreen(siteId: s.id),
                                ),
                              ),
                          onNavigate: onNavigateToSite,
                        ),
                      ),
                    ],

                    // ── Recommended For You ─────────────────────────────────
                    if (recommended.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.lg,
                            bottom: AppSpacing.sm,
                          ),
                          child: HomeSectionHeader(
                            title: 'Recommended',
                            seeAllLabel: 'See all',
                            onSeeAll: onGoToExplore,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _HorizontalSiteRow(
                          sites: recommended,
                          uiLanguage: uiLanguage,
                          badge: '⭐ Top Rated',
                          onTap:
                              (s) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DetailScreen(siteId: s.id),
                                ),
                              ),
                          onNavigate: onNavigateToSite,
                        ),
                      ),
                    ],

                    // ── Your Favourites ─────────────────────────────────────
                    if (favourites.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.lg,
                            bottom: AppSpacing.sm,
                          ),
                          child: HomeSectionHeader(
                            title: 'Your Favourites',
                            seeAllLabel: 'View all',
                            onSeeAll:
                                () =>
                                    Navigator.of(context).pushNamed(
                                      '/favorites',
                                    ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _HorizontalSiteRow(
                          sites: favourites,
                          uiLanguage: uiLanguage,
                          onTap:
                              (s) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DetailScreen(siteId: s.id),
                                ),
                              ),
                          onNavigate: onNavigateToSite,
                        ),
                      ),
                    ],

                    // ── All Sites section header ─────────────────────────────
                    if (sites.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.lg,
                            bottom: AppSpacing.sm,
                          ),
                          child: HomeSectionHeader(
                            title: 'All Sites',
                            seeAllLabel: 'Explore map',
                            onSeeAll: onGoToExplore,
                          ),
                        ),
                      ),

                      // ── All Sites 2-col grid ──────────────────────────────
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.xl +
                              MediaQuery.of(context).padding.bottom,
                        ),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final site = sites[index];
                              return SiteCard(
                                site: site,
                                uiLanguage: uiLanguage,
                                onTap:
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                DetailScreen(siteId: site.id),
                                      ),
                                    ),
                                onNavigate: () => onNavigateToSite(site),
                                isInItinerary:
                                    context
                                        .read<ExploreCubit>()
                                        .isInItinerary(site.id),
                                isFavorite:
                                    context
                                        .read<FavoritesCubit>()
                                        .isFavorite(site.id),
                                onToggleFavorite:
                                    () => context
                                        .read<FavoritesCubit>()
                                        .toggleFavorite(site.id),
                              );
                            },
                            childCount: sites.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                                childAspectRatio: 0.75,
                              ),
                        ),
                      ),
                    ],

                    // ── Empty state ─────────────────────────────────────────
                    if (sites.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_city,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _tr('best_places'),
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
          },
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(_tr('stone_town_guide')),
      actions: [
        IconButton(
          icon: const Icon(PhosphorIconsRegular.heart),
          tooltip: _tr('favorites'),
          onPressed: () => Navigator.of(context).pushNamed('/favorites'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search shortcut bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchShortcut extends StatelessWidget {
  const _SearchShortcut({required this.hint, required this.onTap});
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.fullBorder,
            boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.site,
    required this.uiLanguage,
    required this.onTap,
    required this.onNavigate,
  });
  final SiteModel site;
  final String uiLanguage;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 240,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.xlBorder,
          boxShadow: AppShadows.mediumFor(Theme.of(context).brightness),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.xlBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              CachedNetworkImage(
                imageUrl: site.getTransformedImageUrl(
                  transformation: 'w_900,c_fill,q_auto,f_auto',
                ),
                fit: BoxFit.cover,
                placeholder:
                    (_, __) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                errorWidget:
                    (_, __, ___) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Theme.of(context).colorScheme.outline,
                        size: 48,
                      ),
                    ),
              ),

              // Gradient scrim
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.3, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),

              // Featured pill top-left
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: AppRadius.fullBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsFill.star,
                        size: 12,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Featured',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rating top-right
              if (site.rating != null)
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsFill.star,
                          size: 13,
                          color: const Color(0xFFFFD700),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          site.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom text + CTA
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (site.category != null)
                              Text(
                                SiteCategories.getLabel(site.category!),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              site.getName(uiLanguage),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              site.displayAddress,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Navigate CTA
                      GestureDetector(
                        onTap: onNavigate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: AppRadius.fullBorder,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsFill.navigationArrow,
                                size: 14,
                                color:
                                    Theme.of(context).colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Navigate',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Category quick-pick chips
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.onGoToExplore});
  final VoidCallback onGoToExplore;

  static const _categories = <String, _CatMeta>{
    'historic': _CatMeta(PhosphorIconsRegular.buildings, 'Historic'),
    'cultural': _CatMeta(PhosphorIconsRegular.palette, 'Cultural'),
    'religious': _CatMeta(PhosphorIconsRegular.mosque, 'Religious'),
    'museum': _CatMeta(PhosphorIconsRegular.frameCorners, 'Museum'),
    'market': _CatMeta(PhosphorIconsRegular.shoppingBag, 'Market'),
    'natural_landmark': _CatMeta(PhosphorIconsRegular.tree, 'Nature'),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.md),
          child: Text(
            'Explore by Category',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              ..._categories.entries.map(
                (e) => _CategoryChip(
                  label: e.value.label,
                  icon: e.value.icon,
                  onTap: () {
                    // Switch to Explore and filter by category.
                    onGoToExplore();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatMeta {
  const _CatMeta(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: color.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal scroll row of SiteCardHorizontal
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalSiteRow extends StatelessWidget {
  const _HorizontalSiteRow({
    required this.sites,
    required this.uiLanguage,
    required this.onTap,
    required this.onNavigate,
    this.badge,
  });

  final List<SiteModel> sites;
  final String uiLanguage;
  final Function(SiteModel) onTap;
  final Function(SiteModel) onNavigate;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 226,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: sites.length,
        itemBuilder: (context, index) {
          final site = sites[index];
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: SiteCardHorizontal(
              site: site,
              uiLanguage: uiLanguage,
              badge: badge,
              onTap: () => onTap(site),
              onNavigate: () => onNavigate(site),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error body
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.retryLabel});
  final String message;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<SiteListCubit>().loadSites(),
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KeepAlivePage
// ─────────────────────────────────────────────────────────────────────────────

class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({super.key, required this.child});
  final Widget child;

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
