import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';

/// A rounded surface used to group settings tiles. Replaces the
/// `_SettingsCard` previously inlined in `settings_screen.dart` and
/// `admin_settings_screen.dart`. Styling is the same — M3 surface, the
/// existing card radius, and the low shadow — so the two screens stay
/// visually consistent without copy-paste.
class SettingsCard extends StatelessWidget {

  const SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.lowFor(theme.brightness),
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

/// 1px hairline divider aligned with the start of the title text
/// (after the icon column). Used between settings tiles inside a
/// [SettingsCard] so the grouping reads as one card.
class SettingsDivider extends StatelessWidget {

  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56), // Align with title text
      child: Divider(
        height: 1,
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.5),
      ),
    );
  }
}