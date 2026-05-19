import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../blocs/site_list/site_list_cubit.dart';
import '../../blocs/site_list/site_list_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/explore/explore_cubit.dart';
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeContent(onNavigate: _navigateToSite),
          const ExploreScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
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

  const _HomeContent({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stone Town Guide'),
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
                    state.errorMessage ?? 'Something went wrong',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<SiteListCubit>().loadSites(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final sites = state.sites;

          if (sites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_city,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No heritage sites found',
                    style: TextStyle(
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
}