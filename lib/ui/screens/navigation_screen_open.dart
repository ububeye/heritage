import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show Path;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stone_town_heritage_vt_guide/core/utils/distance_calculator.dart'
    as dc;
import '../../data/services/shared_prefs_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../blocs/navigation/navigation_cubit.dart';
import '../../blocs/navigation/navigation_state.dart';
import '../../blocs/runtime_config/runtime_config_cubit.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_durations.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/polyline_snap.dart';
import '../../core/utils/stone_town_bounds.dart';
import '../../core/utils/unguja_bounds.dart';
import '../../data/models/navigation_state.dart' as nav_model;
import '../../data/models/site_model.dart';
import '../../data/services/route_cache_service.dart';
import '../../data/services/routing_service.dart';
import '../../data/services/tile_cache_service.dart';
import '../widgets/arrival_overlay.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Stone Town live-navigation screen.
///
/// Polished Google-Maps-style navigation on top of `flutter_map` + OpenStreetMap.
/// Features:
///   - Compass-driven map rotation (heading lock) on real devices.
///   - Large top maneuver card with turn icon + distance.
///   - Route progress bar (% completed).
///   - Speed-adaptive zoom (zooms in when close to destination).
///   - Remaining route distance computed from polyline.
///   - Turn-by-turn steps with road name.
class NavigationScreenOpen extends StatefulWidget {
  const NavigationScreenOpen({super.key, required this.site});
  final SiteModel site;

  @override
  State<NavigationScreenOpen> createState() => _NavigationScreenOpenState();
}

class _NavigationScreenOpenState extends State<NavigationScreenOpen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final RoutingService _routingService = RoutingService(
    routeCache: FirestoreRouteCache(),
  );
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

  /// Total route distance in metres (OSRM-reported). Used for progress bar.
  double _totalRouteDistanceM = 0;

  /// Remaining distance along the polyline from user to destination.
  double _remainingRouteDistanceM = 0;

  /// Incremented on each `_fetchRoute` call so a late OSRM response from a
  /// previous site can't overwrite the current one.
  int _routeRequestId = 0;

  /// Animation ticker that drives the smooth camera-follow.
  Ticker? _cameraTicker;
  LatLng? _cameraTickerStart;
  LatLng? _cameraTickerEnd;
  LatLng? _lastUserPosition;
  bool _userInsideBox = true;

  // ── Compass / heading ──────────────────────────────────────────────────────

  /// Current device heading in degrees (0 = north, 90 = east). Sourced from
  /// [Geolocator.getPositionStream] via the `heading` field of each [Position].
  /// Null until the first GPS fix with a valid heading arrives.
  double? _headingDeg;

  /// Whether the map is locked to follow the user's heading (compass mode).
  /// Toggled by the recenter / compass button in the top-right.
  bool _headingLocked = true;

  // ── Speed-adaptive zoom ────────────────────────────────────────────────────

  /// Returns the target zoom level based on remaining distance.
  double _adaptiveZoom(double? distanceM) {
    if (distanceM == null) return AppConstants.defaultZoom;
    if (distanceM < 80) return 19.0;
    if (distanceM < 200) return 18.0;
    if (distanceM < 500) return 17.0;
    return 16.0;
  }

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
      entryRadiusM: SharedPrefsService.instance.arrivalAlertsRadiusM.toDouble(),
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

    // Snap destination to polyline as soon as the route is available.
    final snapped =
        result.points.length >= 2
            ? PolylineSnap.snapToPolyline(destination, result.points)
            : null;

    // Compute total route distance.
    final totalDist =
        result.distanceMeters > 0
            ? result.distanceMeters
            : _computePolylineLength(result.points);

    setState(() {
      _routePoints = result.points;
      _routeSteps = result.steps;
      _activeStepIndex = 0;
      _snappedDestination = snapped;
      _routeLoading = false;
      _routeIsFallback = result.isFallback;
      _routeError = result.errorMessage;
      _totalRouteDistanceM = totalDist;
      _remainingRouteDistanceM = totalDist;
    });
  }

  /// Computes the sum of great-circle distances between consecutive points.
  double _computePolylineLength(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += dc.DistanceCalculator.calculateDistance(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  /// Computes the remaining polyline length from [userPos] to the end of
  /// [_routePoints]. Finds the nearest vertex to the user, then sums
  /// distances from that vertex to the destination.
  double _computeRemainingDistance(LatLng userPos) {
    if (_routePoints.length < 2) return 0;
    // Find the closest point index on the polyline.
    int nearest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _routePoints.length; i++) {
      final d = dc.DistanceCalculator.calculateDistance(
        userPos.latitude,
        userPos.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        nearest = i;
      }
    }
    // Sum the polyline from nearest to end.
    double remaining = minDist; // user to the nearest vertex
    for (int i = nearest; i < _routePoints.length - 1; i++) {
      remaining += dc.DistanceCalculator.calculateDistance(
        _routePoints[i].latitude,
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude,
        _routePoints[i + 1].longitude,
      );
    }
    return remaining;
  }

  /// Animate the camera from its current centre to [target] preserving
  /// zoom and applying heading rotation when [_headingLocked] is true.
  void _animateCameraTo(LatLng target, {double? distanceM}) {
    final clamped =
        UngujaBounds.contains(target) ? target : UngujaBounds.centre;
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

    final targetZoom = _adaptiveZoom(distanceM);

    _cameraTicker?.dispose();
    _cameraTickerStart = start;
    _cameraTickerEnd = clamped;
    _cameraTicker = createTicker((elapsed) {
      final t = (elapsed.inMicroseconds /
              1000.0 /
              AppDurations.navigation.inMilliseconds)
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

      // Apply heading rotation when locked.
      if (_headingLocked && _headingDeg != null) {
        _mapController.moveAndRotate(LatLng(lat, lng), targetZoom, -_headingDeg!);
      } else {
        _mapController.move(LatLng(lat, lng), targetZoom);
      }

      if (t >= 1.0) {
        _cameraTicker?.stop();
        _cameraTicker?.dispose();
        _cameraTicker = null;
      }
    })..start();
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
        UngujaBounds.contains(user) ? user : UngujaBounds.centre,
        AppConstants.defaultZoom,
      );
      return;
    }
    final bounds = LatLngBounds.fromPoints(pts);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 160, 60, 220),
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
      listenWhen:
          (prev, next) =>
              prev.navigationState.status != next.navigationState.status ||
              prev.navigationState.currentPosition !=
                  next.navigationState.currentPosition ||
              (prev.navigationState.errorCode !=
                      next.navigationState.errorCode &&
                  next.navigationState.errorCode == 'permission_denied'),
      listener: (context, state) {
        final navState = state.navigationState;
        final pos = navState.currentPosition;
        final posLatLng =
            pos == null ? null : LatLng(pos.latitude, pos.longitude);

        // 1. Pull a route once we know where the user is.
        if (_routeLoading && posLatLng != null) {
          _fetchRoute(
            UngujaBounds.contains(posLatLng)
                ? posLatLng
                : UngujaBounds.centre,
          );
          _fitInitial(
            UngujaBounds.contains(posLatLng)
                ? posLatLng
                : UngujaBounds.centre,
          );
        }

        // 2. Camera follow on each subsequent update — animated with adaptive zoom.
        if (posLatLng != null && !_routeLoading) {
          _animateCameraTo(
            posLatLng,
            distanceM: navState.distanceToSite,
          );
        }

        // 2b. Update heading from the GPS position.
        if (pos != null && pos.heading != 0.0) {
          if (_headingDeg != pos.heading) {
            setState(() => _headingDeg = pos.heading);
          }
        }

        // 2c. Update remaining polyline distance.
        if (posLatLng != null && _routePoints.length >= 2) {
          final remaining = _computeRemainingDistance(posLatLng);
          if ((remaining - _remainingRouteDistanceM).abs() > 2) {
            setState(() => _remainingRouteDistanceM = remaining);
          }
        }

        // 2d. Advance the active turn-by-turn step.
        if (posLatLng != null && _routeSteps.isNotEmpty) {
          final newIdx = RoutingService.currentStepIndex(
            _routeSteps,
            posLatLng,
          );
          if (newIdx != _activeStepIndex) {
            setState(() => _activeStepIndex = newIdx);
          }
        }

        // 3. Track whether the user is inside the island.
        if (posLatLng != null) {
          final inside = UngujaBounds.contains(posLatLng);
          if (inside != _userInsideBox) {
            setState(() => _userInsideBox = inside);
          }
        }

        // 4. Show arrival overlay once.
        if (navState.status == nav_model.NavigationStatus.arrived &&
            !_showArrivalOverlay &&
            SharedPrefsService.instance.arrivalAlertsEnabled) {
          setState(() => _showArrivalOverlay = true);

          if (SharedPrefsService.instance.autoPlayOnArrival) {
            final audioLang = context.read<LanguageCubit>().state.audioLanguage;
            final isPremium = context.read<AuthCubit>().state.isPremium;
            context.read<SiteDetailCubit>().playAudio(
              audioLang,
              isPremium: isPremium,
            );
          }
        }

        // 5. Error state → stop animating.
        if (navState.status == nav_model.NavigationStatus.error) {
          _cameraTicker?.stop();
          _cameraTicker?.dispose();
          _cameraTicker = null;
        }

        // 6. Permission denied SnackBar.
        if (navState.errorCode == 'permission_denied') {
          final locCubit = context.read<LocalizationCubit>();
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            SnackBar(
              content: Text(locCubit.translate('location_permission_required')),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: locCubit.translate('action_open_settings'),
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final navState = state.navigationState;
        final uiLanguage =
            context.read<LocalizationCubit>().state.currentLanguage;
        final userLatLng =
            navState.currentPosition == null
                ? null
                : LatLng(
                  navState.currentPosition!.latitude,
                  navState.currentPosition!.longitude,
                );

        return Scaffold(
          body: Stack(
            children: [
              _buildMap(context, userLatLng),
              // Google-Maps-style top maneuver card (replaces slim row)
              _buildTopManeuverCard(context, navState),
              _buildBanner(context, navState),
              _buildBottomCard(context, navState, uiLanguage),
              if (_showArrivalOverlay)
                ArrivalOverlay(
                  site: widget.site,
                  uiLanguage: uiLanguage,
                  onPlayAudio: () {
                    final audioLang =
                        context.read<LanguageCubit>().state.audioLanguage;
                    final isPremium = context.read<AuthCubit>().state.isPremium;
                    context.read<SiteDetailCubit>().playAudio(
                      audioLang,
                      isPremium: isPremium,
                    );
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
          // Allow rotate when heading-locked so the compass can drive it;
          // manual finger rotation is still blocked.
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        cameraConstraint: CameraConstraint.contain(
          bounds: UngujaBounds.cameraBounds,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.stonetown.guide',
          maxNativeZoom: 19,
          tileProvider: TileCacheService.instance.tileProvider(),
        ),
        // Route polyline — white border underlay for a crisp look.
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: context.semanticColors.onImage,
                strokeWidth: AppConstants.routePolylineWidth + 4,
              ),
              Polyline(
                points: _routePoints,
                color: context.semanticColors.mapRoute,
                strokeWidth: AppConstants.routePolylineWidth,
              ),
            ],
          ),
        // Arrival-zone translucent circle.
        CircleLayer(
          circles: [
            CircleMarker(
              point: LatLng(widget.site.latitude, widget.site.longitude),
              radius: widget.site.entryRadiusM,
              useRadiusInMeter: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.45),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Destination drop-pin.
            Marker(
              point:
                  _snappedDestination ??
                  LatLng(widget.site.latitude, widget.site.longitude),
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: const _DestinationMarker(),
            ),
            // User — pulsing blue dot. Only when GPS is fixed and on-island.
            if (userLatLng != null && _userInsideBox)
              Marker(
                point: userLatLng,
                width: 28,
                height: 28,
                child: _UserMarker(),
              ),
          ],
        ),
        // Attribution.
        BlocBuilder<RuntimeConfigCubit, RuntimeConfigState>(
          buildWhen: (prev, curr) => prev.orsApiKey != curr.orsApiKey,
          builder: (context, state) {
            return RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                const TextSourceAttribution('© OpenStreetMap contributors'),
                TextSourceAttribution(
                  state.orsApiKey.isNotEmpty
                      ? 'Routing by OpenRouteService / OSRM'
                      : 'Routing by OSRM',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Google Maps-style top maneuver card ─────────────────────────────────

  /// Large card at the very top: left = big turn icon, centre = distance +
  /// street name, right = back + compass buttons stacked.
  Widget _buildTopManeuverCard(
    BuildContext context,
    nav_model.NavigationState nav,
  ) {
    final arrived = nav.status == nav_model.NavigationStatus.arrived;
    final topPad = MediaQuery.of(context).padding.top;

    // When there are no steps yet or already arrived → just show the back row.
    if (_routeSteps.isEmpty || arrived) {
      return _buildMinimalTopBar(context, topPad);
    }

    final step =
        _routeSteps[_activeStepIndex.clamp(0, _routeSteps.length - 1)];
    final loc = context.read<LocalizationCubit>();
    final instruction = step.localizedDescription(loc.translate);
    final distToTurn = _formatDistance(step.distanceMeters);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(0, topPad, 0, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Large turn icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppRadius.mdBorder,
                    ),
                    child: Icon(
                      step.icon,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Distance + instruction
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          distToTurn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Back + compass buttons
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavIconButton(
                        icon: PhosphorIconsRegular.arrowLeft,
                        onPressed: () => Navigator.of(context).pop(),
                        heroTag: 'nav_back',
                      ),
                      const SizedBox(height: 6),
                      _NavIconButton(
                        icon: _headingLocked
                            ? PhosphorIconsRegular.compass
                            : PhosphorIconsRegular.compassTool,
                        onPressed: _toggleHeadingLock,
                        heroTag: 'nav_compass',
                        active: _headingLocked,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Progress bar — fills from left as the route is completed.
            _buildProgressBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalTopBar(BuildContext context, double topPad) {
    return Positioned(
      top: topPad + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          FloatingActionButton.small(
            heroTag: 'nav_back',
            onPressed: () => Navigator.of(context).pop(),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 4,
            child: const Icon(PhosphorIconsRegular.arrowLeft),
          ),
          const Spacer(),
          FloatingActionButton.small(
            heroTag: 'nav_compass',
            onPressed: _toggleHeadingLock,
            backgroundColor: _headingLocked
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            foregroundColor: _headingLocked
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            elevation: 4,
            child: const Icon(PhosphorIconsRegular.compass),
          ),
        ],
      ),
    );
  }

  /// Thin coloured bar at the bottom of the top card showing % completed.
  Widget _buildProgressBar(BuildContext context) {
    double fraction = 0;
    if (_totalRouteDistanceM > 0) {
      fraction = 1.0 -
          (_remainingRouteDistanceM / _totalRouteDistanceM).clamp(0.0, 1.0);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Background track
            Container(
              height: 5,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            // Filled progress
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              height: 5,
              width: constraints.maxWidth * fraction,
              color: Colors.white,
            ),
          ],
        );
      },
    );
  }

  void _toggleHeadingLock() {
    setState(() => _headingLocked = !_headingLocked);
    if (!_headingLocked) {
      // Reset map north-up when unlocking.
      try {
        _mapController.rotate(0);
      } catch (_) {}
    }
    // Recenter on user when re-locking.
    if (_headingLocked) _recenter();
  }

  void _recenter() {
    final nav = _navigationCubit?.state.navigationState;
    final pos = nav?.currentPosition;
    final raw =
        (pos != null)
            ? LatLng(pos.latitude, pos.longitude)
            : UngujaBounds.centre;
    final target = UngujaBounds.contains(raw) ? raw : UngujaBounds.centre;

    _cameraTicker?.stop();
    _cameraTicker?.dispose();
    _cameraTicker = null;
    _lastUserPosition = null;

    _fitInitial(target);
  }

  /// Small banner shown below the top card while route is loading / error /
  /// fallback. Hidden once a clean route is loaded.
  Widget _buildBanner(BuildContext context, nav_model.NavigationState nav) {
    final hasError = nav.status == nav_model.NavigationStatus.error;
    if (!_routeLoading && !_routeIsFallback && !hasError) {
      return const SizedBox.shrink();
    }
    final loc = context.read<LocalizationCubit>();
    String tr(String key) => loc.translate(key);
    final isRoutingAuthFailure = _routeError == 'routing_api_key_invalid';
    final color =
        hasError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurface;
    final text =
        hasError
            ? (nav.errorMessage ?? tr('error_generic'))
            : _routeLoading
            ? tr('loading')
            : (isRoutingAuthFailure
                ? tr('routing_api_key_invalid')
                : (_routeError != null
                    ? '${tr('routing_offline')}\n$_routeError'
                    : tr('routing_offline')));

    // Position below the top card (or top padding if no card yet).
    final topOffset =
        _routeSteps.isEmpty ? MediaQuery.of(context).padding.top + 64 : 160.0;

    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          color: color,
          elevation: 2,
          borderRadius: AppRadius.bannerBorder,
          child: Padding(
            padding: AppInsets.bannerInner,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.surface,
              ),
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
    final statusChip =
        hasError
            ? _StatusChip(
              label: 'Error',
              color: Theme.of(context).colorScheme.error,
              foreground: Theme.of(context).colorScheme.onError,
              icon: PhosphorIconsRegular.warningCircle,
            )
            : arrived
            ? _StatusChip(
              label: 'Arrived',
              color: Theme.of(context).colorScheme.primary,
              foreground: Theme.of(context).colorScheme.onPrimary,
              icon: PhosphorIconsRegular.checkCircle,
            )
            : _StatusChip(
              label: 'Navigating',
              color: Theme.of(context).colorScheme.primary,
              foreground: Theme.of(context).colorScheme.onPrimary,
              icon: PhosphorIconsRegular.personSimpleWalk,
            );

    // Choose which distance to show: remaining polyline distance (more
    // accurate) when available, otherwise the straight-line distance from
    // the cubit.
    final displayDistance =
        (!_routeIsFallback && _remainingRouteDistanceM > 0)
            ? _remainingRouteDistanceM
            : nav.distanceToSite;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetBorderSm),
          ),
          boxShadow: AppShadows.bottomBarFor(context.semanticColors.shadow),
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
                      borderRadius: AppRadius.mdBorder,
                      child: CachedNetworkImage(
                        imageUrl: widget.site.primaryImage,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder:
                            (_, __) => Container(
                              width: 56,
                              height: 56,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                        errorWidget:
                            (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                              child: Icon(
                                Icons.image_not_supported,
                                color: Theme.of(context).colorScheme.outline,
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
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                PhosphorIconsRegular.ruler,
                                size: 14,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  displayDistance != null
                                      ? _formatDistance(displayDistance)
                                      : '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                PhosphorIconsRegular.clock,
                                size: 14,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  nav.estimatedTime != null
                                      ? _formatDuration(nav.estimatedTime!)
                                      : '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
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
                const SizedBox(height: 12),
                // Stop button.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(PhosphorIconsRegular.x, size: 18),
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
    final isImperial = SharedPrefsService.instance.distanceUnits == 'imperial';
    return dc.DistanceCalculator.formatDistance(meters, isImperial: isImperial);
  }

  String _formatDuration(Duration d) {
    return dc.DistanceCalculator.formatDuration(d);
  }
}

// ── Small icon button used inside the top maneuver card ──────────────────────

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.onPressed,
    required this.heroTag,
    this.active = false,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final String heroTag;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? Colors.white.withValues(alpha: 0.25)
          : Colors.white.withValues(alpha: 0.12),
      borderRadius: AppRadius.smBorder,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.smBorder,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

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
      padding: AppInsets.pillRow,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.sheetBorderSmBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 12, color: foreground),
          ),
        ],
      ),
    );
  }
}

// ── Destination pin ───────────────────────────────────────────────────────────

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PinPainter(
        fillColor: context.semanticColors.mapMarker,
        strokeColor: context.semanticColors.onImage,
        shadowColor: context.semanticColors.imageScrim,
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({
    required this.fillColor,
    required this.strokeColor,
    required this.shadowColor,
  });

  final Color fillColor;
  final Color strokeColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.32;
    final center = Offset(size.width / 2, radius + 4);
    final tailBottom = Offset(size.width / 2, size.height - 2);

    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + const Offset(0, 1), radius, shadowPaint);

    final fill = Paint()..color = fillColor;
    final stroke =
        Paint()
          ..color = strokeColor
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);

    final tail =
        ui.Path()
          ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.6)
          ..lineTo(tailBottom.dx, tailBottom.dy)
          ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.6)
          ..close();
    canvas.drawPath(tail, fill);
    canvas.drawPath(tail, stroke);

    // Inner dot
    final inner = Paint()..color = strokeColor;
    canvas.drawCircle(center, radius * 0.35, inner);
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.shadowColor != shadowColor;
}

// ── User location dot ─────────────────────────────────────────────────────────

class _UserMarker extends StatefulWidget {
  @override
  State<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<_UserMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDurations.onboardingReveal,
    );
    if (!SharedPrefsService.instance.reduceMotion) {
      _ctrl.repeat();
    }
  }

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
                color: context.semanticColors.mapUser.withValues(
                  alpha: 0.18 * (1 - pulse),
                ),
              ),
            ),
            // Solid dot.
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: context.semanticColors.mapUser,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.semanticColors.onImage,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.semanticColors.shadow,
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
