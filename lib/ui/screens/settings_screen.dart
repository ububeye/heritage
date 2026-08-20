import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_durations.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/language_meta.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../data/services/tile_cache_service.dart';
import '../widgets/settings/settings_card.dart';
import '../widgets/settings/settings_dropdown_tile.dart';
import '../widgets/settings/settings_segmented_tile.dart';
import '../widgets/settings/settings_section_title.dart';
import '../widgets/settings/settings_tile.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';
import 'upgrade_screen.dart';
import 'user_profile_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Recipient for "Report a problem" mailto links. Configured at build time via
/// `--dart-define=SUPPORT_EMAIL=help@example.com`. When empty the tile
/// surfaces an in-app dialog instead of attempting a silent mailto.
const String kSupportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: '',
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _tr(LocalizationState state, String key) =>
      state.translations[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          return BlocBuilder<LocalizationCubit, LocalizationState>(
            builder: (context, locState) {
              return _SettingsBody(
                authState: authState,
                locState: locState,
                tr: _tr,
              );
            },
          );
        },
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.authState,
    required this.locState,
    required this.tr,
  });
  final AuthState authState;
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _ProfileHeroAppBar(authState: authState, locState: locState, tr: tr),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Tour preferences (NEW) ───────────────────────────────
              SettingsSectionTitle(label: tr(locState, 'tour_preferences')),
              SettingsCard(
                children: const [
                  _AutoPlayTile(),
                  SettingsDivider(),
                  _PlaybackSpeedTile(),
                  SettingsDivider(),
                  _DistanceUnitsTile(),
                  SettingsDivider(),
                  _ReduceMotionTile(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Appearance ───────────────────────────────────────────
              SettingsSectionTitle(label: tr(locState, 'appearance')),
              SettingsCard(
                children: const [
                  _ThemeTile(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Languages ────────────────────────────────────────────
              SettingsSectionTitle(label: tr(locState, 'app_language')),
              SettingsCard(
                children: [
                  _LanguageDropdownTile(
                    icon: PhosphorIconsRegular.globe,
                    iconColor: context.semanticColors.info,
                    code: locState.currentLanguage,
                    items: AppConstants.uiLanguages,
                    titleKey: 'app_language',
                    subtitleKey: 'app_language_subtitle',
                    onChanged: (value) {
                      if (value != null) {
                        context.read<LocalizationCubit>().setLanguage(value);
                      }
                    },
                  ),
                  const SettingsDivider(),
                  _LanguageDropdownTile(
                    icon: Icons.record_voice_over,
                    iconColor: context.semanticColors.warning,
                    code: context.watch<LanguageCubit>().state.audioLanguage,
                    items:
                        authState.isPremium
                            ? AppConstants.ttsLanguages
                            : AppConstants.freeTtsLanguages,
                    enabled: authState.isPremium,
                    titleKey: 'audio_language',
                    subtitleKey: 'audio_language_subtitle',
                    onChanged: (value) {
                      if (value == null) return;
                      if (!authState.isPremium) {
                        _showUpgradeDialog(context, locState);
                        return;
                      }
                      context.read<LanguageCubit>().setAudioLanguage(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Notifications ────────────────────────────────────────
              SettingsSectionTitle(label: tr(locState, 'notifications')),
              SettingsCard(children: [_ArrivalNotificationsGroup()]),
              const SizedBox(height: AppSpacing.lg),

              // ── Storage ──────────────────────────────────────────────
              SettingsSectionTitle(label: tr(locState, 'storage')),
              SettingsCard(
                children: const [
                  _ClearMapCacheTile(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Account ──────────────────────────────────────────────
              SettingsSectionTitle(label: tr(locState, 'account')),
              SettingsCard(children: [_AccountRow(authState: authState)]),
              const SizedBox(height: AppSpacing.lg),

              // ── About ────────────────────────────────────────────────
              SettingsSectionTitle(label: tr(locState, 'about')),
              SettingsCard(
                children: const [
                  _VersionTile(),
                  SettingsDivider(),
                  _OpenSourceLicensesTile(),
                  SettingsDivider(),
                  _ReportAProblemTile(),
                ],
              ),

              if (!authState.isPremium) ...[
                const SizedBox(height: AppSpacing.lg),
                SettingsSectionTitle(label: tr(locState, 'upgrade_to_premium')),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Icons.workspace_premium,
                      iconColor: Theme.of(context).colorScheme.secondary,
                      title: tr(locState, 'upgrade_to_premium'),
                      subtitle: tr(locState, 'unlock_premium'),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UpgradeScreen(),
                            ),
                          ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              // ── Sign-out footer ──────────────────────────────────────
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              _SignOutFooter(locState: locState, tr: tr),
              const SizedBox(height: AppSpacing.xxl),
            ]),
          ),
        ),
      ],
    );
  }

  void _showUpgradeDialog(BuildContext context, LocalizationState locState) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: Text(
              tr(locState, 'unlock_premium'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(tr(locState, 'benefit_audio_tours')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr(locState, 'try_free')),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(tr(locState, 'go_premium')),
              ),
            ],
          ),
    );
  }
}

// ── Sliver app bar with profile hero ─────────────────────────────────────

class _ProfileHeroAppBar extends StatelessWidget {
  const _ProfileHeroAppBar({
    required this.authState,
    required this.locState,
    required this.tr,
  });
  final AuthState authState;
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  @override
  Widget build(BuildContext context) {
    final user = authState.user;
    final name = user?.displayName ?? user?.email ?? '';
    final isPremium = authState.isPremium;
    // Email sub-line is only meaningful when the display name is being
    // shown — otherwise the title text already shows the email and we'd
    // just be repeating it. We read it once and pin to a non-null local
    // so the analyzer doesn't flag the conditional access as dead.
    final hasDisplayName = user?.displayName != null;
    final emailSubtitle = hasDisplayName ? user?.email : null;

    final theme = Theme.of(context);
    // Use the *card* surface for the bar background, not the scaffold. In
    // dark mode `scaffoldBackgroundColor` is `darkScaffold` (very dark),
    // while the cards underneath are `darkSurfaceContainer` — using the
    // scaffold color creates a visible bar/block split at the top.
    return SliverAppBar.medium(
      automaticallyImplyLeading: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        tr(locState, 'settings'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.md,
              bottom: AppSpacing.md,
              end: AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UserAvatar(
                photoUrl: user?.photoUrl,
                fallbackName: name,
                radius: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _PlanBadge(isPremium: isPremium, locState: locState),
                      ],
                    ),
                    if (emailSubtitle != null)
                      Text(
                        emailSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Only show the Edit button for authed users — for guests
              // the row below ("Sign in") is the entry point, and the
              // Edit button would silently push an empty profile.
              if (authState.isAuthenticated)
                OutlinedButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UserProfileScreen(),
                        ),
                      ),
                  icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 16),
                  label: Text(tr(locState, 'edit_profile')),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.isPremium, required this.locState});
  final bool isPremium;
  final LocalizationState locState;

  @override
  Widget build(BuildContext context) {
    final key = isPremium ? 'premium_badge' : 'free_badge';
    final color =
        isPremium
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: AppInsets.badgePadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        locState.translations[key] ?? (isPremium ? 'Premium' : 'Free'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Account row (kept simple — the heavy lifting is in the hero now) ────

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.authState});
  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    final isAuthed = authState.isAuthenticated;
    final email = authState.user?.email;
    final loc = context.watch<LocalizationCubit>().state;
    if (!isAuthed) {
      // Guest row — no empty email, no premium/free subtitle. Push the
      // user to the login screen rather than into an empty profile.
      return SettingsTile(
        icon: PhosphorIconsRegular.signIn,
        iconColor: Theme.of(context).colorScheme.primary,
        title: loc.translations['sign_in'] ?? 'Sign in',
        subtitle: loc.translations['sign_in_subtitle'] ?? 'Sync your itinerary and favorites',
        trailing: Icon(
          PhosphorIconsRegular.caretRight,
          size: 16,
          color: Theme.of(context).colorScheme.outline,
        ),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
        },
      );
    }
    return SettingsTile(
      icon: PhosphorIconsRegular.userCircle,
      iconColor: Theme.of(context).colorScheme.primary,
      title: email ?? loc.translations['account'] ?? 'Account',
      subtitle:
          authState.isPremium
              ? (loc.translations['premium_badge'] ?? 'Premium')
              : (loc.translations['free_badge'] ?? 'Free'),
      trailing: Icon(
        PhosphorIconsRegular.caretRight,
        size: 16,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const UserProfileScreen()));
      },
    );
  }
}

// ── Tour preferences tiles ──────────────────────────────────────────────

class _AutoPlayTile extends StatefulWidget {
  const _AutoPlayTile();
  @override
  State<_AutoPlayTile> createState() => _AutoPlayTileState();
}

class _AutoPlayTileState extends State<_AutoPlayTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = SharedPrefsService.instance.autoPlayOnArrival;
  }

  Future<void> _onChange(bool v) async {
    setState(() => _value = v);
    await SharedPrefsService.instance.setAutoPlayOnArrival(v);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return SettingsSwitchTile(
      icon: Icons.play_circle_outline,
      iconColor: Theme.of(context).colorScheme.primary,
      title: loc.translations['auto_play_on_arrival'] ?? 'Auto-play on arrival',
      subtitle:
          loc.translations['auto_play_on_arrival_subtitle'] ??
          'Start narration as soon as you enter a site',
      value: _value,
      onChanged: _onChange,
    );
  }
}

class _DistanceUnitsTile extends StatefulWidget {
  const _DistanceUnitsTile();
  @override
  State<_DistanceUnitsTile> createState() => _DistanceUnitsTileState();
}

class _DistanceUnitsTileState extends State<_DistanceUnitsTile> {
  late String _units;

  @override
  void initState() {
    super.initState();
    _units = SharedPrefsService.instance.distanceUnits;
  }

  Future<void> _onChange(String v) async {
    setState(() => _units = v);
    await SharedPrefsService.instance.setDistanceUnits(v);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return SettingsSegmentedTile<String>(
      icon: Icons.straighten,
      iconColor: context.semanticColors.info,
      options: [
        loc.translations['units_metric'] ?? 'Metric',
        loc.translations['units_imperial'] ?? 'Imperial',
      ],
      values: const ['metric', 'imperial'],
      value: _units,
      onChanged: _onChange,
    );
  }
}

class _ReduceMotionTile extends StatefulWidget {
  const _ReduceMotionTile();
  @override
  State<_ReduceMotionTile> createState() => _ReduceMotionTileState();
}

class _ReduceMotionTileState extends State<_ReduceMotionTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = SharedPrefsService.instance.reduceMotion;
  }

  Future<void> _onChange(bool v) async {
    setState(() => _value = v);
    await SharedPrefsService.instance.setReduceMotion(v);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return SettingsSwitchTile(
      icon: Icons.motion_photos_off_outlined,
      iconColor: Colors.deepPurpleAccent,
      title: loc.translations['reduce_motion'] ?? 'Reduce motion',
      subtitle:
          loc.translations['reduce_motion_subtitle'] ??
          'Disable hero crossfades and the arrival pulse',
      value: _value,
      onChanged: _onChange,
    );
  }
}

class _PlaybackSpeedTile extends StatefulWidget {
  const _PlaybackSpeedTile();
  @override
  State<_PlaybackSpeedTile> createState() => _PlaybackSpeedTileState();
}

class _PlaybackSpeedTileState extends State<_PlaybackSpeedTile> {
  static const List<double> _options = [0.75, 1.0, 1.25, 1.5];
  late double _speed;

  @override
  void initState() {
    super.initState();
    _speed = SharedPrefsService.instance.playbackSpeed;
  }

  Future<void> _onChange(double v) async {
    setState(() => _speed = v);
    await SharedPrefsService.instance.setPlaybackSpeed(v);
    // Apply immediately so the next TTS utterance in this session uses
    // the new rate without requiring an app restart. flutter_tts accepts
    // platform-defined ranges (Android typically [0.5, 2.0]); the value
    // we pass was picked from _options, so it's already in range.
    if (!mounted) return;
    await context.read<SiteDetailCubit>().applyPlaybackSpeed(v);
  }

  String _labelFor(BuildContext context, double v) {
    final loc = context.watch<LocalizationCubit>().state;
    switch (v) {
      case 0.75:
        return loc.translations['speed_0_75x'] ?? '0.75×';
      case 1.25:
        return loc.translations['speed_1_25x'] ?? '1.25×';
      case 1.5:
        return loc.translations['speed_1_5x'] ?? '1.5×';
      case 1.0:
      default:
        return loc.translations['speed_1x'] ?? '1×';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    // Snap persisted value into the option list so the dropdown never
    // shows a stale / unmapped selection on next launch. Use a tolerance
    // instead of `contains` because SharedPreferences round-tripping
    // a double can land on 0.75 ± ε from the literal in _options.
    double safeValue = 1.0;
    for (final opt in _options) {
      if ((_speed - opt).abs() < 1e-6) {
        safeValue = opt;
        break;
      }
    }
    return SettingsDropdownTile<double>(
      icon: Icons.speed,
      iconColor: context.semanticColors.warning,
      title: loc.translations['playback_speed'] ?? 'Playback speed',
      subtitle: loc.translations['playback_speed_subtitle'] ?? 'Narration pace',
      value: safeValue,
      items: _options,
      labels: _options.map((v) => _labelFor(context, v)).toList(),
      onChanged: (v) {
        if (v != null) _onChange(v);
      },
    );
  }
}

// ── Appearance tiles ────────────────────────────────────────────────────

class _ThemeTile extends StatelessWidget {
  const _ThemeTile();

  String _themeKey(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return SettingsSegmentedTile<String>(
          icon: PhosphorIconsRegular.palette,
          iconColor: Colors.deepPurpleAccent,
          options: [
            loc.translations['theme_light'] ?? 'Light',
            loc.translations['theme_dark'] ?? 'Dark',
            loc.translations['theme_system'] ?? 'System',
          ],
          values: const ['light', 'dark', 'system'],
          value: _themeKey(themeMode),
          onChanged: (v) {
            switch (v) {
              case 'dark':
                context.read<ThemeCubit>().setThemeMode(ThemeMode.dark);
              case 'system':
                context.read<ThemeCubit>().setThemeMode(ThemeMode.system);
              case 'light':
              default:
                context.read<ThemeCubit>().setThemeMode(ThemeMode.light);
            }
          },
        );
      },
    );
  }
}

// ── Languages dropdown tile (generic) ───────────────────────────────────

class _LanguageDropdownTile extends StatelessWidget {
  const _LanguageDropdownTile({
    required this.icon,
    required this.iconColor,
    required this.code,
    required this.items,
    required this.titleKey,
    required this.subtitleKey,
    this.enabled = true,
    required this.onChanged,
  });
  final IconData icon;
  final Color iconColor;
  final String code;
  final List<String> items;
  // Explicit translation keys so the title/subtitle can't get crossed
  // when the items list happens to match AppConstants.uiLanguages by
  // reference — the previous list-identity heuristic was fragile.
  final String titleKey;
  final String subtitleKey;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return SettingsDropdownTile<String>(
      icon: icon,
      iconColor: iconColor,
      title: loc.translations[titleKey] ?? titleKey,
      subtitle: loc.translations[subtitleKey] ?? '',
      value: code,
      items: items,
      labels:
          items
              .map((c) => '${LanguageMeta.flag(c)} ${LanguageMeta.name(c)}')
              .toList(),
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}

// ── Notifications tiles ─────────────────────────────────────────────────

/// Owns the parent `_ArrivalAlertsTile` toggle *and* its sub-tiles so the
/// sub-tiles (radius, quiet-hours) rebuild the moment the parent flips
/// on. Previously each sub-tile read `SharedPrefsService.instance...`
/// directly inside `build()` — which doesn't notify — so toggling the
/// parent left the sub-tiles permanently hidden until the screen was
/// re-entered.
class _ArrivalNotificationsGroup extends StatefulWidget {
  const _ArrivalNotificationsGroup();

  @override
  State<_ArrivalNotificationsGroup> createState() =>
      _ArrivalNotificationsGroupState();
}

class _ArrivalNotificationsGroupState
    extends State<_ArrivalNotificationsGroup> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = SharedPrefsService.instance.arrivalAlertsEnabled;
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    await SharedPrefsService.instance.setArrivalAlertsEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSwitchTile(
          icon: CupertinoIcons.bell_solid,
          iconColor: Colors.amber,
          title: loc.translations['arrival_alerts'] ?? 'Arrival alerts',
          subtitle: loc.translations['arrival_alerts_subtitle'] ?? '',
          value: _enabled,
          onChanged: _toggle,
        ),
        // Sub-tiles render only when the parent toggle is on. Wrapped in
        // AnimatedSize so the appear/disappear is a soft tween rather
        // than a hard cut.
        AnimatedSize(
          duration: AppDurations.collapse,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child:
              _enabled
                  ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsDivider(),
                      _ArrivalRadiusSubTile(),
                    ],
                  )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ArrivalRadiusSubTile extends StatefulWidget {
  const _ArrivalRadiusSubTile();
  @override
  State<_ArrivalRadiusSubTile> createState() => _ArrivalRadiusSubTileState();
}

class _ArrivalRadiusSubTileState extends State<_ArrivalRadiusSubTile> {
  static const List<int> _options = [20, 30, 50, 100];
  late int _radiusMeters;

  @override
  void initState() {
    super.initState();
    _radiusMeters = SharedPrefsService.instance.arrivalAlertsRadiusM;
  }

  Future<void> _onChange(int v) async {
    setState(() => _radiusMeters = v);
    await SharedPrefsService.instance.setArrivalAlertsRadiusM(v);
  }

  String _label(BuildContext context, int m) {
    final loc = context.watch<LocalizationCubit>().state;
    switch (m) {
      case 20:
        return loc.translations['radius_20m'] ?? '20 m';
      case 30:
        return loc.translations['radius_30m'] ?? '30 m';
      case 50:
        return loc.translations['radius_50m'] ?? '50 m';
      case 100:
        return loc.translations['radius_100m'] ?? '100 m';
      default:
        return '$m m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    final safeValue = _options.contains(_radiusMeters) ? _radiusMeters : 30;
    return SettingsDropdownTile<int>(
      icon: Icons.adjust,
      iconColor: Theme.of(context).colorScheme.secondary,
      title: loc.translations['arrival_radius'] ?? 'Arrival radius',
      subtitle: loc.translations['arrival_radius_subtitle'] ?? '',
      value: safeValue,
      items: _options,
      labels: _options.map((m) => _label(context, m)).toList(),
      onChanged: (v) {
        if (v != null) _onChange(v);
      },
    );
  }
}


// ── Storage tiles ───────────────────────────────────────────────────────

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
    final loc = context.read<LocalizationCubit>();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(loc.translate('cache_cleared')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    final sizeLabel =
        _bytes < 0
            ? (loc.translations['cache_size_unknown'] ?? 'Calculating…')
            : _formatBytes(_bytes);
    return SettingsTile(
      icon: CupertinoIcons.trash,
      iconColor: Colors.blueGrey,
      title: loc.translations['clear_map_cache'] ?? 'Clear map cache',
      subtitle: loc.translations['clear_map_cache_subtitle'] ?? '',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sizeLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 12,
              color:
                  _bytes > 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          if (_bytes > 0)
            IconButton(
              icon: Icon(
                CupertinoIcons.clear_circled_solid,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              onPressed: _onClear,
              tooltip: loc.translations['clear_map_cache'] ?? 'Clear map cache',
            ),
        ],
      ),
      // Override default chevron — this row's trailing is the size+clear
      // cluster, not a navigation cue.
    );
  }
}

// ── About tiles ─────────────────────────────────────────────────────────

class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version ?? '1.0.0';
        final build = snap.data?.buildNumber ?? '1';
        final loc = context.watch<LocalizationCubit>().state;
        final value = (loc.translations['app_version_build'] ??
                'Version %s (build %s)')
            .replaceFirst('%s', version)
            .replaceFirst('%s', build);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          leading: SettingsTileIcon(
            icon: PhosphorIconsRegular.info,
            color: Colors.teal,
          ),
          title: Text(
            loc.translations['version'] ?? 'Version',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

class _OpenSourceLicensesTile extends StatelessWidget {
  const _OpenSourceLicensesTile();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return SettingsTile(
      icon: Icons.balance_outlined,
      iconColor: Theme.of(context).colorScheme.primary,
      title: loc.translations['open_source_licenses'] ?? 'Open-source licenses',
      onTap: () async {
        // Pull the real version from PackageInfo instead of hard-coding
        // '1.0.0' — the licenses page lists the app version + build.
        final info = await PackageInfo.fromPlatform();
        if (!context.mounted) return;
        showLicensePage(
          context: context,
          applicationName: 'Stone Town Guide',
          applicationVersion: '${info.version}+${info.buildNumber}',
        );
      },
    );
  }
}

class _ReportAProblemTile extends StatelessWidget {
  const _ReportAProblemTile();

  Future<void> _launch(BuildContext context) async {
    final loc = context.read<LocalizationCubit>();
    // Block mailto entirely when no support email is configured at
    // build time. Shipping a dead 'support@example.com' address is
    // worse than nothing — the user types a report and gets a bounce.
    if (kSupportEmail.isEmpty) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(loc.state.translations['report_a_problem'] ?? 'Report a problem'),
          content: Text(
            loc.state.translations['support_email_not_configured'] ??
                'Email support is not configured in this build. '
                    'Please contact the developer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(loc.state.translations['ok'] ?? 'OK'),
            ),
          ],
        ),
      );
      return;
    }

    final info = await PackageInfo.fromPlatform();
    final subject =
        'Stone Town Guide ${info.version}+${info.buildNumber} — bug';
    final body =
        'Locale: ${loc.state.currentLanguage}\nVersion: ${info.version}+${info.buildNumber}\n\n';
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      queryParameters: {'subject': subject, 'body': body},
    );

    void showError() {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            loc.state.translations['report_email_failed'] ??
                'Could not open your email app — please email support directly.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    try {
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        showError();
        return;
      }
      // launchUrl can still throw on some platforms (missing mailto
      // handler, plugin channel error). Wrap so a swallowed exception
      // never leaves the UI in a hung state.
      await launchUrl(uri);
    } catch (_) {
      showError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    return SettingsTile(
      icon: Icons.bug_report_outlined,
      iconColor: context.semanticColors.warning,
      title: loc.translations['report_a_problem'] ?? 'Report a problem',
      onTap: () => _launch(context),
    );
  }
}

// ── Sign-out footer ─────────────────────────────────────────────────────

class _SignOutFooter extends StatelessWidget {
  const _SignOutFooter({required this.locState, required this.tr});
  final LocalizationState locState;
  final String Function(LocalizationState, String) tr;

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: Text(
              tr(locState, 'sign_out'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(tr(locState, 'sign_out_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(tr(locState, 'cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(tr(locState, 'sign_out')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final authCubit = context.read<AuthCubit>();
    final navigator = Navigator.of(context);
    // Await the cubit transition so the next screen doesn't briefly see
    // a stale `authenticated` state when LoginScreen reads AuthState
    // during its first build.
    await authCubit.signOut();
    // The async signOut may have torn down the widget tree; if the
    // Settings screen is no longer mounted, Navigator state is gone
    // and the AuthCubit listener will route us instead.
    if (!context.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmAndSignOut(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        icon: const Icon(PhosphorIconsRegular.signOut, size: 18),
        label: Text(tr(locState, 'sign_out')),
      ),
    );
  }
}
