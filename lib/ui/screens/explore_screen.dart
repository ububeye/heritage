import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../blocs/explore/explore_cubit.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/site_model.dart';
import '../widgets/site_card.dart';
import '../widgets/featured_site_card.dart';
import '../widgets/category_chips.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/heritage_map.dart';
import 'detail_screen.dart';
import '../../core/utils/nav_guard.dart';
import '../../core/theme/app_spacing.dart';

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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(_tr(locState, 'explore')),
            actions: [
              BlocBuilder<ExploreCubit, ExploreState>(
                builder: (context, state) {
                  final locState = context.watch<LocalizationCubit>().state;
                  final key = state.isMapView ? 'view_list' : 'view_map';
                  final label = locState.translations[key] ?? key;
                  return Semantics(
                    label: label,
                    button: true,
                    child: IconButton(
                      icon: Icon(state.isMapView ? Icons.list : Icons.map),
                      tooltip: label,
                      onPressed: () => context.read<ExploreCubit>().toggleMapView(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SearchBarWidget(
                  controller: _searchController,
                  hintText: _tr(locState, 'search_places'),
                  onChanged: (query) => context.read<SiteListCubit>().search(query),
                ),
              ),
              const SizedBox(height: 8),
              BlocBuilder<LocalizationCubit, LocalizationState>(
                builder: (context, locState) {
                  return CategoryChips(
                    categories: SiteCategories.all,
                    selectedCategory: _selectedCategory,
                    onSelected: (category) {
                      setState(() => _selectedCategory = category);
                      context.read<SiteListCubit>().filterByCategory(category);
                    },
                    locState: locState,
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BlocBuilder<SiteListCubit, SiteListState>(
                  builder: (context, state) {
                    if (state.status == SiteListStatus.loading) {
                      return Center(
                        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary),
                      );
                    }

                    final sites = state.filteredSites;
                    if (sites.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            // The previous copy here showed the
                            // search-hint string ('Search places…'),
                            // which is misleading under a magnifier-off
                            // icon — there's nothing to search, the
                            // filter has no matches.
                            Text(
                              _tr(locState, 'no_results'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    return BlocBuilder<ExploreCubit, ExploreState>(
                      builder: (context, exploreState) {
                        final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;

                        // Featured site pinning (B-08): prefer sites explicitly
                        // marked `featured: true` in Firestore, fall back to
                        // the first item in the list.
                        SiteModel? featuredSite;
                        if (_selectedCategory == null && sites.isNotEmpty) {
                          try {
                            featuredSite = sites.firstWhere((s) => s.featured);
                          } catch (_) {
                            featuredSite = sites.first;
                          }
                        }

                        return IndexedStack(
                          index: exploreState.isMapView ? 0 : 1,
                          children: [
                            _MapView(
                              sites: sites,
                              uiLanguage: uiLanguage,
                              onSiteTap: (site) => _navigateToDetail(site),
                              onNavigate: (site) => _navigateToNav(site),
                              locState: locState,
                            ),
                            _ListView(
                              sites: sites,
                              uiLanguage: uiLanguage,
                              featuredSite: featuredSite,
                              onSiteTap: (site) => _navigateToDetail(site),
                              onNavigate: (site) => _navigateToNav(site),
                              onFeaturedNavigate: (site) => _navigateToNav(site),
                              onFeaturedAudio: (site) => _navigateToDetail(site),
                              locState: locState,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  void _navigateToDetail(SiteModel site) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(siteId: site.id)),
    );
  }

  void _navigateToNav(SiteModel site) {
    safePushNavigation(context, site);
  }
}

class _ListView extends StatelessWidget {

  const _ListView({
    required this.sites,
    required this.uiLanguage,
    this.featuredSite,
    required this.onSiteTap,
    required this.onNavigate,
    required this.onFeaturedNavigate,
    required this.onFeaturedAudio,
    required this.locState,
  });
  final List<SiteModel> sites;
  final String uiLanguage;
  final SiteModel? featuredSite;
  final Function(SiteModel) onSiteTap;
  final Function(SiteModel) onNavigate;
  final Function(SiteModel) onFeaturedNavigate;
  final Function(SiteModel) onFeaturedAudio;
  final LocalizationState locState;

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final exploreCubit = context.read<ExploreCubit>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (featuredSite != null) ...[
          FeaturedSiteCard(
            site: featuredSite!,
            uiLanguage: uiLanguage,
            onTap: () => onSiteTap(featuredSite!),
            onViewMap: () => onFeaturedNavigate(featuredSite!),
            onStartAudio: () => onFeaturedAudio(featuredSite!),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _tr(locState, 'best_places'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: featuredSite != null ? sites.length - 1 : sites.length,
          itemBuilder: (context, index) {
            final siteIndex = featuredSite != null ? index + 1 : index;
            if (siteIndex >= sites.length) return const SizedBox();
            final site = sites[siteIndex];

            return _SiteCardWithItinerary(
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
        ),
      ],
    );
  }
}

class _SiteCardWithItinerary extends StatelessWidget {

  const _SiteCardWithItinerary({
    required this.site,
    required this.uiLanguage,
    required this.isInItinerary,
    required this.onTap,
    required this.onNavigate,
    required this.onToggleItinerary,
  });
  final SiteModel site;
  final String uiLanguage;
  final bool isInItinerary;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback onToggleItinerary;

  @override
  Widget build(BuildContext context) {
    return SiteCard(
      site: site,
      uiLanguage: uiLanguage,
      onTap: onTap,
      onNavigate: onNavigate,
      isInItinerary: isInItinerary,
      onToggleItinerary: onToggleItinerary,
    );
  }
}

class _MapView extends StatelessWidget {

  const _MapView({
    required this.sites,
    required this.uiLanguage,
    required this.onSiteTap,
    required this.onNavigate,
    required this.locState,
  });
  final List<SiteModel> sites;
  final String uiLanguage;
  final Function(SiteModel) onSiteTap;
  final Function(SiteModel) onNavigate;
  final LocalizationState locState;

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: HeritageMap.browse(
            sites: sites,
            onSiteTap: onSiteTap,
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: AppInsets.listItem,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '${sites.length} sites on map',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.read<ExploreCubit>().setMapView(false),
                  icon: const Icon(Icons.view_list, size: 18),
                  label: Text(_tr(locState, 'view_list')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
