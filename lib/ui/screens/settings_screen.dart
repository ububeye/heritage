import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/premium/premium_cubit.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'upgrade_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(title: 'Language'),
              _SettingsCard(
                children: [
                  _DropdownTile(
                    icon: Icons.language,
                    title: 'App Language',
                    value: context.watch<LanguageCubit>().state.uiLanguage,
                    items: const ['en', 'sw'],
                    labels: const ['English', 'Swahili'],
                    onChanged: (value) {
                      if (value != null) {
                        context.read<LanguageCubit>().setUiLanguage(value);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _DropdownTile(
                    icon: Icons.record_voice_over,
                    title: 'Audio Language',
                    value: context.watch<LanguageCubit>().state.audioLanguage,
                    items: authState.isPremium
                        ? AppConstants.ttsLanguages
                        : AppConstants.freeTtsLanguages,
                    labels: authState.isPremium
                        ? const ['English', 'Swahili', 'French', 'German', 'Arabic', 'Italian', 'Spanish']
                        : const ['English', 'Swahili'],
                    enabled: authState.isPremium,
                    onChanged: (value) {
                      if (value != null && authState.isPremium) {
                        context.read<LanguageCubit>().setAudioLanguage(value);
                      } else if (!authState.isPremium) {
                        _showUpgradeDialog(context);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Account'),
              _SettingsCard(
                children: [
                  if (authState.isAuthenticated)
                    ListTile(
                      leading: const Icon(Icons.email, color: AppColors.primary),
                      title: Text(authState.user?.email ?? ''),
                      subtitle: Text(
                        authState.isPremium ? 'Premium User' : 'Free User',
                        style: TextStyle(
                          color: authState.isPremium ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: AppColors.primary),
                      title: const Text('Not logged in'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                    ),
                  if (authState.isAuthenticated) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.error),
                      title: const Text('Logout'),
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              if (!authState.isPremium) ...[
                _SectionTitle(title: 'Subscription'),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.workspace_premium, color: AppColors.accent),
                      ),
                      title: const Text('Upgrade to Premium'),
                      subtitle: const Text('Unlock all features'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              _SectionTitle(title: 'About'),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.primary),
                    title: const Text('Version'),
                    trailing: const Text('1.0.0'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: const Text('Unlock all 7 audio languages with Premium subscription.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AuthCubit>().signOut();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final List<String> items;
  final List<String> labels;
  final bool enabled;
  final Function(String?) onChanged;

  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.labels,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: enabled ? AppColors.primary : AppColors.textHint),
      title: Text(title),
      subtitle: !enabled
          ? const Text(
              'Upgrade for more languages',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.lock, size: 16, color: AppColors.textHint),
            ),
          DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            underline: const SizedBox(),
            items: items.asMap().entries.map((e) {
              return DropdownMenuItem<String>(
                value: e.value,
                child: Text(labels[e.key]),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}