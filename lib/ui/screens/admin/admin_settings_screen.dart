import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../blocs/auth/auth_cubit.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../blocs/language/language_cubit.dart';
import '../../screens/login_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Admin Settings'),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAdminHeader(authState),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Preferences'),
              _SettingsCard(
                children: [
                  _DropdownTile(
                    icon: Icons.language,
                    title: 'Default App Language',
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
                    title: 'Default Audio Language',
                    value: context.watch<LanguageCubit>().state.audioLanguage,
                    items: AppConstants.ttsLanguages,
                    labels: const ['English', 'Swahili', 'French', 'German', 'Arabic', 'Italian', 'Spanish'],
                    onChanged: (value) {
                      if (value != null) {
                        context.read<LanguageCubit>().setAudioLanguage(value);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'App Info'),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.primary),
                    title: const Text('App Version'),
                    trailing: const Text('1.0.0'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.flutter_dash, color: AppColors.primary),
                    title: const Text('Flutter'),
                    trailing: const Text('v3.x'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud, color: AppColors.primary),
                    title: const Text('Firebase'),
                    trailing: const Text('Connected'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Danger Zone'),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Logout'),
                    subtitle: Text(
                      authState.user?.email ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 8),
                    Text(
                      'Stone Town Guide Admin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2024',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdminHeader(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authState.user?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 179),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthCubit>().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
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
  final Function(String?) onChanged;

  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        underline: const SizedBox(),
        items: items.asMap().entries.map((e) {
          return DropdownMenuItem<String>(
            value: e.value,
            child: Text(labels[e.key]),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}