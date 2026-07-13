import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show Path;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/navigation/navigation_cubit.dart';
import '../../blocs/navigation/navigation_state.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/polyline_snap.dart';
import '../../core/utils/stone_town_bounds.dart';
import '../../data/models/navigation_state.dart' as nav_model;
import '../../data/models/site_model.dart';
import '../../data/services/route_cache_service.dart';
import '../../data/services/routing_service.dart';
import '../../data/services/tile_cache_service.dart';
import '../widgets/arrival_overlay.dart';

/// Stone Town live-navigation screen.
///
/// Polished Google-Maps-style navigation on top of `flutter_map` + OpenStreetMap.
/// Built for a 1.4 km × 1.7 km heritage peninsula — the camera is clamped to
/// the Stone Town box, so the user can never pan out to see the rest of
/// Unguja or empty ocean.
class NavigationScreenOpen extends StatefulWidget {
  const NavigationScreenOpen({super.key, required this.site});
  final SiteModel site;

  @override
  State<NavigationScreenOpen> createState() => _NavigationScreenOpenState();
}

class _NavigationScreenOpenState extends State<NavigationScreenOpen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final RoutingService _routingService =
      RoutingService(routeCache: FirestoreRouteCache());
  bool _showArrivalOverlay = false;

  /// Cached at [didChangeDependencies] time. We must not call
  /// `context.read<NavigationCubit>()` from [dispose] because by then the
  /// element tree is deactivated and Flutter will throw
  /// "Looking up a deactivated widget's ancestor is unsafe."
  NavigationCubit? _navigationCubit;

  /// Guard so we only kick off the cubit once even if `didChangeDependencies`
  /// runs again (locale change, MediaQuery update, etc.).
  bool _started = false;

  /// Route polyline points. Two points (start/end) when in fallback mode.
  List<LatLng> _routePoints = const [];

  /// Turn-by-turn steps parsed from OSRM. Empty on a fallback route.
  List<RouteStep> _routeSteps = const [];

  /// Index into [_routeSteps] of the step the user is currently on.
  /// Recomputed in the BlocConsumer listener on each GPS update.
  int _activeStepIndex = 0;

  /// Destination marker position. Initially the raw site coords; once the
  /// route polyline is available it snaps to the nearest polyline vertex
  /// so the marker visibly sits on the road.
  LatLng? _snappedDestination;
  bool _routeLoading = true;
  bool _routeIsFallback = false;
  String? _routeError;

  /// Incremented on each `_fetchRoute` call so a late OSRM response from a
  /// previous site can't overwrite the current one.
  int _routeRequestId = 0;

  /// Animation ticker that drives the smooth camera-follow.
  Ticker? _cameraTicker;
  LatLng? _cameraTickerStart;
  LatLng? _cameraTickerEnd;
  LatLng? _lastUserPosition;
  bool _userInsideBox = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigationCubit ??= context.read<NavigationCubit>();
    if (!_started) {
      _started = true;
      _startNavigation();
    }
  }

  void _startNavigation() {
    _navigationCubit?.startNavigation(
      siteId: widget.site.id,
      siteLat: widget.site.latitude,
      siteLng: widget.site.longitude,
      entryRadiusM: widget.site.entryRadiusM,
    );
  }

  Future<void> _fetchRoute(LatLng origin) async {
    final destination = LatLng(widget.site.latitude, widget.site.longitude);
    final myId = ++_routeRequestId;

    final result = await _routingService.getRoute(
      from: origin,
      to: destination,
      site: widget.site,
    );

    if (!mounted || myId != _routeRequestId) return;

    // Snap destination to polyline as soon as the route is available —
    // the marker should sit on the road, not 5 m into a doorway.
    final snapped = result.points.length >= 2
        ? PolylineSnap.snapToPolyline(destination, result.points)
        : null;

    setState(() {
      _routePoints = result.points;
      _routeSteps = result.steps;
      _activeStepIndex = 0;
      _snappedDestination = snapped;
      _routeLoading = false;
      _routeIsFallback = result.isFallback;
      _routeError = result.errorMessage;
    });
  }

  /// Animate the camera from its current centre to [target] in
  /// [AppConstants.navigationAnimationMs], preserving zoom and rotation.
  void _animateCameraTo(LatLng target) {
    final clamped = StoneTownBounds.contains(target)
        ? target
        : StoneTownBounds.centre;
    if (_lastUserPosition != null &&
        _lastUserPosition!.latitude == clamped.latitude &&
        _lastUserPosition!.longitude == clamped.longitude) {
      return;
    }
    _lastUserPosition = clamped;

    final camera = _mapController.camera;
    final start = camera.center;
    if (start.latitude == clamped.latitude &&
        start.longitude == clamped.longitude) {
      return;
    }

    _cameraTicker?.dispose();
    _cameraTickerStart = start;
    _cameraTickerEnd = clamped;
    _cameraTicker = createTicker((elapsed) {
      final t = (elapsed.inMicroseconds / 1000.0 /
              AppConstants.navigationAnimationMs)
          .clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(t);
      final lat = _lerp(
        _cameraTickerStart!.latitude,
        _cameraTickerEnd!.latitude,
        eased,
      );
      final lng = _lerp(
        _cameraTickerStart!.longitude,
        _cameraTickerEnd!.longitude,
        eased,
      );
      _mapController.move(LatLng(lat, lng), camera.zoom);

      if (t >= 1.0) {
        _cameraTicker?.stop();
        _cameraTicker?.dispose();
        _cameraTicker = null;
      }
    })
      ..start();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _fitInitial(LatLng user) {
    final pts = <LatLng>[
      LatLng(widget.site.latitude, widget.site.longitude),
      user,
      ..._routePoints,
    ];
    if (pts.length < 2) {
      _mapController.move(
        StoneTownBounds.contains(user) ? user : StoneTownBounds.centre,
        AppConstants.defaultZoom,
      );
      return;
    }
    final bounds = LatLngBounds.fromPoints(pts);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 160, 60, 200),
        maxZoom: AppConstants.markerZoom,
        minZoom: AppConstants.stoneTownMinZoom,
      ),
    );
  }

  @override
  void dispose() {
    _cameraTicker?.dispose();
    _navigationCubit?.stopNavigation();
    _routingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NavigationCubit, NavigationCubitState>(
      listenWhen: (prev, next) =>
          prev.navigationState.status != next.navigationState.status ||
          prev.navigationState.currentPosition !=
              next.navigationState.currentPosition,
      listener: (context, state) {
        final navState = state.navigationState;
        final pos = navState.currentPosition;
        final posLatLng = pos == null ? null : LatLng(pos.latitude, pos.longitude);

        // 1. Pull a route once we know where the user is.
        if (_routeLoading && posLatLng != null) {
          _fetchRoute(
            StoneTownBounds.contains(posLatLng)
                ? posLatLng
                : StoneTownBounds.centre,
          );
          _fitInitial(
            StoneTownBounds.contains(posLatLng)
                ? posLatLng
                : StoneTownBounds.centre,
          );
        }

        // 2. Camera follow on each subsequent update — animated.
        if (posLatLng != null && !_routeLoading) {
          _animateCameraTo(posLatLng);
        }

        // 2b. Advance the active turn-by-turn step when the user passes
        //     a maneuver point. Only meaningful once steps have been
        //     loaded; ignore on the initial pre-route state.
        if (posLatLng != null && _routeSteps.isNotEmpty) {
          final newIdx =
              RoutingService.currentStepIndex(_routeSteps, posLatLng);
          if (newIdx != _activeStepIndex) {
            setState(() => _activeStepIndex = newIdx);
          }
        }

        // 3. Track whether the user is inside the box (drives a subtle
        //    banner so they know GPS hasn't locked onto Stone Town yet).
        if (posLatLng != null) {
          final inside = StoneTownBounds.contains(posLatLng);
          if (inside != _userInsideBox) {
            setState(() => _userInsideBox = inside);
          }
        }

        // 4. Show arrival overlay once. Gated by the arrival-alerts preference
//    so users who turned off the welcome card in Settings don't get a
//    surprise modal as they walk through Stone Town.
        if (navState.status == nav_model.NavigationStatus.arrived &&
            !_showArrivalOverlay &&
            SharedPrefsService.instance.arrivalAlertsEnabled) {
          setState(() => _showArrivalOverlay = true);
        }

        // 5. Error state → stop animating so the user can re-tap recenter.
        if (navState.status == nav_model.NavigationStatus.error) {
          _cameraTicker?.stop();
          _cameraTicker?.dispose();
          _cameraTicker = null;
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
              _buildMap(context, userLatLng),
              _buildTopBar(context),
              _buildBanner(context, navState),
              _buildBottomCard(context, navState, uiLanguage),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(BuildContext context, LatLng? userLatLng) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: StoneTownBounds.centre,
        initialZoom: AppConstants.defaultZoom,
        minZoom: AppConstants.stoneTownMinZoom,
        maxZoom: AppConstants.stoneTownMaxZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        cameraConstraint: CameraConstraint.contain(
          bounds: StoneTownBounds.cameraBounds,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.stone_town_heritage_vt_guide',
          maxNativeZoom: AppConstants.stoneTownMaxZoom.toInt(),
          tileProvider: TileCacheService.instance.tileProvider(),
        ),
        // Route polyline — drawn as two stacked layers for a crisp
        // white-bordered look that matches Google Maps.
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: Colors.white,
                strokeWidth: AppConstants.routePolylineWidth + 4,
              ),
              Polyline(
                points: _routePoints,
                color: AppColors.mapRoute,
                strokeWidth: AppConstants.routePolylineWidth,
              ),
            ],
          ),
        // Arrival-zone visualisation — translucent circle around the
        // destination so the user sees how close they have to get.
        CircleLayer(
          circles: [
            CircleMarker(
              point: LatLng(widget.site.latitude, widget.site.longitude),
              radius: widget.site.entryRadiusM,
              useRadiusInMeter: true,
              color: AppColors.primary.withValues(alpha: 0.12),
              borderColor: AppColors.primary.withValues(alpha: 0.45),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Destination — drop-pin marker. Uses the snapped position so
            // it lands on the polyline rather than 5 m off into a
            // doorway; proximity detection still uses the raw coord
            // (see [CircleMarker] above).
            Marker(
              point: _snappedDestination ??
                  LatLng(
                    widget.site.latitude,
                    widget.site.longitude,
                  ),
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: const _DestinationMarker(),
            ),
            // User — pulsing blue dot. Only when GPS is fixed.
            if (userLatLng != null && _userInsideBox)
              Marker(
                point: userLatLng,
                width: 28,
                height: 28,
                child: _UserMarker(),
              ),
          ],
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            const TextSourceAttribution('© OpenStreetMap contributors'),
            TextSourceAttribution(
              AppConstants.orsApiKey.isNotEmpty
                  ? 'Routing by OpenRouteService / OSRM'
                  : 'Routing by OSRM',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          FloatingActionButton.small(
            heroTag: 'nav_back',
            onPressed: () => Navigator.of(context).pop(),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 4,
            child: const Icon(Icons.arrow_back),
          ),
          const Spacer(),
          FloatingActionButton.small(
            heroTag: 'nav_recenter',
            onPressed: () => _recenter(),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 4,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  void _recenter() {
    final nav = _navigationCubit?.state.navigationState;
    final pos = nav?.currentPosition;
    final raw = (pos != null)
        ? LatLng(pos.latitude, pos.longitude)
        : StoneTownBounds.centre;
    final target = StoneTownBounds.contains(raw) ? raw : StoneTownBounds.centre;

    // _fitInitial drives the camera via the map controller; stop any
    // in-flight animation so the two don't fight each other.
    _cameraTicker?.stop();
    _cameraTicker?.dispose();
    _cameraTicker = null;
    _lastUserPosition = null;

    _fitInitial(target);
  }

  /// Banner shown above the map while the route is loading or when the
  /// engine fell back to a straight line.
  Widget _buildBanner(BuildContext context, nav_model.NavigationState nav) {
    final hasError = nav.status == nav_model.NavigationStatus.error;
    if (!_routeLoading && !_routeIsFallback && !hasError) {
      return const SizedBox.shrink();
    }
    final color = hasError ? AppColors.error : Colors.black87;
    final text = hasError
        ? (nav.errorMessage ?? 'Navigation unavailable')
        : _routeLoading
            ? 'Fetching route…'
            : (_routeError != null
                ? 'Routing offline — direct line.\n${_routeError!}'
                : 'Routing offline — direct line.');

    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          color: color,
          elevation: 2,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard(
    BuildContext context,
    nav_model.NavigationState nav,
    String uiLanguage,
  ) {
    final arrived = nav.status == nav_model.NavigationStatus.arrived;
    final hasError = nav.status == nav_model.NavigationStatus.error;
    final statusChip = hasError
        ? _StatusChip(
            label: 'Error',
            color: AppColors.error,
            foreground: AppColors.textOnPrimary,
            icon: Icons.error_outline,
          )
        : arrived
            ? _StatusChip(
                label: 'Arrived',
                color: AppColors.primary,
                foreground: AppColors.textOnPrimary,
                icon: Icons.check_circle,
              )
            : _StatusChip(
                label: 'Navigating',
                color: AppColors.primary,
                foreground: AppColors.textOnPrimary,
                icon: Icons.directions_walk,
              );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.site.primaryImage,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.surfaceDark,
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.surfaceDark,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.site.getName(uiLanguage),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.straighten,
                                  size: 14, color: AppColors.textSecondary,),
                              const SizedBox(width: 4),
                              Text(
                                nav.distanceToSite != null
                                    ? _formatDistance(nav.distanceToSite!)
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.access_time,
                                  size: 14, color: AppColors.textSecondary,),
                              const SizedBox(width: 4),
                              Text(
                                nav.estimatedTime != null
                                    ? _formatDuration(nav.estimatedTime!)
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    statusChip,
                  ],
                ),
                // Turn-by-turn instruction row. Hidden on fallback routes
                // (no step data) and on the arrived state (the destination
                // overlay covers navigation). Sits just above the action
                // button so the eye reads "next move → action".
                if (_routeSteps.isNotEmpty &&
                    !arrived)
                  _buildTurnInstructionRow(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '< 1 min';
    if (d.inHours < 1) return '${d.inMinutes} min';
    return '${d.inHours} h ${d.inMinutes % 60} min';
  }

  /// Builds the next-maneuver card that sits just above the Stop button
  /// on the bottom sheet. Shows a maneuver icon, the instruction text
  /// ("Turn left onto Kenyatta Rd"), and the remaining distance to the
  /// next turn.
  Widget _buildTurnInstructionRow() {
    final step = _routeSteps[_activeStepIndex.clamp(0, _routeSteps.length - 1)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(step.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDistance(step.distanceMeters)}'
                  '${step.durationSeconds != null ? ' • ${_formatDuration(Duration(seconds: step.durationSeconds!.round()))}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.foreground,
    required this.icon,
  });
  final String label;
  final Color color;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PinPainter(),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Drop-pin shape: filled circle on top, tapered tail to a point.
    final radius = size.width * 0.32;
    final center = Offset(size.width / 2, radius + 4);
    final tailBottom = Offset(size.width / 2, size.height - 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + const Offset(0, 1), radius, shadowPaint);

    final fill = Paint()..color = AppColors.mapMarker;
    final stroke = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);

    final tail = ui.Path()
      ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.6)
      ..lineTo(tailBottom.dx, tailBottom.dy)
      ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.6)
      ..close();
    canvas.drawPath(tail, fill);
    canvas.drawPath(tail, stroke);

    // Inner dot
    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.35, inner);
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => false;
}

class _UserMarker extends StatefulWidget {
  @override
  State<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<_UserMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final pulse = math.sin(t * math.pi); // 0..1..0 over the loop
        return Stack(
          alignment: Alignment.center,
          children: [
            // Expanding pulse ring.
            Container(
              width: 28 + pulse * 18,
              height: 28 + pulse * 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mapUser.withValues(alpha: 0.18 * (1 - pulse)),
              ),
            ),
            // Solid dot.
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.mapUser,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}