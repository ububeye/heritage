import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/explore/explore_cubit.dart';
import '../../blocs/favorites/favorites_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/site_model.dart';
import 'detail_screen.dart';
import 'explore_screen.dart';
import 'settings_screen.dart';
import '../widgets/site_card.dart';
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
              KeepAlivePage(child: _HomeContent(onNavigate: _navigateToSite, locState: locState)),
              const KeepAlivePage(child: ExploreScreen()),
              const KeepAlivePage(child: SettingsScreen()),
            ],
          ),
          // M3 NavigationBar. Uses the themed indicator pill + 72dp
          // height we added to AppTheme — drops the legacy M2
          // BottomNavigationBar so the user shell matches the admin
          // shell, which already migrated in PR-A.
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              _pageController.jumpToPage(index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
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
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: _tr(locState, 'settings'),
                tooltip: _tr(locState, 'settings'),
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

  void _navigateToSite(SiteModel site) {
    safePushNavigation(context, site);
  }
}

class _HomeContent extends StatelessWidget {

  const _HomeContent({required this.onNavigate, required this.locState});
  final Function(SiteModel) onNavigate;
  final LocalizationState locState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_tr(locState, 'stone_town_guide')),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: _tr(locState, 'favorites'),
            onPressed: () => Navigator.of(context).pushNamed('/favorites'),
          ),
        ],
      ),
      body: BlocBuilder<SiteListCubit, SiteListState>(
        builder: (context, state) {
          if (state.status == SiteListStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          if (state.status == SiteListStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? _tr(locState, 'error_generic'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<SiteListCubit>().loadSites(),
                    child: Text(_tr(locState, 'retry')),
                  ),
                ],
              ),
            );
          }

          final sites = state.sites;

          if (sites.isEmpty) {
            return Center(
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
                    _tr(locState, 'best_places'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<SiteListCubit>().loadSites(),
            color: AppColors.accent,
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: sites.length,
              itemBuilder: (context, index) {
                final site = sites[index];
                final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;

                return SiteCard(
                  site: site,
                  uiLanguage: uiLanguage,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(siteId: site.id),
                    ),
                  ),
                  onNavigate: () => onNavigate(site),
                  isInItinerary: context.read<ExploreCubit>().isInItinerary(site.id),
                  isFavorite: context.read<FavoritesCubit>().isFavorite(site.id),
                  onToggleFavorite: () => context.read<FavoritesCubit>().toggleFavorite(site.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }
}

class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({super.key, required this.child});
  final Widget child;

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
