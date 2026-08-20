import 'package:flutter/material.dart';

import '../../../core/theme/app_shadows.dart';

/// Standalone marker widget extracted from [HeritageMap]. Renders a small
/// label chip + a circular pin icon. When `selected == true`, the pin pulses
/// gently to draw the user's eye; otherwise a calm static pin is drawn.
class SelectedSiteMarker extends StatefulWidget {
  const SelectedSiteMarker({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.selected = false,
    this.isPicker = false,
  });

  /// Optional label shown above the pin.
  final String? label;

  /// Pin fill colour (typically the category brand colour).
  final Color color;

  /// Icon shown inside the pin (typically a category icon).
  final IconData icon;

  /// Whether this pin represents the currently-selected site. Drives the
  /// pulse animation.
  final bool selected;

  /// Whether this marker is rendered inside an admin coordinate picker; that
  /// variant is slightly larger to be tap-friendly.
  final bool isPicker;

  @override
  State<SelectedSiteMarker> createState() => _SelectedSiteMarkerState();
}

class _SelectedSiteMarkerState extends State<SelectedSiteMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.10)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  late final Animation<double> _halo = Tween<double>(begin: 0.0, end: 0.55)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (widget.selected) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant SelectedSiteMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.selected && oldWidget.selected) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPicker = widget.isPicker;
    final diameter = isPicker
        ? 38.0
        : (widget.selected ? 36.0 : 28.0);
    final shadowColor = Theme.of(context).colorScheme.shadow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: widget.selected
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: widget.selected
                    ? widget.color
                    : Theme.of(context).colorScheme.outlineVariant,
                width: widget.selected ? 1.5 : 0.8,
              ),
              boxShadow: AppShadows.mapPinFor(shadowColor),
            ),
            constraints: BoxConstraints(maxWidth: widget.selected ? 110 : 85),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: widget.selected ? 11 : 9.5,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            // Halo glow when selected.
            final haloAlpha = widget.selected ? _halo.value : 0.0;
            return SizedBox(
              width: diameter * 1.7,
              height: diameter * 1.7,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.selected)
                    Container(
                      width: diameter * 1.5,
                      height: diameter * 1.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(alpha: haloAlpha),
                      ),
                    ),
                  Transform.scale(
                    scale: widget.selected ? _scale.value : 1.0,
                    child: child,
                  ),
                ],
              ),
            );
          },
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: widget.selected ? 3 : 2,
              ),
              boxShadow: AppShadows.mapPinFor(shadowColor),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: isPicker ? 20 : (widget.selected ? 18 : 14),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
