import '../../../core/theme/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/language_meta.dart';
import '../../../blocs/auth/auth_cubit.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../blocs/language/language_cubit.dart';
import '../../widgets/settings/settings_card.dart';
import '../../widgets/settings/settings_dropdown_tile.dart';
import '../../widgets/settings/settings_section_title.dart';
import '../../widgets/settings/settings_tile.dart';
import '../../screens/login_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  String _tr(LocalizationState s, String key) => s.translations[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: BlocBuilder<LocalizationCubit, LocalizationState>(
          builder: (context, loc) =>
              Text(loc.translations['admin_tab_settings'] ?? 'Settings'),
        ),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          return BlocBuilder<LocalizationCubit, LocalizationState>(
            builder: (context, locState) {
              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // ── Preferences (admin defaults) ─────────────────────
                  SettingsSectionTitle(
                    label: _tr(locState, 'preferences'),
                  ),
                  SettingsCard(children: [
                    SettingsDropdownTile<String>(
                      icon: Icons.language,
                      iconColor: AppColors.primary,
                      title: _tr(locState, 'app_language'),
                      value: context.watch<LanguageCubit>().state.uiLanguage,
                      items: AppConstants.uiLanguages,
                      labels: [
                        '${LanguageMeta.flag('en')} ${LanguageMeta.name('en')}',
                        '${LanguageMeta.flag('sw')} ${LanguageMeta.name('sw')}',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          context.read<LanguageCubit>().setUiLanguage(value);
                        }
                      },
                    ),
                    const SettingsDivider(),
                    SettingsDropdownTile<String>(
                      icon: Icons.record_voice_over,
                      iconColor: AppColors.warning,
                      title: _tr(locState, 'audio_language'),
                      value: context.watch<LanguageCubit>().state.audioLanguage,
                      items: AppConstants.ttsLanguages,
                      labels: AppConstants.ttsLanguages
                          .map((c) =>
                              '${LanguageMeta.flag(c)} ${LanguageMeta.name(c)}',
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          context
                              .read<LanguageCubit>()
                              .setAudioLanguage(value);
                        }
                      },
                    ),
                  ],),
                  const SizedBox(height: 16),

                  // ── App info ──────────────────────────────────────────
                  SettingsSectionTitle(label: _tr(locState, 'app_info')),
                  SettingsCard(children: [
                    _InfoRow(
                      icon: Icons.info_outline,
                      title: _tr(locState, 'version'),
                      value: '1.0.0',
                    ),
                    const SettingsDivider(),
                    _InfoRow(
                      icon: Icons.flutter_dash,
                      title: 'Flutter',
                      value: 'v3.x',
                    ),
                    const SettingsDivider(),
                    _InfoRow(
                      icon: Icons.cloud,
                      title: 'Firebase',
                      value: 'Connected',
                    ),
                  ],),
                  const SizedBox(height: 24),

                  // ── Footer sign-out (matches user settings) ───────────
                  SettingsTile(
                    icon: Icons.logout,
                    iconColor: AppColors.error,
                    title: _tr(locState, 'logout'),
                    subtitle: authState.user?.email ?? '',
                    onTap: () => _showLogoutDialog(context, locState),
                  ),

                  const SizedBox(height: 32),
                  Center(child: _AdminFooter(locState: locState)),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showLogoutDialog(
    BuildContext context,
    LocalizationState locState,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(_tr(locState, 'logout')),
        content: Text('${_tr(locState, 'logout')}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_tr(locState, 'cancel')),
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
            child: Text(_tr(locState, 'logout')),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SettingsTileIcon(icon: icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Text(
        value,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AdminFooter extends StatelessWidget {
  const _AdminFooter({required this.locState});
  final LocalizationState locState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.admin_panel_settings,
          size: 36,
          color: AppColors.textHint,
        ),
        const SizedBox(height: 8),
        Text(
          'Stone Town Guide Admin',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '2024',
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
      ],
    );
  }
}