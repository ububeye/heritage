import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/nav_guard.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/services/shared_prefs_service.dart';
import 'login_screen.dart';
import 'upgrade_screen.dart';
import 'user_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentMapProvider() {
    try {
      return SharedPrefsService.instance.mapProvider;
    } catch (_) {
      return AppConstants.mapProviderOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _buildLocalizedText('settings'),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          return BlocBuilder<LocalizationCubit, LocalizationState>(
            builder: (context, locState) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionTitle(title: _tr(locState, 'app_language')),
                  _SettingsCard(
                    children: [
                      _DropdownTile(
                        icon: Icons.language,
                        title: _tr(locState, 'app_language'),
                        subtitle: _tr(locState, 'choose_language'),
                        value: locState.currentLanguage,
                        items: const ['en', 'sw'],
                        labels: [_tr(locState, 'english'), _tr(locState, 'swahili')],
                        onChanged: (value) {
                          if (value != null) {
                            context.read<LocalizationCubit>().setLanguage(value);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      _DropdownTile(
                        icon: Icons.record_voice_over,
                        title: _tr(locState, 'audio_language'),
                        subtitle: authState.isPremium
                            ? _tr(locState, 'benefit_audio_tours')
                            : _tr(locState, 'upgrade_for_full_audio'),
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
                            _showUpgradeDialog(context, locState);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'Map provider'),
                  _SettingsCard(
                    children: [
                      _MapProviderTile(
                        current: _currentMapProvider(),
                        googleKeyConfigured: isGoogleMapsEnabled,
                        onChanged: (value) async {
                          if (value == null) return;
                          await SharedPrefsService.instance
                              .setMapProvider(value);
                          if (!context.mounted) return;
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value == AppConstants.mapProviderOpen
                                    ? 'Switched to OpenStreetMap. Works without an API key.'
                                    : (isGoogleMapsEnabled
                                        ? 'Switched to Google Maps.'
                                        : 'Google Maps selected, but no API key is configured. Using the open-source map until one is set.'),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: _tr(locState, 'account')),
                  _SettingsCard(
                    children: [
                      if (authState.isAuthenticated) ...[
                        ListTile(
                          leading: const Icon(Icons.person, color: AppColors.primary),
                          title: Text(authState.user?.email ?? ''),
                          subtitle: Text(
                            authState.isPremium ? 'Premium User' : 'Free User',
                            style: TextStyle(
                              color: authState.isPremium ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout, color: AppColors.error),
                          title: _buildLocalizedText('logout'),
                          onTap: () => _showLogoutDialog(context, locState),
                        ),
                      ] else
                        ListTile(
                          leading: const Icon(Icons.person_outline, color: AppColors.primary),
                          title: _buildLocalizedText('login'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!authState.isPremium) ...[
                    _SectionTitle(title: _tr(locState, 'upgrade_to_premium')),
                    _SettingsCard(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.workspace_premium, color: AppColors.accent),
                          ),
                          title: _buildLocalizedText('upgrade_to_premium'),
                          subtitle: _buildLocalizedText('unlock_premium'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  _SectionTitle(title: _tr(locState, 'about')),
                  _SettingsCard(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: AppColors.primary),
                        title: _buildLocalizedText('version'),
                        trailing: const Text('1.0.0'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                        title: _buildLocalizedText('privacy_policy'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openUrl('https://stonetownguide.com/privacy'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                        title: _buildLocalizedText('terms_of_service'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openUrl('https://stonetownguide.com/terms'),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLocalizedText(String key) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, state) {
        return Text(state.translations[key] ?? key);
      },
    );
  }

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  void _showUpgradeDialog(BuildContext context, LocalizationState locState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(locState, 'unlock_premium')),
        content: Text(_tr(locState, 'benefit_audio_tours')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_tr(locState, 'try_free')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              );
            },
            child: Text(_tr(locState, 'go_premium')),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, LocalizationState locState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
  final String? subtitle;
  final String value;
  final List<String> items;
  final List<String> labels;
  final bool enabled;
  final Function(String?) onChanged;

  const _DropdownTile({
    required this.icon,
    required this.title,
    this.subtitle,
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
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: enabled ? AppColors.textSecondary : AppColors.textHint, fontSize: 12),
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

/// "Map provider" tile — switches between the open-source path (default)
/// and the Google Maps path. The Google option is greyed out when no API
/// key has been configured in `app_constants.dart`.
class _MapProviderTile extends StatelessWidget {
  final String current;
  final bool googleKeyConfigured;
  final ValueChanged<String?> onChanged;

  const _MapProviderTile({
    required this.current,
    required this.googleKeyConfigured,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      AppConstants.mapProviderOpen,
      if (googleKeyConfigured) AppConstants.mapProviderGoogle,
    ];
    final labels = <String>[
      'OpenStreetMap (recommended)',
      if (googleKeyConfigured) 'Google Maps',
    ];

    return ListTile(
      leading: const Icon(Icons.map, color: AppColors.primary),
      title: const Text('Map provider'),
      subtitle: Text(
        googleKeyConfigured
            ? 'OpenStreetMap is free and works without an API key.'
            : 'Google Maps requires an API key in app_constants.dart.\nNot configured — using the open-source map.',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: DropdownButton<String>(
        value: items.contains(current) ? current : items.first,
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