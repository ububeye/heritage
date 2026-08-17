import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/site_model.dart';
import '../../data/services/routing_service.dart';
import '../../core/utils/nav_guard.dart';
import '../../core/theme/app_radius.dart';
import '../widgets/heritage_map.dart';
import '../widgets/map/route_polyline_layer.dart';

/// Full-screen map view for a single site. Shows the site as a labeled pin
/// on an OpenStreetMap tile layer, with a Navigate FAB that pushes the
/// live-navigation screen.
class SiteMapScreen extends StatefulWidget {
  const SiteMapScreen({super.key, required this.site});
  final SiteModel site;

  @override
  State<SiteMapScreen> createState() => _SiteMapScreenState();
}

class _SiteMapScreenState extends State<SiteMapScreen> {
  /// Toggle for the optional "Show route" button in the AppBar. When on,
  /// a route polyline from the user's current GPS to the site is fetched
  /// and rendered over the basemap. Doesn't enter navigation mode.
  bool _showRoute = false;
  bool _routeLoading = false;
  List<LatLng> _routePoints = const [];

  late final RoutingService _routingService = RoutingService();

  Future<void> _fetchRoute() async {
    setState(() => _routeLoading = true);

    Position? pos;
    try {
      // Best-effort current location. We don't gate this on permission
      // failures — the toggle is opt-in and a missing-fix should just
      // leave the polyline empty.
      pos = await _ensurePosition();
    } catch (_) {
      pos = null;
    }

    if (pos == null) {
      if (mounted) setState(() => _routeLoading = false);
      return;
    }

    final origin = LatLng(pos.latitude, pos.longitude);
    final dest = LatLng(widget.site.latitude, widget.site.longitude);
    final result = await _routingService.getRoute(from: origin, to: dest);
    if (!mounted) return;

    setState(() {
      _routeLoading = false;
      _routePoints = result.isFallback ? const [] : result.points;
    });
  }

  Future<Position?> _ensurePosition() async {
    try {
      // Quick path — use the last known position to avoid waiting on a
      // cold-start GPS fix. The toggle is optional and the polyline is
      // purely advisory.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _toggleRoute(bool value) {
    setState(() => _showRoute = value);
    if (value) {
      _fetchRoute();
    } else {
      setState(() => _routePoints = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiLanguage = context.read<LocalizationCubit>().state.currentLanguage;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.site.getName(uiLanguage)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.signpost,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                const Text('Show route'),
                Switch(
                  value: _showRoute,
                  onChanged: _toggleRoute,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          HeritageMap.singleSite(site: widget.site),
          if (_showRoute)
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(widget.site.latitude, widget.site.longitude),
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  if (_routePoints.length >= 2)
                    RoutePolylineLayer(points: _routePoints),
                  if (_routeLoading)
                    const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                ],
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 2,
              borderRadius: AppRadius.mdBorder,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppRadius.mdBorder,
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.mapPin,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.site.displayAddress,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    Text(
                      '${widget.site.latitude.toStringAsFixed(4)}, ${widget.site.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => safePushNavigation(context, widget.site),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(PhosphorIconsFill.navigationArrow),
        label: const Text('Navigate'),
      ),
    );
  }
}
