import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../blocs/site_list/site_list_cubit.dart';
import '../../../blocs/site_list/site_list_state.dart';
import '../../../blocs/user/user_cubit.dart';
import '../../../blocs/auth/auth_cubit.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../blocs/localization/localization_cubit.dart';
import 'admin_sites_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_analytics_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _AdminDashboard(
                locState: locState,
                tr: _tr,
                onNavigateToTab: (i) => setState(() => _currentIndex = i),
              ),
              const AdminSitesScreen(),
              const AdminUserManagementScreen(),
              const AdminSettingsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: _tr(locState, 'admin_tab_home'),
                tooltip: _tr(locState, 'admin_tab_home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.location_city_outlined),
                selectedIcon: const Icon(Icons.location_city),
                label: _tr(locState, 'admin_tab_sites'),
                tooltip: _tr(locState, 'admin_tab_sites'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: _tr(locState, 'admin_tab_users'),
                tooltip: _tr(locState, 'admin_tab_users'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: _tr(locState, 'admin_tab_settings'),
                tooltip: _tr(locState, 'admin_tab_settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminDashboard extends StatelessWidget {

  const _AdminDashboard({
    required this.locState,
    required this.tr,
    required this.onNavigateToTab,
  });
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(tr(locState, 'admin_dashboard')),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<SiteListCubit>().loadSites();
          context.read<UserCubit>().loadUsers();
        },
        color: AppColors.accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeCard(locState: locState, tr: tr),
              const SizedBox(height: 20),
              _StatsSection(locState: locState, tr: tr),
              const SizedBox(height: 24),
              _MenuSection(
                locState: locState,
                tr: tr,
                onNavigateToTab: onNavigateToTab,
              ),
              const SizedBox(height: 24),
              _QuickActionsSection(
                locState: locState,
                tr: tr,
                onNavigateToTab: onNavigateToTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {

  const _WelcomeCard({required this.locState, required this.tr});
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(locState, 'admin_welcome'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authState.user?.email ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsSection extends StatelessWidget {

  const _StatsSection({required this.locState, required this.tr});
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BlocBuilder<SiteListCubit, SiteListState>(
            builder: (context, state) {
              return _StatCard(
                icon: Icons.location_city,
                value: state.sites.length.toString(),
                label: tr(locState, 'best_places'),
                color: AppColors.primary,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BlocBuilder<UserCubit, UserState>(
            builder: (context, state) {
              return _StatCard(
                icon: Icons.people,
                value: state.totalUsers.toString(),
                label: tr(locState, 'user_management'),
                color: AppColors.accent,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BlocBuilder<UserCubit, UserState>(
            builder: (context, state) {
              return _StatCard(
                icon: Icons.workspace_premium,
                value: state.premiumUsers.toString(),
                label: tr(locState, 'upgrade_to_premium'),
                color: AppColors.success,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {

  const _MenuSection({
    required this.locState,
    required this.tr,
    required this.onNavigateToTab,
  });
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: tr(locState, 'admin_dashboard_subtitle')),
        const SizedBox(height: 12),
        _MenuCard(
          icon: Icons.location_on,
          title: tr(locState, 'best_places'),
          subtitle: tr(locState, 'admin_tab_sites'),
          color: AppColors.primary,
          // Switch to the Sites tab (index 1) instead of pushing a new
          // AdminSitesScreen instance — the bottom nav stays in sync.
          onTap: () => onNavigateToTab(1),
        ),
        const SizedBox(height: 12),
        _MenuCard(
          icon: Icons.people,
          title: tr(locState, 'user_management'),
          subtitle: tr(locState, 'admin_tab_users'),
          color: AppColors.accent,
          onTap: () => onNavigateToTab(2),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {

  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint, size: 24),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {

  const _QuickActionsSection({
    required this.locState,
    required this.tr,
    required this.onNavigateToTab,
  });
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: tr(locState, 'start_audio_guide')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_location,
                label: tr(locState, 'add_site'),
                color: AppColors.primary,
                // Drop the redundant AdminSitesScreen(addNew:true) push —
                // jump to the Sites tab and rely on its own FAB for "+".
                onTap: () => onNavigateToTab(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.analytics,
                label: tr(locState, 'analytics'),
                color: AppColors.accent,
                // Analytics is a pushed screen (not a tab). Pre-existing
                // behaviour — keep it so the chip stays useful.
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}