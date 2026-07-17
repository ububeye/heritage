import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/language_meta.dart';
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
  static String _audioLanguageLabel(String code) => LanguageMeta.name(code);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          return BlocBuilder<LocalizationCubit, LocalizationState>(
            builder: (context, locState) {
              return CustomScrollView(
                slivers: [
                  SliverAppBar.large(
                    automaticallyImplyLeading: false,
                    title: _buildLocalizedText('settings'),
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _SectionTitle(title: _tr(locState, 'app_language')),
                        _SettingsCard(
                          children: [
                            _ModernDropdownTile(
                              icon: Icons.language,
                              iconColor: AppColors.info,
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
                            const _CardDivider(),
                            BlocBuilder<LanguageCubit, LanguageState>(
                              builder: (context, langState) {
                                return _ModernDropdownTile(
                                  icon: Icons.record_voice_over,
                                  iconColor: AppColors.warning,
                                  title: _tr(locState, 'audio_language'),
                                  subtitle: authState.isPremium
                                      ? _tr(locState, 'benefit_audio_tours')
                                      : _tr(locState, 'upgrade_for_full_audio'),
                                  value: langState.audioLanguage,
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
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(title: _tr(locState, 'map_provider')),
                        _SettingsCard(
                          children: [
                            _MapProviderTile(),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(title: _tr(locState, 'appearance')),
                        _SettingsCard(
                          children: [
                            BlocBuilder<ThemeCubit, ThemeMode>(
                              builder: (context, themeMode) {
                                return _ModernDropdownTile(
                                  icon: Icons.palette,
                                  iconColor: Colors.deepPurpleAccent,
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
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(title: _tr(locState, 'storage')),
                        _SettingsCard(
                          children: [
                            _ClearMapCacheTile(),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(title: _tr(locState, 'notifications')),
                        _SettingsCard(
                          children: [
                            _ArrivalAlertsTile(),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(title: _tr(locState, 'account')),
                        _SettingsCard(
                          children: [
                            if (authState.isAuthenticated) ...[
                              _ModernListTile(
                                icon: Icons.person,
                                iconColor: AppColors.primary,
                                title: authState.user?.email ?? '',
                                subtitle: authState.isPremium ? 'Premium User' : 'Free User',
                                trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textHint),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                                ),
                              ),
                              const _CardDivider(),
                              _ModernListTile(
                                icon: Icons.logout,
                                iconColor: AppColors.error,
                                title: _tr(locState, 'logout'),
                                onTap: () => _showLogoutDialog(context, locState),
                              ),
                            ] else
                              _ModernListTile(
                                icon: Icons.person_outline,
                                iconColor: AppColors.primary,
                                title: _tr(locState, 'login'),
                                trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textHint),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (!authState.isPremium) ...[
                          _SectionTitle(title: _tr(locState, 'upgrade_to_premium')),
                          _SettingsCard(
                            children: [
                              _ModernListTile(
                                icon: Icons.workspace_premium,
                                iconColor: AppColors.accent,
                                title: _tr(locState, 'upgrade_to_premium'),
                                subtitle: _tr(locState, 'unlock_premium'),
                                trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textHint),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _SectionTitle(title: _tr(locState, 'about')),
                        _SettingsCard(
                          children: [
                            _ModernListTile(
                              icon: Icons.info_outline,
                              iconColor: Colors.teal,
                              title: _tr(locState, 'version'),
                              trailing: const Text(
                                '1.0.0',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ]),
                    ),
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
        return Text(
          state.translations[key] ?? key,
          style: const TextStyle(fontWeight: FontWeight.bold),
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(_tr(locState, 'unlock_premium'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(_tr(locState, 'logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
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
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textHint,
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.low,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56), // Align with text
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
    );
  }
}

class _ModernIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ModernIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _ModernListTile extends StatelessWidget {
  const _ModernListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      leading: _ModernIcon(icon: icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _ModernDropdownTile extends StatelessWidget {
  const _ModernDropdownTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.items,
    required this.labels,
    this.enabled = true,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
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
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      leading: _ModernIcon(icon: icon, color: enabled ? iconColor : AppColors.textHint),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: enabled ? Theme.of(context).colorScheme.onSurfaceVariant : AppColors.textHint,
                fontSize: 12,
              ),
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
            icon: const Icon(CupertinoIcons.chevron_down, size: 16),
            style: TextStyle(
              color: enabled ? Theme.of(context).colorScheme.onSurface : AppColors.textHint,
              fontWeight: FontWeight.w500,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              value: AppConstants.mapProviderOpen,
              groupValue: _active,
              onChanged: (v) {
                if (v != null) _selectProvider(v);
              },
              title: Text(tr('map_provider_open'), style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                tr('map_provider_open_subtitle'),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              secondary: const _ModernIcon(icon: Icons.public, color: AppColors.primary),
            ),
            const _CardDivider(),
            RadioListTile<String>(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              value: AppConstants.mapProviderGoogle,
              groupValue: _active,
              onChanged: googleEnabled
                  ? (v) {
                      if (v != null) _selectProvider(v);
                    }
                  : null,
              title: Text(
                tr('map_provider_google'),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: googleEnabled ? null : AppColors.textHint,
                ),
              ),
              subtitle: Text(
                googleEnabled ? tr('map_provider_google_subtitle') : tr('map_provider_google_disabled'),
                style: TextStyle(
                  fontSize: 12,
                  color: googleEnabled ? Theme.of(context).colorScheme.onSurfaceVariant : AppColors.textHint,
                ),
              ),
              secondary: _ModernIcon(
                icon: Icons.map,
                color: googleEnabled ? Colors.green : AppColors.textHint,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClearMapCacheTile extends StatefulWidget {
  const _ClearMapCacheTile();

  @override
  State<_ClearMapCacheTile> createState() => _ClearMapCacheTileState();
}

class _ClearMapCacheTileState extends State<_ClearMapCacheTile> {
  int _bytes = -1;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    if (!TileCacheService.instance.isReady) {
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
        final sizeLabel = _bytes < 0 ? tr('cache_size_unknown') : _formatBytes(_bytes);
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
          leading: const _ModernIcon(icon: CupertinoIcons.trash, color: Colors.blueGrey),
          title: Text(tr('clear_map_cache'), style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            tr('clear_map_cache_subtitle'),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _bytes > 0 ? Theme.of(context).colorScheme.primary : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 8),
              if (_bytes > 0)
                IconButton(
                  icon: const Icon(CupertinoIcons.clear_circled_solid, color: AppColors.error, size: 20),
                  onPressed: _onClear,
                  tooltip: tr('clear_map_cache'),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _trFromLoc(BuildContext context, String key) {
  try {
    return context.read<LocalizationCubit>().translate(key);
  } catch (_) {
    return key;
  }
}

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
        return SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
          secondary: const _ModernIcon(icon: CupertinoIcons.bell_solid, color: Colors.amber),
          title: Text(tr('arrival_alerts'), style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            tr('arrival_alerts_subtitle'),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          value: _enabled,
          activeColor: Theme.of(context).colorScheme.primary,
          onChanged: _toggle,
        );
      },
    );
  }
}
