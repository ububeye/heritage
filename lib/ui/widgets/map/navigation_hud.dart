import 'package:flutter/material.dart';

import 'compass_overlay.dart';
import 'off_route_banner.dart';

/// Slim header strip rendered above the navigation map.
///
/// Composes the optional off-route banner with the compass overlay. The
/// detailed maneuver card and ETA chip live alongside in [NavigationScreenOpen]
/// because they need access to position/route state that this widget does
/// not own.
class NavigationHud extends StatelessWidget {
  const NavigationHud({
    super.key,
    required this.isRerouting,
    required this.headingLocked,
    required this.headingDeg,
  });

  /// Whether a reroute is in flight. Drives the off-route banner.
  final bool isRerouting;

  /// Whether the user's heading is locked. Drives the compass visibility.
  final bool headingLocked;

  /// Current heading in degrees. `null` while no fix is available.
  final double? headingDeg;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Stack(
      children: [
        Positioned(
          top: media.padding.top + 8,
          left: 12,
          right: 12,
          child: OffRouteBanner(isVisible: isRerouting),
        ),
        if (headingLocked)
          Positioned(
            right: 16,
            top: media.padding.top + 132,
            child: CompassOverlay(headingDeg: headingDeg),
          ),
      ],
    );
  }
}
