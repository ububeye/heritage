import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/colors.dart';
import '../../../blocs/user/user_cubit.dart';
import '../../../data/models/user_model.dart';

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
      backgroundColor: AppColors.background,
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
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<UserCubit, UserState>(
              builder: (context, state) {
                return TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => context.read<UserCubit>().searchUsers(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  onChanged: (value) => context.read<UserCubit>().searchUsers(value),
                );
              },
            ),
          ),
          _buildStatsBar(),
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', state.totalUsers.toString(), AppColors.primary),
              _buildStatItem('Premium', state.premiumUsers.toString(), AppColors.accent),
              _buildStatItem('Admins', state.adminUsers.toString(), AppColors.success),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        if (state.status == UserStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        if (state.status == UserStatus.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
                  state.searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                  size: 64,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 16),
                Text(
                  state.searchQuery.isEmpty ? 'No users found' : 'No matching users',
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
          onRefresh: () => context.read<UserCubit>().loadUsers(),
          color: AppColors.accent,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserCard(
                user: user,
                onRoleChange: (role) => context.read<UserCubit>().updateUserRole(user.id, role),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete user "${user.email}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
  final UserModel user;
  final Function(UserRole) onRoleChange;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onRoleChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 26),
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.email[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildRoleBadge(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRoleDropdown(context),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    Color color;
    String label;
    switch (user.role) {
      case UserRole.admin:
        color = AppColors.success;
        label = 'Admin';
      case UserRole.premium:
        color = AppColors.accent;
        label = 'Premium';
      case UserRole.free:
        color = AppColors.textSecondary;
        label = 'Free';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          value: user.role,
          isExpanded: true,
          items: UserRole.values.map((role) {
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
                    color: role == UserRole.admin
                        ? AppColors.success
                        : role == UserRole.premium
                            ? AppColors.accent
                            : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    role.name[0].toUpperCase() + role.name.substring(1),
                    style: const TextStyle(fontSize: 14),
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