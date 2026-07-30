import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';

/// Square leading icon chip with a tinted background. Mirrors the
/// `_ModernIcon` helper previously inlined in `settings_screen.dart`.
class SettingsTileIcon extends StatelessWidget {
  const SettingsTileIcon({super.key, required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.smBorder,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Plain settings row: leading icon, title, optional subtitle, optional
/// trailing widget, optional onTap. The Material-y defaults come from the
/// app's [ListTileTheme] / [ThemeData.listTileTheme]; we set explicit
/// padding only.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      leading: SettingsTileIcon(icon: icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
              : null,
      trailing:
          trailing ??
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
      onTap: onTap,
    );
  }
}

/// Switch variant of [SettingsTile] — convenience for boolean toggles so
/// callers don't have to assemble the trailing `Switch.adaptive` manually.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      secondary: SettingsTileIcon(icon: icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
              : null,
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: onChanged,
    );
  }
}
