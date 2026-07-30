import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'settings_tile.dart';

/// Dropdown-row inside a settings card. Used for longer lists where a
/// `SegmentedButton` would overflow — typically language pickers (7
/// entries). When [enabled] is false a 🔒 icon is shown next to the
/// value and the dropdown is disabled, used to gate premium-only
/// options.
class SettingsDropdownTile<T extends Object> extends StatelessWidget {

  const SettingsDropdownTile({
    super.key,
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
  final T value;
  final List<T> items;
  final List<String> labels;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final valueIsMember = items.contains(value);
    final effectiveValue = valueIsMember ? value : items.first;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      leading: SettingsTileIcon(
        icon: icon,
        color: enabled ? iconColor : AppColors.textHint,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: enabled
                  ? Theme.of(context).colorScheme.onSurface
                  : AppColors.textHint,
            ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppColors.textHint,
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
          DropdownButton<T>(
            value: effectiveValue,
            underline: const SizedBox(),
            icon: const Icon(CupertinoIcons.chevron_down, size: 16),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: enabled
                      ? Theme.of(context).colorScheme.onSurface
                      : AppColors.textHint,
                  fontWeight: FontWeight.w500,
                  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                ),
            items: [
              for (var i = 0; i < items.length; i++)
                DropdownMenuItem<T>(
                  value: items[i],
                  child: Text(labels[i]),
                ),
            ],
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}