import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/explore/explore_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/site_model.dart';
import 'detail_screen.dart';
import 'navigation_screen.dart';
import 'explore_screen.dart';
import 'settings_screen.dart';
import '../widgets/site_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<SiteListCubit>().loadSites();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _HomeContent(onNavigate: _navigateToSite, locState: locState),
              const ExploreScreen(),
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: _tr(locState, 'home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.explore_outlined),
                activeIcon: const Icon(Icons.explore),
                label: _tr(locState, 'explore'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                activeIcon: const Icon(Icons.settings),
                label: _tr(locState, 'settings'),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(site: site),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final Function(SiteModel) onNavigate;
  final LocalizationState locState;

  const _HomeContent({required this.onNavigate, required this.locState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_tr(locState, 'stone_town_guide')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
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
                    style: const TextStyle(color: AppColors.textSecondary),
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
                  const Icon(
                    Icons.location_city,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _tr(locState, 'best_places'),
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
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
              padding: const EdgeInsets.all(16),
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