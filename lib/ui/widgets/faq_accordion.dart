import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';

/// Static FAQ list rendered on the upgrade screen. Each entry is an
/// [ExpansionTile] so the screen stays single-scroll and the FAQ scales
/// with content.
class FaqAccordion extends StatelessWidget {
  const FaqAccordion({
    super.key,
    required this.entries,
    this.title = 'Frequently asked questions',
  });

  final String title;
  final List<FaqEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.badgeBorder,
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.dividerColor,
                  ),
                _FaqTile(entry: entries[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class FaqEntry {
  const FaqEntry({required this.question, required this.answer, this.icon});
  final String question;
  final String answer;

  /// Optional leading icon shown next to the question when expanded.
  final IconData? icon;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry});
  final FaqEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: scheme.primary.withValues(alpha: 0.06),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: entry.icon != null
            ? Icon(entry.icon, color: scheme.primary, size: 22)
            : null,
        title: Text(
          entry.question,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 15,
                color: scheme.onSurface,
              ),
        ),
        iconColor: scheme.primary,
        collapsedIconColor: scheme.onSurface.withValues(alpha: 0.5),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.answer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
