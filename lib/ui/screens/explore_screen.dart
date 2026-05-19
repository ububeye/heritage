import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../blocs/explore/explore_cubit.dart';
import '../../blocs/language/language_cubit.dart';
import '../../data/models/site_model.dart';
import '../widgets/site_card.dart';
import '../widgets/featured_site_card.dart';
import '../widgets/category_chips.dart';
import '../widgets/search_bar_widget.dart';
import 'detail_screen.dart';
import 'navigation_screen.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Explore'),
        actions: [
          BlocBuilder<ExploreCubit, ExploreState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(state.isMapView ? Icons.list : Icons.map),
                onPressed: () => context.read<ExploreCubit>().toggleMapView(),
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
              onChanged: (query) => context.read<SiteListCubit>().search(query),
            ),
          ),
          const SizedBox(height: 8),
          CategoryChips(
            categories: AppConstants.siteCategories,
            selectedCategory: _selectedCategory,
            onSelected: (category) {
              setState(() => _selectedCategory = category);
              context.read<SiteListCubit>().filterByCategory(category);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<SiteListCubit, SiteListState>(
              builder: (context, state) {
                if (state.status == SiteListStatus.loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final sites = state.filteredSites;
                if (sites.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text(
                          'No places found',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return BlocBuilder<ExploreCubit, ExploreState>(
                  builder: (context, exploreState) {
                    final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;

                    if (exploreState.isMapView) {
                      return _MapView(
                        sites: sites,
                        uiLanguage: uiLanguage,
                        onSiteTap: (site) => _navigateToDetail(site),
                        onNavigate: (site) => _navigateToNav(site),
                      );
                    }

                    return _ListView(
                      sites: sites,
                      uiLanguage: uiLanguage,
                      featuredSite: sites.isNotEmpty ? sites.first : null,
                      onSiteTap: (site) => _navigateToDetail(site),
                      onNavigate: (site) => _navigateToNav(site),
                      onFeaturedNavigate: (site) => _navigateToNav(site),
                      onFeaturedAudio: (site) => _navigateToDetail(site),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(SiteModel site) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(siteId: site.id)),
    );
  }

  void _navigateToNav(SiteModel site) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NavigationScreen(site: site)),
    );
  }
}

class _ListView extends StatelessWidget {
  final List<SiteModel> sites;
  final String uiLanguage;
  final SiteModel? featuredSite;
  final Function(SiteModel) onSiteTap;
  final Function(SiteModel) onNavigate;
  final Function(SiteModel) onFeaturedNavigate;
  final Function(SiteModel) onFeaturedAudio;

  const _ListView({
    required this.sites,
    required this.uiLanguage,
    this.featuredSite,
    required this.onSiteTap,
    required this.onNavigate,
    required this.onFeaturedNavigate,
    required this.onFeaturedAudio,
  });

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Best Places',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
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
  final SiteModel site;
  final String uiLanguage;
  final bool isInItinerary;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback onToggleItinerary;

  const _SiteCardWithItinerary({
    required this.site,
    required this.uiLanguage,
    required this.isInItinerary,
    required this.onTap,
    required this.onNavigate,
    required this.onToggleItinerary,
  });

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
  final List<SiteModel> sites;
  final String uiLanguage;
  final Function(SiteModel) onSiteTap;
  final Function(SiteModel) onNavigate;

  const _MapView({
    required this.sites,
    required this.uiLanguage,
    required this.onSiteTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'Map View',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${sites.length} sites available',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<ExploreCubit>().setMapView(false),
            child: const Text('Switch to List View'),
          ),
        ],
      ),
    );
  }
}