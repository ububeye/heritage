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
                onTap: () => _showUserManagementSheet(context, user),
              );
            },
          ),
        );
      },
    );
  }

  void _showUserManagementSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTopBorder,
      ),
      builder: (ctx) => _UserManagementSheet(user: user, parentContext: context),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onTap,
  });
  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    final deleteLabel = loc.translations['delete_user_a11y'] ?? 'Delete user';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
        break;
      case UserRole.premium:
        color = Theme.of(context).colorScheme.secondary;
        label = 'Premium';
        break;
      case UserRole.free:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        label = 'Free';
        break;
    }

    if (user.disabled) {
      color = Theme.of(context).colorScheme.error;
      label = 'Disabled';
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

class _UserManagementSheet extends StatelessWidget {
  const _UserManagementSheet({required this.user, required this.parentContext});
  final UserModel user;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: AppRadius.fullBorder,
                ),
              ),
            ),
            Text(
              'Manage User',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            
            // Access Level
            Text(
              'Access Level',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: UserRole.values.map((role) {
                final isSelected = user.role == role;
                return ChoiceChip(
                  label: Text(role.name[0].toUpperCase() + role.name.substring(1)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      parentContext.read<UserCubit>().updateUserRole(user.id, role);
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Security
            Text(
              'Security',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                user.disabled ? Icons.lock_open : Icons.lock_outline,
                color: user.disabled ? context.semanticColors.success : Theme.of(context).colorScheme.error,
              ),
              title: Text(user.disabled ? 'Unsuspend Account' : 'Suspend Account'),
              onTap: () {
                parentContext.read<UserCubit>().toggleUserDisabled(user.id, !user.disabled);
                Navigator.pop(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password),
              title: const Text('Force Password Reset'),
              onTap: () async {
                try {
                  await parentContext.read<UserCubit>().sendPasswordReset(user.email);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset email sent')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
            
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                parentContext.read<UserCubit>().deleteUser(user.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Account Permanently'),
            ),
          ],
        ),
      ),
    );
  }
}

