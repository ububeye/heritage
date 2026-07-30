import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import 'login_screen.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

import '../../data/models/user_model.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = authState.user;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Profile'),
          ),
          body: ListView(
            padding: AppInsets.card,
            children: [
              // Profile Header
              _buildProfileHeader(context, user),
              const SizedBox(height: 24),

              // Account Section
              _SectionTitle(title: 'Account'),
              _SettingsCard(
                children: [
                  _ProfileMenuItem(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Change name and photo',
                    onTap: () => _showEditProfileDialog(context, authState),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update your password',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuItem(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'App and audio language',
                    onTap: () => _showLanguageDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Subscription Section
              _SectionTitle(title: 'Subscription'),
              _SettingsCard(
                children: [
                  _ProfileMenuItem(
                    icon: Icons.workspace_premium,
                    title: 'Premium Plan',
                    subtitle:
                        authState.isPremium
                            ? 'Active'
                            : 'Upgrade for more features',
                    trailing:
                        authState.isPremium
                            ? Container(
                              padding: AppInsets.tag,
                              decoration: BoxDecoration(
                                color: context.semanticColors.success
                                    .withValues(alpha: 0.1),
                                borderRadius: AppRadius.smBorder,
                              ),
                              child: Text(
                                'Active',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(
                                  color: context.semanticColors.success,
                                  fontSize: 12,
                                ),
                              ),
                            )
                            : const Icon(Icons.chevron_right),
                    onTap: () => _showUpgradeDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // App Info
              Center(
                child: Column(
                  children: [
                    Text(
                      'Stone Town Guide v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Made with ❤️ for Zanzibar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.1),
            backgroundImage:
                user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
            child:
                user?.photoUrl == null
                    ? Text(
                      user?.email[0].toUpperCase() ?? 'U',
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? user?.email ?? 'User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: AppInsets.pillTight,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.2),
                    borderRadius: AppRadius.mdBorder,
                  ),
                  child: Text(
                    user?.role.name.toUpperCase() ?? 'FREE',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthState authState) {
    final nameController = TextEditingController(
      text: authState.user?.displayName ?? '',
    );

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Name cannot be empty')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await context.read<AuthCubit>().updateDisplayName(newName);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (newController.text != confirmController.text) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match')),
                    );
                    return;
                  }
                  if (newController.text.length < 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Password must be at least 6 characters'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await context.read<AuthCubit>().changePassword(
                      currentPassword: currentController.text,
                      newPassword: newController.text,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Language'),
            content: const Text('Go to Settings to change language'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Upgrade to Premium'),
            content: const Text(
              'Unlock all features:\n\n'
              '• Full audio guides in 7 languages\n'
              '• Unlimited site access\n'
              '• Priority support\n\n'
              'Coming soon!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
              : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
