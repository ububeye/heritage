import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_semantic_colors.dart';

/// Renders the walking-route polyline on top of the basemap.
///
/// The route is a 2-stroke polyline: a wider white underlay (for a halo
/// effect on light tiles) and a tinted foreground. The foreground colour
/// switches to an amber warning tint when [isOffRoute] is true, so the user
/// can see at a glance that the route has been invalidated and a reroute is
/// in flight.
class RoutePolylineLayer extends StatelessWidget {
  const RoutePolylineLayer({
    super.key,
    required this.points,
    this.isOffRoute = false,
    this.underlayColor,
    this.routeColor,
    this.warningColor,
    this.underlayWidthDelta = 4,
  });

  /// Ordered route geometry.
  final List<LatLng> points;

  /// Whether the user currently violates off-route threshold. Drives the
  /// amber tint.
  final bool isOffRoute;

  /// Optional override for the underlay stroke colour (typically white).
  final Color? underlayColor;

  /// Optional override for the normal on-route stroke colour.
  final Color? routeColor;

  /// Optional override for the off-route stroke colour.
  final Color? warningColor;

  /// Extra pixels added to the underlay width to create the halo effect.
  final double underlayWidthDelta;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }
    final fg = isOffRoute
        ? (warningColor ?? context.semanticColors.warning)
        : (routeColor ?? context.semanticColors.mapRoute);
    final bg = underlayColor ?? context.semanticColors.onImage;

    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          color: bg,
          strokeWidth: AppConstants.routePolylineWidth + underlayWidthDelta,
        ),
        Polyline(
          points: points,
          color: fg,
          strokeWidth: AppConstants.routePolylineWidth,
        ),
      ],
    );
  }
}
