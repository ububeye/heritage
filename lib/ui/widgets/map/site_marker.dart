import 'package:flutter/material.dart';

import '../../../core/theme/app_shadows.dart';

/// Compact, static map-pin marker for un-selected heritage sites. The
/// selected variant lives in [SelectedSiteMarker] and adds a pulse animation.
class SiteMarker extends StatelessWidget {
  const SiteMarker({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.isPicker = false,
  });

  /// Optional label rendered above the pin.
  final String? label;

  /// Pin fill colour (typically the category brand colour).
  final Color color;

  /// Icon inside the pin.
  final IconData icon;

  /// Whether this is rendered inside the admin coordinate picker. Picker
  /// pins are slightly larger so they can be tapped and dragged comfortably.
  final bool isPicker;

  @override
  Widget build(BuildContext context) {
    final diameter = isPicker ? 38.0 : 28.0;
    final shadowColor = Theme.of(context).colorScheme.shadow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (label != null && label!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.8,
              ),
              boxShadow: AppShadows.mapPinFor(shadowColor),
            ),
            constraints: const BoxConstraints(maxWidth: 85),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: AppShadows.mapPinFor(shadowColor),
          ),
          child: Center(
            child: Icon(
              icon,
              size: isPicker ? 20 : 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
