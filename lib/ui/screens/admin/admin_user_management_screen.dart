import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../blocs/user/user_cubit.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementState();
}

class _AdminUserManagementState extends State<AdminUserManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Reuse the app-level UserCubit so dashboard stats stay in sync.
    // The watch stream in UserCubit will keep the list live; loadUsers() is
    // only needed on the very first navigation.
    final cubit = context.read<UserCubit>();
    if (cubit.state.users.isEmpty) {
      cubit.loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _UserManagementContent();
  }
}

class _UserManagementContent extends StatelessWidget {
  const _UserManagementContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<UserCubit>().loadUsers(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppInsets.card,
            child: BlocBuilder<UserCubit, UserState>(
              builder: (context, state) {
                return TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        state.searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed:
                                  () =>
                                      context.read<UserCubit>().searchUsers(''),
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged:
                      (value) => context.read<UserCubit>().searchUsers(value),
                );
              },
            ),
          ),
          _buildStatsBar(),
          _buildFilterAndSort(),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: AppInsets.chipTall,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.mdBorder,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                'Total',
                state.totalUsers.toString(),
                Theme.of(context).colorScheme.primary,
              ),
              _buildStatItem(
                context,
                'Premium',
                state.premiumUsers.toString(),
                Theme.of(context).colorScheme.secondary,
              ),
              _buildStatItem(
                context,
                'Admins',
                state.adminUsers.toString(),
                context.semanticColors.success,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterAndSort() {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: state.roleFilter == null,
                        onTap:
                            () => context.read<UserCubit>().setRoleFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Admins',
                        isSelected: state.roleFilter == UserRole.admin,
                        onTap:
                            () => context.read<UserCubit>().setRoleFilter(
                              UserRole.admin,
                            ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Premium',
                        isSelected: state.roleFilter == UserRole.premium,
                        onTap:
                            () => context.read<UserCubit>().setRoleFilter(
                              UserRole.premium,
                            ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Free',
                        isSelected: state.roleFilter == UserRole.free,
                        onTap:
                            () => context.read<UserCubit>().setRoleFilter(
                              UserRole.free,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: AppRadius.smBorder,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserSortOrder>(
                    value: state.sortOrder,
                    icon: const Icon(Icons.sort, size: 18),
                    style: Theme.of(context).textTheme.bodySmall,
                    items: const [
                      DropdownMenuItem(
                        value: UserSortOrder.nameAsc,
                        child: Text('A-Z'),
                      ),
                      DropdownMenuItem(
                        value: UserSortOrder.nameDesc,
                        child: Text('Z-A'),
                      ),
                      DropdownMenuItem(
                        value: UserSortOrder.newestFirst,
                        child: Text('Newest'),
                      ),
                    ],
                    onChanged: (order) {
                      if (order != null) {
                        context.read<UserCubit>().setSortOrder(order);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        if (state.status == UserStatus.loading) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.secondary,
            ),
          );
        }

        if (state.status == UserStatus.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                const Text('Failed to load users'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.read<UserCubit>().loadUsers(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final users = state.filteredUsers;

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  state.searchQuery.isEmpty
                      ? Icons.people_outline
                      : Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  state.searchQuery.isEmpty
                      ? 'No users found'
                      : 'No matching users',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<UserCubit>().loadUsers(),
          color: Theme.of(context).colorScheme.secondary,
          child: ListView.builder(
            padding: AppInsets.card,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserCard(
                user: user,
                onRoleChange:
                    (role) =>
                        context.read<UserCubit>().updateUserRole(user.id, role),
                onDelete: () => _confirmDelete(context, user),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete User'),
            content: Text(
              'Delete user "${user.email}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<UserCubit>().deleteUser(user.id);
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onRoleChange,
    required this.onDelete,
  });
  final UserModel user;
  final Function(UserRole) onRoleChange;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    final deleteLabel = loc.translations['delete_user_a11y'] ?? 'Delete user';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                  child:
                      user.photoUrl == null
                          ? Text(
                            user.email[0].toUpperCase(),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? user.email,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildRoleBadge(context),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildRoleDropdown(context)),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: deleteLabel,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context) {
    Color color;
    String label;
    switch (user.role) {
      case UserRole.admin:
        color = context.semanticColors.success;
        label = 'Admin';
      case UserRole.premium:
        color = Theme.of(context).colorScheme.secondary;
        label = 'Premium';
      case UserRole.free:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        label = 'Free';
    }

    return Container(
      padding: AppInsets.pillTight,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdBorder,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontSize: 12, color: color),
      ),
    );
  }

  Widget _buildRoleDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: AppRadius.smBorder,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          value: user.role,
          isExpanded: true,
          items:
              UserRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Row(
                    children: [
                      Icon(
                        role == UserRole.admin
                            ? Icons.admin_panel_settings
                            : role == UserRole.premium
                            ? Icons.workspace_premium
                            : Icons.person,
                        size: 18,
                        color:
                            role == UserRole.admin
                                ? context.semanticColors.success
                                : role == UserRole.premium
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        role.name[0].toUpperCase() + role.name.substring(1),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: (role) {
            if (role != null && role != user.role) {
              onRoleChange(role);
            }
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.fullBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.fullBorder,
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
