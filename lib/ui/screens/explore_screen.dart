import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../blocs/explore/explore_cubit.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../core/theme/app_durations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/nav_guard.dart';
import '../../data/models/site_model.dart';
import '../widgets/category_chips.dart';
import '../widgets/featured_site_card.dart';
import '../widgets/heritage_map.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/site_card.dart';
import 'detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String? category) {
    setState(() => _selectedCategory = category);
    context.read<SiteListCubit>().filterByCategory(category);
  }

  void _navigateToDetail(SiteModel site) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(siteId: site.id)),
    );
  }

  void _navigateToNav(SiteModel site) {
    safePushNavigation(context, site);
  }

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: BlocBuilder<ExploreCubit, ExploreState>(
            builder: (context, exploreState) {
              final isMapView = exploreState.isMapView;
              final key = isMapView ? 'view_list' : 'view_map';
              final label = _tr(locState, key);
              return FloatingActionButton.extended(
                onPressed: () => context.read<ExploreCubit>().toggleMapView(),
                icon: Icon(isMapView ? Icons.list : PhosphorIconsRegular.mapTrifold),
                label: Text(label),
              );
            },
          ),
          body: BlocBuilder<SiteListCubit, SiteListState>(
            builder: (context, siteState) {
              if (siteState.status == SiteListStatus.loading) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                );
              }

              final sites = siteState.filteredSites;
              SiteModel? featuredSite;
              if (_selectedCategory == null && sites.isNotEmpty) {
                try {
                  featuredSite = sites.firstWhere((s) => s.featured);
                } catch (_) {
                  featuredSite = sites.first;
                }
              }

              return BlocBuilder<ExploreCubit, ExploreState>(
                builder: (context, exploreState) {
                  return AnimatedSwitcher(
                    duration: AppDurations.normal,
                    child: exploreState.isMapView
                        ? _ExploreMapView(
                            key: const ValueKey('map'),
                            sites: sites,
                            searchController: _searchController,
                            selectedCategory: _selectedCategory,
                            onCategorySelected: _onCategorySelected,
                            locState: locState,
                            onSiteTap: _navigateToDetail,
                          )
                        : _ExploreListView(
                            key: const ValueKey('list'),
                            sites: sites,
                            featuredSite: featuredSite,
                            searchController: _searchController,
                            selectedCategory: _selectedCategory,
                            onCategorySelected: _onCategorySelected,
                            locState: locState,
                            onSiteTap: _navigateToDetail,
                            onNavigate: _navigateToNav,
                          ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List View (Modernized CustomScrollView)
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreListView extends StatelessWidget {
  const _ExploreListView({
    super.key,
    required this.sites,
    this.featuredSite,
    required this.searchController,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.locState,
    required this.onSiteTap,
    required this.onNavigate,
  });

  final List<SiteModel> sites;
  final SiteModel? featuredSite;
  final TextEditingController searchController;
  final String? selectedCategory;
  final Function(String?) onCategorySelected;
  final LocalizationState locState;
  final Function(SiteModel) onSiteTap;
  final Function(SiteModel) onNavigate;

  String _tr(String key) => locState.translations[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final uiLanguage = locState.currentLanguage;
    final exploreCubit = context.read<ExploreCubit>();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          pinned: true,
          title: Text(_tr('explore')),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SearchBarWidget(
                controller: searchController,
                hintText: _tr('search_places'),
                onChanged: (query) =>
                    context.read<SiteListCubit>().search(query),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: CategoryChips(
              categories: SiteCategories.all,
              selectedCategory: selectedCategory,
              onSelected: onCategorySelected,
              locState: locState,
            ),
          ),
        ),
        if (sites.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.magnifyingGlassMinus,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _tr('no_results'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        if (sites.isNotEmpty && featuredSite != null) ...[
          SliverToBoxAdapter(
            child: FeaturedSiteCard(
              site: featuredSite!,
              uiLanguage: uiLanguage,
              onTap: () => onSiteTap(featuredSite!),
              onViewMap: () => onNavigate(featuredSite!),
              onStartAudio: () => onSiteTap(featuredSite!),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                _tr('best_places'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
        ],
        if (sites.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // FAB clearance
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final siteIndex = featuredSite != null ? index + 1 : index;
                  if (siteIndex >= sites.length) return const SizedBox();
                  final site = sites[siteIndex];
                  return SiteCard(
                    site: site,
                    uiLanguage: uiLanguage,
                    isInItinerary: exploreCubit.isInItinerary(site.id),
                    onTap: () => onSiteTap(site),
                    onNavigate: () => onNavigate(site),
                    onToggleItinerary: () {
                      if (exploreCubit.isInItinerary(site.id)) {
                        exploreCubit.removeFromItinerary(site.id);
                      } else {
                        exploreCubit.addToItinerary(site.id);
                      }
                    },
                  );
                },
                childCount:
                    featuredSite != null ? sites.length - 1 : sites.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map View (Full-bleed with floating UI)
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreMapView extends StatelessWidget {
  const _ExploreMapView({
    super.key,
    required this.sites,
    required this.searchController,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.locState,
    required this.onSiteTap,
  });

  final List<SiteModel> sites;
  final TextEditingController searchController;
  final String? selectedCategory;
  final Function(String?) onCategorySelected;
  final LocalizationState locState;
  final Function(SiteModel) onSiteTap;

  String _tr(String key) => locState.translations[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. The Map
        HeritageMap.browse(
          sites: sites,
          onSiteTap: onSiteTap,
        ),
        // 2. Floating Search and Categories
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  SearchBarWidget(
                    controller: searchController,
                    hintText: _tr('search_places'),
                    onChanged: (query) =>
                        context.read<SiteListCubit>().search(query),
                  ),
                  const SizedBox(height: 12),
                  CategoryChips(
                    categories: SiteCategories.all,
                    selectedCategory: selectedCategory,
                    onSelected: onCategorySelected,
                    locState: locState,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
