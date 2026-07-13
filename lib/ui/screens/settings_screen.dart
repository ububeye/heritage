import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/language_meta.dart';
import '../../core/utils/nav_guard.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../data/services/tile_cache_service.dart';
import 'login_screen.dart';
import 'upgrade_screen.dart';
import 'user_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Localized display name for an audio-language dropdown item. Uses
  /// the same in-language names as the audio bar's language chip so the
  /// two pickers stay in sync.
  static String _audioLanguageLabel(String code) => LanguageMeta.name(code);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        items: AppConstants.uiLanguages,
                        labels: AppConstants.uiLanguages
                            .map((c) => _tr(locState, c == 'en' ? 'english' : 'swahili'))
                            .toList(),
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
                        labels: (authState.isPremium
                                ? AppConstants.ttsLanguages
                                : AppConstants.freeTtsLanguages)
                            .map(_audioLanguageLabel)
                            .toList(),
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
                  _SectionTitle(title: _tr(locState, 'map_provider')),
                  _SettingsCard(
                    children: [
                      _MapProviderTile(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: _tr(locState, 'appearance')),
                  _SettingsCard(
                    children: [
                      BlocBuilder<ThemeCubit, ThemeMode>(
                        builder: (context, themeMode) {
                          return _DropdownTile(
                            icon: Icons.palette,
                            title: _tr(locState, 'theme'),
                            subtitle: _tr(locState, 'choose_theme'),
                            value: themeMode.toString().split('.').last,
                            items: const ['light', 'dark', 'system'],
                            labels: [
                              _tr(locState, 'theme_light'),
                              _tr(locState, 'theme_dark'),
                              _tr(locState, 'theme_system'),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                ThemeMode newMode;
                                switch (value) {
                                  case 'dark':
                                    newMode = ThemeMode.dark;
                                    break;
                                  case 'system':
                                    newMode = ThemeMode.system;
                                    break;
                                  case 'light':
                                  default:
                                    newMode = ThemeMode.light;
                                    break;
                                }
                                context.read<ThemeCubit>().setThemeMode(newMode);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: _tr(locState, 'storage')),
                  _SettingsCard(
                    children: [
                      _ClearMapCacheTile(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: _tr(locState, 'notifications')),
                  _SettingsCard(
                    children: [
                      _ArrivalAlertsTile(),
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
                      // Privacy Policy and Terms of Service tiles were
                      // removed — the placeholder URLs pointed at pages
                      // that don't exist (stonetownguide.com/{privacy,
                      // terms}) and would 404. They will return once real
                      // pages are hosted.
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

  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DropdownTile extends StatelessWidget {

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
  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final List<String> items;
  final List<String> labels;
  final bool enabled;
  final Function(String?) onChanged;

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

/// "Map provider" tile — reflects the active provider and lets the user
/// swap to Google when an API key is configured. When `googleMapsApiKey`
/// is null the Google row is rendered disabled with an inline hint so the
/// user understands why they can't select it.
class _MapProviderTile extends StatefulWidget {
  const _MapProviderTile();

  @override
  State<_MapProviderTile> createState() => _MapProviderTileState();
}

class _MapProviderTileState extends State<_MapProviderTile> {
  late String _active;

  @override
  void initState() {
    super.initState();
    _active = SharedPrefsService.instance.mapProvider;
  }

  void _selectProvider(String provider) {
    if (provider == _active) return;
    setState(() => _active = provider);
    SharedPrefsService.instance.setMapProvider(provider);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        String tr(String key) => locState.translations[key] ?? key;
        final googleEnabled = AppConstants.googleMapsApiKey != null &&
            AppConstants.googleMapsApiKey!.isNotEmpty;

        return Column(
          children: [
            RadioListTile<String>(
              value: AppConstants.mapProviderOpen,
              groupValue: _active,
              onChanged: (v) {
                if (v != null) _selectProvider(v);
              },
              title: Text(tr('map_provider_open')),
              subtitle: Text(
                tr('map_provider_open_subtitle'),
                style: const TextStyle(fontSize: 12),
              ),
              secondary: const Icon(Icons.public, color: AppColors.primary),
            ),
            const Divider(height: 1),
            RadioListTile<String>(
              value: AppConstants.mapProviderGoogle,
              groupValue: _active,
              // Force-disable when no API key has been configured so the
              // user can't pick a path that will crash on launch.
              onChanged: googleEnabled
                  ? (v) {
                      if (v != null) _selectProvider(v);
                    }
                  : null,
              title: Text(
                tr('map_provider_google'),
                style: TextStyle(
                  color: googleEnabled
                      ? null
                      : AppColors.textHint,
                ),
              ),
              subtitle: Text(
                googleEnabled
                    ? tr('map_provider_google_subtitle')
                    : tr('map_provider_google_disabled'),
                style: TextStyle(
                  fontSize: 12,
                  color: googleEnabled
                      ? AppColors.textSecondary
                      : AppColors.textHint,
                ),
              ),
              secondary: Icon(
                Icons.map,
                color: googleEnabled ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "Storage → Clear map cache" tile. Reads the current disk-cache size
/// on first build, refreshes it after a clear, and shows the user the
/// freed-up space in a human-readable form (e.g. "12.4 MB"). Surfaced
/// under Appearance → Storage in the Settings tree.
class _ClearMapCacheTile extends StatefulWidget {
  const _ClearMapCacheTile();

  @override
  State<_ClearMapCacheTile> createState() => _ClearMapCacheTileState();
}

class _ClearMapCacheTileState extends State<_ClearMapCacheTile> {
  int _bytes = -1; // -1 == unknown / not yet calculated

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    if (!TileCacheService.instance.isReady) {
      // The service is best-effort — silently show "0" when the FS
      // cache wasn't initialised.
      setState(() => _bytes = 0);
      return;
    }
    final size = await TileCacheService.instance.getTotalSizeBytes();
    if (mounted) setState(() => _bytes = size);
  }

  Future<void> _onClear() async {
    if (!TileCacheService.instance.isReady) return;
    await TileCacheService.instance.clear();
    if (!mounted) return;
    setState(() => _bytes = 0);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(_trFromLoc(context, 'cache_cleared')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        String tr(String key) => locState.translations[key] ?? key;
        final sizeLabel = _bytes < 0
            ? tr('cache_size_unknown')
            : _formatBytes(_bytes);
        return ListTile(
          leading: const Icon(Icons.cleaning_services, color: AppColors.primary),
          title: Text(tr('clear_map_cache')),
          subtitle: Text(
            tr('clear_map_cache_subtitle'),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: _bytes > 0
                      ? AppColors.textSecondary
                      : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _bytes > 0 ? _onClear : null,
                child: Text(tr('clear_map_cache')),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Helper: read a localization key outside of a BlocBuilder context —
/// used by [SnackBar] callbacks fired from imperative handlers.
String _trFromLoc(BuildContext context, String key) {
  try {
    return context.read<LocalizationCubit>().translate(key);
  } catch (_) {
    return key;
  }
}

/// "Notifications → Arrival alerts" tile. Toggle is persisted via
/// SharedPrefs and read at the navigation-screen arrival-detection
/// site so users who turn it off don't see the welcome modal.
class _ArrivalAlertsTile extends StatefulWidget {
  const _ArrivalAlertsTile();

  @override
  State<_ArrivalAlertsTile> createState() => _ArrivalAlertsTileState();
}

class _ArrivalAlertsTileState extends State<_ArrivalAlertsTile> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = SharedPrefsService.instance.arrivalAlertsEnabled;
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await SharedPrefsService.instance.setArrivalAlertsEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationCubit, LocalizationState>(
      builder: (context, locState) {
        String tr(String key) => locState.translations[key] ?? key;
        return SwitchListTile(
          secondary: const Icon(Icons.notifications_active, color: AppColors.primary),
          title: Text(tr('arrival_alerts')),
          subtitle: Text(
            tr('arrival_alerts_subtitle'),
            style: const TextStyle(fontSize: 12),
          ),
          value: _enabled,
          onChanged: _toggle,
        );
      },
    );
  }
}
