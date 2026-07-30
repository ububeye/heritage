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
import '../../../blocs/runtime_config/runtime_config_cubit.dart';
import '../../widgets/settings/settings_card.dart';
import '../../widgets/settings/settings_dropdown_tile.dart';
import '../../widgets/settings/settings_section_title.dart';
import '../../widgets/settings/settings_tile.dart';
import '../../screens/login_screen.dart';
import 'admin_analytics_screen.dart';

/// Admin settings surface. The body is a vertical list of four labelled
/// sections, each a [SettingsCard] or a single tile:
///
///   • Tour catalogue  — admin-side defaults that affect what users see.
///   • Operational     — placeholder; Phase 3 wires the analytics
///                       shortcut and the maintenance-mode toggle here.
///   • App info        — version / engine / backend rows, read-only.
///   • Account         — sign-out tile.
///
/// The grouping is intentional: the previous version used three flat
/// sections and mixed admin defaults (language) with app metadata and
/// account actions, which made it unclear what an admin could actually
/// change. Sections keep related actions together.
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
                  // ── Tour catalogue (admin-side defaults) ──────────────
                  SettingsSectionTitle(
                    label: _tr(locState, 'admin_section_tour_catalogue'),
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

                  // ── Operational ───────────────────────────────────────
                  SettingsSectionTitle(
                    label: _tr(locState, 'admin_section_operational'),
                  ),
                  SettingsCard(children: [
                    // Live maintenance indicator + one-tap toggle. We
                    // wrap the maintenance rows in a BlocBuilder so the
                    // active banner and the switch state stay in sync
                    // with the cubit — without this the switch reads
                    // the initial value once and stops reacting to
                    // out-of-band changes (e.g. another admin flips it
                    // via deep link).
                    BlocBuilder<RuntimeConfigCubit, RuntimeConfigState>(
                      builder: (context, runtimeState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SettingsSwitchTile(
                              icon: Icons.build_circle_outlined,
                              iconColor: AppColors.warning,
                              title: _tr(
                                locState,
                                'admin_maintenance_mode',
                              ),
                              subtitle: _tr(
                                locState,
                                'admin_maintenance_mode_subtitle',
                              ),
                              value: runtimeState.maintenanceMode,
                              onChanged: (v) => context
                                  .read<RuntimeConfigCubit>()
                                  .setMaintenanceMode(v),
                            ),
                            if (runtimeState.maintenanceMode) ...[
                              const SettingsDivider(),
                              _MaintenanceBanner(
                                message: _tr(
                                  locState,
                                  'admin_maintenance_active_banner',
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SettingsDivider(),
                    SettingsTile(
                      icon: Icons.bar_chart,
                      iconColor: AppColors.accent,
                      title: _tr(locState, 'admin_view_analytics'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminAnalyticsScreen(),
                        ),
                      ),
                    ),
                  ],),
                  const SizedBox(height: 16),

                  // Runtime configuration — values admins can change
                  // without rebuilding the app. Each tile shows the
                  // current value from RuntimeConfigCubit and edits
                  // round-trip through the cubit, which writes to
                  // SharedPreferences and re-emits so any consumer
                  // (TtsService, RoutingService, the navigation
                  // attribution widget) picks up the new value.
                  SettingsSectionTitle(
                    label: _tr(locState, 'admin_runtime_config'),
                  ),
                  SettingsCard(children: [
                    _FreeAudioSecondsTile(locState: locState),
                    const SettingsDivider(),
                    _OrsApiKeyTile(locState: locState),
                  ],),
                  const SizedBox(height: 16),

                  // ── App info ──────────────────────────────────────────
                  SettingsSectionTitle(
                    label: _tr(locState, 'app_info'),
                  ),
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

                  // ── Account ───────────────────────────────────────────
                  SettingsSectionTitle(
                    label: _tr(locState, 'admin_section_account'),
                  ),
                  SettingsCard(children: [
                    SettingsTile(
                      icon: Icons.logout,
                      iconColor: AppColors.error,
                      title: _tr(locState, 'logout'),
                      subtitle: authState.user?.email ?? '',
                      // Suppress the default chevron — this is an action
                      // tile, not a navigation cue. An empty SizedBox is
                      // cheaper than a custom trailing widget.
                      trailing: const SizedBox.shrink(),
                      onTap: () => _showLogoutDialog(context, locState),
                    ),
                  ],),
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// Inline banner shown inside the Operational card when maintenance
/// mode is on. Renders the warning icon + the active-state message in
/// a tinted strip that fits the existing SettingsCard layout.
class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.warning,
                    fontSize: 13,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Free-audio preview length tile. Reads the current value from the
/// cubit and presents a dropdown of common options (15 / 30 / 60 / 90 s).
/// The dropdown list deliberately excludes degenerate values like 5 s
/// — the service clamps to a 5 s floor but the UI shouldn't expose
/// values that aren't useful as previews.
class _FreeAudioSecondsTile extends StatelessWidget {
  const _FreeAudioSecondsTile({required this.locState});

  final LocalizationState locState;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RuntimeConfigCubit, RuntimeConfigState>(
      buildWhen: (prev, curr) =>
          prev.freeAudioMaxSeconds != curr.freeAudioMaxSeconds,
      builder: (context, state) {
        // Snap persisted values to the option list so the dropdown
        // doesn't show a stale / unmapped selection.
        const options = [15, 30, 60, 90];
        final value = options.contains(state.freeAudioMaxSeconds)
            ? state.freeAudioMaxSeconds
            : 30;
        return SettingsDropdownTile<int>(
          icon: Icons.timer_outlined,
          iconColor: AppColors.warning,
          title: locState.translations['admin_free_audio_seconds'] ??
              'Free audio preview length',
          subtitle:
              locState.translations['admin_free_audio_seconds_subtitle'] ??
                  'How many seconds of narration free-tier users hear before the upgrade prompt',
          value: value,
          items: options,
          labels: options.map((s) => '$s s').toList(),
          onChanged: (v) {
            if (v != null) {
              context.read<RuntimeConfigCubit>().setFreeAudioMaxSeconds(v);
            }
          },
        );
      },
    );
  }
}

/// OpenRouteService API key tile. The value is sensitive enough that we
/// show it as plain text — a real production build would mask it behind
/// a visibility toggle and store it in the platform keystore rather than
/// SharedPreferences. For v1 (admin-only, single-device) plain text +
/// SharedPreferences is acceptable; the value never leaves the device.
class _OrsApiKeyTile extends StatelessWidget {
  const _OrsApiKeyTile({required this.locState});

  final LocalizationState locState;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RuntimeConfigCubit, RuntimeConfigState>(
      buildWhen: (prev, curr) => prev.orsApiKey != curr.orsApiKey,
      builder: (context, state) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: SettingsTileIcon(
            icon: Icons.vpn_key_outlined,
            color: AppColors.accent,
          ),
          title: Text(
            locState.translations['admin_ors_api_key'] ??
                'OpenRouteService API key',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            locState.translations['admin_ors_api_key_subtitle'] ??
                'Leave empty to use the OSRM demo (no key required)',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: locState.translations['edit_profile'] ?? 'Edit',
            onPressed: () => _showEditDialog(context, state.orsApiKey),
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final locState = context.read<LocalizationCubit>().state;
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          locState.translations['admin_ors_api_key'] ??
              'OpenRouteService API key',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText:
                locState.translations['admin_ors_api_key_hint'] ??
                    'Paste the key here',
            border: const OutlineInputBorder(),
          ),
          // Password-style obscuring would defeat the admin's purpose of
          // being able to verify the key is correct. Plain text.
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locState.translations['cancel'] ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: Text(locState.translations['save'] ?? 'Save'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    if (!context.mounted) return;
    await context.read<RuntimeConfigCubit>().setOrsApiKey(saved);
  }
}
