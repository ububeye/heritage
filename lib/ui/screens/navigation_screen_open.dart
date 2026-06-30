import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/navigation/navigation_cubit.dart';
import '../../blocs/navigation/navigation_state.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/colors.dart';
import '../../data/models/navigation_state.dart' as nav_model;
import '../../data/models/site_model.dart';
import '../../data/services/routing_service.dart';
import '../../data/services/tile_cache_service.dart';
import '../widgets/arrival_overlay.dart';

/// Open-source live-navigation screen.
///
/// No Google Maps SDK. No API key. Built on top of:
///   • [FlutterMap] + OpenStreetMap raster tiles for the map
///   • [RoutingService] (OSRM demo, foot profile) for routing geometry
///   • [NavigationCubit] + [LocationService] for arrival detection
///
/// If routing fails (offline, demo endpoint down, bad coords) the route
/// layer silently falls back to a straight line between the user and the
/// destination, so navigation still works.
class NavigationScreenOpen extends StatefulWidget {
  final SiteModel site;

  const NavigationScreenOpen({super.key, required this.site});

  @override
  State<NavigationScreenOpen> createState() => _NavigationScreenOpenState();
}

class _NavigationScreenOpenState extends State<NavigationScreenOpen> {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  bool _showArrivalOverlay = false;

  /// Cached at [didChangeDependencies] time. We must not call
  /// `context.read<NavigationCubit>()` from [dispose] because by then the
  /// element tree is deactivated and Flutter will throw
  /// "Looking up a deactivated widget's ancestor is unsafe."
  NavigationCubit? _navigationCubit;

  /// Current route polyline. Two points (start/end) when in fallback mode.
  List<LatLng> _routePoints = const [];

  /// True when no usable polyline is available yet (route still fetching).
  bool _routeLoading = true;

  /// True when we ended up rendering a straight-line fallback. Surfaced as a
  /// subtle banner so the user knows the line isn't road-snapped.
  bool _routeIsFallback = false;

  String? _routeError;

  /// Stone Town / Zanzibar City centre (Unguja, Tanzania). Used as a
  /// hard-clamped default origin when the user's GPS fix isn't available
  /// yet — keeps OSRM from snapping "nearest road" to a highway thousands
  /// of kilometres away.
  ///
  /// Roughly the Forodhani Gardens waterfront — a known, well-mapped
  /// pedestrian area in Stone Town.
  static const LatLng _stoneTownFallbackOrigin = LatLng(-6.1619, 39.1936);

  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the cubit reference while the inherited-widget tree is still
    // mounted. [dispose] is called *after* the element is deactivated, so
    // `context.read` from there is unsafe — the cached reference is.
    _navigationCubit = context.read<NavigationCubit>();
  }

  void _startNavigation() {
    _navigationCubit?.startNavigation(
          siteId: widget.site.id,
          siteLat: widget.site.latitude,
          siteLng: widget.site.longitude,
          entryRadiusM: widget.site.entryRadiusM,
        );
  }

  /// Pull a foot route from OSRM between the user (or, if unknown, the
  /// Stone Town centre) and the destination.
  Future<void> _fetchRoute(LatLng? origin) async {
    final destination = LatLng(widget.site.latitude, widget.site.longitude);

    // First start: no user position yet — use a Stone Town centre offset so
    // we still get *some* reasonable road geometry.
    //
    // OSRM is a global router — if we hand it an origin that's somewhere
    // outside the OSM coverage for this region, it'll happily snap the
    // "nearest road" to a highway in another country. Hard-clamp the
    // default origin to a known Stone Town anchor so the demo server
    // resolves to a footpath on Unguja, not a trunk road across the Indian
    // Ocean.
    final effectiveOrigin = origin ?? _stoneTownFallbackOrigin;

    final result = await _routingService.getRoute(
      from: effectiveOrigin,
      to: destination,
    );

    if (!mounted) return;

    setState(() {
      _routePoints = result.points;
      _routeLoading = false;
      _routeIsFallback = result.isFallback;
      _routeError = result.errorMessage;
    });
  }

  /// Compute bounding box that contains the user, the destination, and the
  /// route. Used to fit the camera on first map ready.
  List<LatLng> _allPoints(LatLng? user) {
    final pts = <LatLng>[
      LatLng(widget.site.latitude, widget.site.longitude),
      if (user != null) user,
      ..._routePoints,
    ];
    return pts;
  }

  @override
  void dispose() {
    // Use the cached reference — `context` is deactivated here, so
    // `context.read` would throw "Looking up a deactivated widget's
    // ancestor is unsafe." The cubit was resolved in
    // [didChangeDependencies], while the tree was still live.
    _navigationCubit?.stopNavigation();
    _routingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NavigationCubit, NavigationCubitState>(
      listener: (context, state) {
        // Show arrival overlay once.
        if (state.navigationState.status == nav_model.NavigationStatus.arrived &&
            !_showArrivalOverlay) {
          setState(() => _showArrivalOverlay = true);
        }

        // Pull a route on the first known user position.
        final pos = state.navigationState.currentPosition;
        if (_routeLoading && pos != null) {
          _fetchRoute(LatLng(pos.latitude, pos.longitude));
        }

        // Camera follow on subsequent updates.
        if (pos != null) {
          final user = LatLng(pos.latitude, pos.longitude);
          _mapController.move(user, _mapController.camera.zoom);
        }
      },
      builder: (context, state) {
        final navState = state.navigationState;
        final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;
        final userLatLng = navState.currentPosition == null
            ? null
            : LatLng(
                navState.currentPosition!.latitude,
                navState.currentPosition!.longitude,
              );

        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    widget.site.latitude,
                    widget.site.longitude,
                  ),
                  initialZoom: AppConstants.defaultZoom,
                  onMapReady: () {
                    // Fit to route + site + user on first ready.
                    final pts = _allPoints(userLatLng);
                    if (pts.length > 1) {
                      final bounds = LatLngBounds.fromPoints(pts);
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(60),
                          maxZoom: 17,
                        ),
                      );
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.stone_town_heritage_vt_guide',
                    maxNativeZoom: 19,
                    tileProvider: TileCacheService.instance.tileProvider(),
                  ),
                  if (_routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: AppColors.mapRoute,
                          strokeWidth: AppConstants.routePolylineWidth,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Destination marker (red).
                      Marker(
                        point: LatLng(
                          widget.site.latitude,
                          widget.site.longitude,
                        ),
                        width: 40,
                        height: 40,
                        child: const _DestinationMarker(),
                      ),
                      // User marker (blue dot). Only render once we know
                      // where the user is.
                      if (userLatLng != null)
                        Marker(
                          point: userLatLng,
                          width: 22,
                          height: 22,
                          child: const _UserMarker(),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      const TextSourceAttribution('© OpenStreetMap contributors'),
                      TextSourceAttribution(
                        // The actual provider depends on whether an
                        // ORS key was configured at build time and
                        // which one responded. See routing_service.dart.
                        AppConstants.orsApiKey.isNotEmpty
                            ? 'Routing by OpenRouteService / OSRM'
                            : 'Routing by OSRM',
                      ),
                    ],
                  ),
                ],
              ),

              // Back button.
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: FloatingActionButton.small(
                  heroTag: 'nav_back',
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: AppColors.surface,
                  child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                ),
              ),

              // Routing fallback / loading banner. Subtle, top-centre.
              if (_routeLoading || _routeIsFallback)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 64),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _routeLoading
                            ? 'Fetching route…'
                            : (_routeError != null
                                ? 'Route unavailable — showing direct line.\n(${_routeError!})'
                                : 'Showing direct line — road routing offline.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),

              // Arrival overlay.
              if (_showArrivalOverlay)
                ArrivalOverlay(
                  site: widget.site,
                  uiLanguage: uiLanguage,
                  onPlayAudio: () {
                    final audioLang =
                        context.read<LanguageCubit>().state.audioLanguage;
                    final isPremium =
                        context.read<AuthCubit>().state.isPremium;
                    context
                        .read<SiteDetailCubit>()
                        .playAudio(audioLang, isPremium: isPremium);
                    setState(() => _showArrivalOverlay = false);
                  },
                  onClose: () => setState(() => _showArrivalOverlay = false),
                ),

              // Bottom info card.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: widget.site.primaryImage,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 60,
                                  height: 60,
                                  color: AppColors.surfaceDark,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: AppColors.accent,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 60,
                                  height: 60,
                                  color: AppColors.surfaceDark,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.site.getName(uiLanguage),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (navState.distanceToSite != null)
                                    Text(
                                      'Distance: ${_formatDistance(navState.distanceToSite!)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Navigating',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textOnAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (navState.estimatedTime != null)
                          Text(
                            'ETA: ${_formatDuration(navState.estimatedTime!)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '< 1 min';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} min';
    }
    return '${duration.inHours} h ${duration.inMinutes % 60} min';
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mapMarker,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on,
        size: 20,
        color: Colors.white,
      ),
    );
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mapUser,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        size: 14,
        color: Colors.white,
      ),
    );
  }
}
