import 'package:flutter/material.dart';

/// Uppercase letter-spaced section header used to introduce a settings
/// group. Takes a [label] directly (callers resolve the i18n key before
/// passing it in — keeps the widget itself translation-agnostic and
/// reusable from screens that don't share the same key namespace, e.g.
/// admin settings).
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    // Resolve at build time so light + dark both pick the right muted color
    // — onSurfaceVariant is the M3-recommended muted tone for
    // both brightness modes.
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}
