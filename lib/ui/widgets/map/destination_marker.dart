import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Final-destination pin. Renders a larger red teardrop pin with a flag
/// glyph at the top. Pairs with [UserMarker] and the route polyline to
/// signal where the user is heading.
///
/// Like [UserMarker], this is a headless widget — wrap in `Marker(...)`
/// from `flutter_map` at the call site.
class DestinationMarker extends StatelessWidget {
  const DestinationMarker({super.key, this.color, this.label});

  /// Pin fill colour. Defaults to error (red) so it stands out from the
  /// blue user marker and the brand-coloured category pins.
  final Color? color;

  /// Optional label rendered below the flag (e.g. "Forodhani Gardens").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pinColor = color ?? scheme.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (label != null && label!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: pinColor, width: 1.2),
              ),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        Icon(
          PhosphorIconsFill.mapPin,
          color: pinColor,
          size: 36,
          shadows: const [
            Shadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ],
    );
  }
}
