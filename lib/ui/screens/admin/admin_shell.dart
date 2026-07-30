import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../blocs/site_list/site_list_cubit.dart';
import '../../../blocs/site_list/site_list_state.dart';
import '../../../blocs/user/user_cubit.dart';
import '../../../blocs/auth/auth_cubit.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../blocs/activity/activity_cubit.dart';
import '../../../blocs/activity/activity_state.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/runtime_config_service.dart';
import '../maintenance_screen.dart';
import '../user_profile_screen.dart';
import 'admin_sites_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_analytics_screen.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<ActivityCubit>().loadActivities();
  }

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    // Maintenance gate for non-admin users who reach the shell via a
    // deep link (notification, share, etc.) that bypasses the splash
    // gate. Admins always see the shell so they can disable the toggle.
    // We read AuthCubit here — the shell already depends on it for the
    // dashboard — so the gate rebuilds on auth changes (e.g. an admin
    // signing out during maintenance shouldn't be locked out).
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isAdmin = authState.user?.role == UserRole.admin;
        final inMaintenance = RuntimeConfigService.instance.maintenanceMode;
        if (inMaintenance && !isAdmin) {
          return const MaintenanceScreen();
        }
        return _buildShell(context);
      },
    );
  }

  Widget _buildShell(BuildContext context) {
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
          context.read<ActivityCubit>().loadActivities();
        },
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeHeader(locState: locState, tr: tr),
              const SizedBox(height: 32),
              _StatsRowContainer(locState: locState, tr: tr),
              const SizedBox(height: 40),
              _QuickActionsGrid(
                locState: locState,
                tr: tr,
                onNavigateToTab: onNavigateToTab,
              ),
              const SizedBox(height: 40),
              _RecentActivities(locState: locState, tr: tr),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.locState, required this.tr});
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(locState, 'admin_welcome'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              authState.user?.email ?? 'Admin',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

class _StatsRowContainer extends StatelessWidget {
  const _StatsRowContainer({required this.locState, required this.tr});
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: BlocBuilder<SiteListCubit, SiteListState>(
                builder: (context, state) {
                  return _StatItem(
                    value: state.sites.length.toString(),
                    label: tr(locState, 'best_places'),
                  );
                },
              ),
            ),
            VerticalDivider(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              thickness: 1,
              width: 1,
            ),
            Expanded(
              child: BlocBuilder<UserCubit, UserState>(
                builder: (context, state) {
                  return _StatItem(
                    value: state.totalUsers.toString(),
                    label: tr(locState, 'user_management'),
                  );
                },
              ),
            ),
            VerticalDivider(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              thickness: 1,
              width: 1,
            ),
            Expanded(
              child: BlocBuilder<UserCubit, UserState>(
                builder: (context, state) {
                  return _StatItem(
                    value: state.premiumUsers.toString(),
                    label:
                        tr(locState, 'premium_users') == 'premium_users'
                            ? 'Premium Users'
                            : tr(locState, 'premium_users'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
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
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            _QuickActionTile(
              icon: Icons.add_location,
              label: tr(locState, 'add_site'),
              onTap: () => onNavigateToTab(1), // Nav to Sites
            ),
            _QuickActionTile(
              icon: Icons.analytics,
              label: tr(locState, 'analytics'),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminAnalyticsScreen(),
                    ),
                  ),
            ),

            _QuickActionTile(
              icon: Icons.settings,
              label: tr(locState, 'admin_tab_settings'),
              onTap: () => onNavigateToTab(3), // Nav to Settings
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.mdBorder,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivities extends StatelessWidget {
  const _RecentActivities({required this.locState, required this.tr});
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  @override
  Widget build(BuildContext context) {
    // Stub for recent activities. In a real app this would be driven by a Cubit.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<ActivityCubit, ActivityState>(
          builder: (context, state) {
            if (state.status == ActivityStatus.loading && state.activities.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.activities.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppRadius.lgBorder,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'No recent activities.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.lgBorder,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
                boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: state.activities.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final activity = state.activities[index];
                  IconData icon;
                  switch (activity.type) {
                    case 'user_registered':
                      icon = Icons.person_add;
                      break;
                    case 'site_updated':
                      icon = Icons.edit_location_alt;
                      break;
                    case 'premium_upgrade':
                      icon = Icons.star;
                      break;
                    default:
                      icon = Icons.notifications;
                  }
                  
                  // Simple relative time formatter
                  final difference = DateTime.now().difference(activity.timestamp);
                  String timeAgo = 'Just now';
                  if (difference.inDays > 0) {
                    timeAgo = '${difference.inDays}d ago';
                  } else if (difference.inHours > 0) {
                    timeAgo = '${difference.inHours}h ago';
                  } else if (difference.inMinutes > 0) {
                    timeAgo = '${difference.inMinutes}m ago';
                  }

                  return _ActivityTile(
                    icon: icon,
                    title: activity.title,
                    subtitle: activity.subtitle,
                    time: timeAgo,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: Text(
        time,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
