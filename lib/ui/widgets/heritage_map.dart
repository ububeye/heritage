import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../blocs/localization/localization_cubit.dart';
import '../../blocs/user_location/user_location_cubit.dart';
import '../../blocs/user_location/user_location_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/utils/heading_source.dart';
import '../../core/utils/nav_guard.dart';
import '../../core/utils/stone_town_bounds.dart';
import '../../core/utils/unguja_bounds.dart';
import '../../data/models/site_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/tile_cache_service.dart';
import '../../state/map/map_camera_controller.dart';
import '../screens/detail_screen.dart';
import 'map_scale_bar.dart';
import 'map/site_marker.dart';
import 'map/selected_site_marker.dart';
import 'map/user_marker.dart';

/// Production-grade Heritage Map for Stone Town exploration and site picking.
///
/// Variants:
/// - [HeritageMap.browse] — Interactive tourist exploration with category pins & site cards.
/// - [HeritageMap.picker] — Interactive admin coordinate picker with draggable pin & tap placement.
/// - [HeritageMap.singleSite] — Focused view centered on a single heritage monument.
class HeritageMap extends StatefulWidget {
  const HeritageMap.browse({
    super.key,
    required this.sites,
    this.onSiteTap,
    this.initialLat = -6.1619,
    this.initialLng = 39.1936,
    this.initialZoom = 15,
    this.showLocateButton = true,
  }) : onLocationPicked = null,
       draggableMarker = false;

  const HeritageMap.picker({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.onLocationPicked,
    this.initialZoom = 16,
    this.showLocateButton = true,
  }) : sites = const [],
       onSiteTap = null,
       draggableMarker = true;

  HeritageMap.singleSite({
    super.key,
    required SiteModel site,
    this.onSiteTap,
    this.initialZoom = 17,
  }) : sites = [site],
       onLocationPicked = null,
       initialLat = site.latitude,
       initialLng = site.longitude,
       showLocateButton = false,
       draggableMarker = false;

  final List<SiteModel> sites;
  final void Function(SiteModel site)? onSiteTap;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final void Function(double lat, double lng)? onLocationPicked;
  final bool showLocateButton;
  final bool draggableMarker;

  /// Camera bounds for picker vs browse mode.
  static LatLngBounds boundsFor({required bool isPicker}) {
    return isPicker
        ? StoneTownBounds.pickerCameraBounds
        : UngujaBounds.cameraBounds;
  }

  /// Clamps coordinate to appropriate bounding box.
  static LatLng clampForPicker(LatLng point, {required bool isPicker}) {
    return isPicker
        ? StoneTownBounds.clampPoint(point)
        : UngujaBounds.clampPoint(point);
  }

  /// Camera constraint using containCenter to avoid assertion crashes during rapid zoom/pan.
  static CameraConstraint constraintFor({required bool isPicker}) {
    final bounds =
        isPicker ? StoneTownBounds.pickerCameraBounds : UngujaBounds.cameraBounds;
    return isPicker
        ? CameraConstraint.containCenter(bounds: bounds)
        : CameraConstraint.contain(bounds: bounds);
  }

  @override
  State<HeritageMap> createState() => _HeritageMapState();
}

class _HeritageMapState extends State<HeritageMap> {
  /// The MapController is owned by [MapCameraController] when one is
  /// provided via [BlocProvider]. Otherwise (legacy callers) we fall
  /// back to a private instance.
  final MapController _localMapController = MapController();
  final LocationService _locationService = LocationService();
  final HeadingSource _headingSource = HeadingSource();
  LatLng? _pickedPoint;
  SiteModel? _selectedSite;
  bool _firstFitDone = false;
  bool _permissionSnackbarShown = false;

  /// Cached after the first build so we can ref/unref in didChangeDependencies
  /// and dispose. Populated lazily to keep [initState] free of context reads.
  UserLocationCubit? _userLocCubit;

  MapCameraController? _cameraController;

  CameraConstraint get _activeConstraint =>
      HeritageMap.constraintFor(isPicker: widget.draggableMarker);

  MapController get _mapController =>
      _cameraController?.mapController ?? _localMapController;

  String _tr(String key) =>
      context.read<LocalizationCubit>().translate(key);

  @override
  void initState() {
    super.initState();
    _pickedPoint = HeritageMap.clampForPicker(
      LatLng(widget.initialLat, widget.initialLng),
      isPicker: widget.draggableMarker,
    );
    if (widget.sites.length == 1) {
      _selectedSite = widget.sites.first;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Adopt an externally-provided camera controller if one is in scope.
    // This allows the navigation screen to share the same MapController
    // state across screens.
    _cameraController =
        MapCameraController.maybeOf(context);
    // Subscribe to the always-on user-location stream. Multiple
    // HeritageMap instances share the cubit via its internal refcount,
    // so a second map screen does NOT double-start the GPS stream.
    _userLocCubit ??= context.read<UserLocationCubit>();
    _userLocCubit!.ref();
    _userLocCubit!.ensurePermissionAndStart();
  }

  @override
  void dispose() {
    // Only dispose the local controller if we own it. If a shared one
    // is in scope, the provider owns it.
    if (_cameraController == null) {
      _localMapController.dispose();
    }
    _locationService.dispose();
    _headingSource.reset();
    _userLocCubit?.unref();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HeritageMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLat != oldWidget.initialLat ||
        widget.initialLng != oldWidget.initialLng) {
      final newPoint = HeritageMap.clampForPicker(
        LatLng(widget.initialLat, widget.initialLng),
        isPicker: widget.draggableMarker,
      );
      setState(() => _pickedPoint = newPoint);
    }
  }

  void _onMapReady() {
    if (_firstFitDone) return;
    _firstFitDone = true;

    if (widget.sites.isNotEmpty && widget.sites.length > 1) {
      final points =
          widget.sites.map((s) => LatLng(s.latitude, s.longitude)).toList();
      final bounds = LatLngBounds.fromPoints(points);
      _safeFitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
          maxZoom: AppConstants.markerZoom,
          minZoom: AppConstants.stoneTownMinZoom,
        ),
      );
    } else if (widget.sites.length == 1) {
      _safeMove(
        LatLng(widget.sites.first.latitude, widget.sites.first.longitude),
        widget.initialZoom,
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null || !mounted) return;

    final rawPoint = LatLng(position.latitude, position.longitude);
    final clampedPoint =
        HeritageMap.clampForPicker(rawPoint, isPicker: widget.draggableMarker);
    final wasOutsideBox = widget.draggableMarker
        ? !StoneTownBounds.contains(rawPoint)
        : !UngujaBounds.contains(rawPoint);

    setState(() => _pickedPoint = clampedPoint);
    _safeMove(clampedPoint, 17);
    widget.onLocationPicked?.call(
      clampedPoint.latitude,
      clampedPoint.longitude,
    );

    if (wasOutsideBox && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            widget.draggableMarker
                ? 'Location is outside Stone Town — snapped to closest point.'
                : 'Location is outside Zanzibar — snapped to closest point.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Browse-mode "My location" handler. Reads the cached position from
  /// [UserLocationCubit] (no extra GPS round-trip) and flies the camera
  /// there. Falls back to a snackbar when no fix is available yet.
  void _locateUserFromCubit() {
    final cubit = _userLocCubit;
    if (cubit == null) return;

    final state = cubit.state;
    final pos = state.position;
    if (pos == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(_tr('error_location_service')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final rawPoint = LatLng(pos.latitude, pos.longitude);
    final clampedPoint = HeritageMap.clampForPicker(
      rawPoint,
      isPicker: false,
    );
    final wasOutsideBox = !UngujaBounds.contains(rawPoint);
    _safeMove(clampedPoint, AppConstants.markerZoom);

    if (wasOutsideBox && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Location is outside Zanzibar — snapped to closest point.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _zoomIn() {
    final cam = _mapController.camera;
    final nextZoom = (cam.zoom + 1).clamp(
      AppConstants.stoneTownMinZoom,
      AppConstants.stoneTownMaxZoom,
    );
    _safeMove(cam.center, nextZoom);
  }

  void _zoomOut() {
    final cam = _mapController.camera;
    final nextZoom = (cam.zoom - 1).clamp(
      AppConstants.stoneTownMinZoom,
      AppConstants.stoneTownMaxZoom,
    );
    _safeMove(cam.center, nextZoom);
  }

  void _safeMove(LatLng center, double zoom) {
    try {
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  void _safeFitCamera(CameraFit fit) {
    try {
      _mapController.fitCamera(fit);
    } catch (_) {}
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (widget.draggableMarker) {
      final clamped =
          HeritageMap.clampForPicker(point, isPicker: widget.draggableMarker);
      setState(() => _pickedPoint = clamped);
      widget.onLocationPicked?.call(clamped.latitude, clamped.longitude);
    } else {
      if (_selectedSite != null) {
        setState(() => _selectedSite = null);
      }
    }
  }

  void _selectSite(SiteModel site) {
    setState(() => _selectedSite = site);
    final target = LatLng(site.latitude, site.longitude);
    final camera = _cameraController;
    if (camera != null) {
      camera.requestSelectSite(target, zoom: 16.5);
    } else {
      _safeMove(target, 16.5);
    }
    // Defer the callback so the controller can apply the visual
    // transition before the parent rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSiteTap?.call(site);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPicker = widget.draggableMarker;
    // Static markers (site pins / picker pin) live outside the
    // BlocSelector below so they do NOT repaint on every GPS fix. Only
    // the user marker rebuilds when the cubit emits a new position.
    final staticMarkers = buildStaticMarkers(
      sites: widget.sites,
      selectedSite: _selectedSite,
      pickedPoint: _pickedPoint,
      isPicker: widget.draggableMarker,
      initialLat: widget.initialLat,
      initialLng: widget.initialLng,
      context: context,
      onPickerDrag: (point) => setState(() => _pickedPoint = point),
      onSiteTap: _selectSite,
    );

    // Feed each position through the local HeadingSource so the user
    // marker can show a heading wedge on Android (where headingAccuracy
    // is often unreliable — HeadingSource falls back to bearing-derived
    // heading from two consecutive fixes).
    _watchHeadingFromCubit();

    // Surface the permission-denied snackbar once per session.
    _maybeShowPermissionDeniedSnackbar();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                _pickedPoint ?? LatLng(widget.initialLat, widget.initialLng),
            initialZoom: widget.initialZoom,
            minZoom: AppConstants.stoneTownMinZoom,
            maxZoom: AppConstants.stoneTownMaxZoom,
            onTap: _onMapTap,
            onMapReady: _onMapReady,
            onPositionChanged: (camera, hasGesture) {
              if (!hasGesture) return;
              if (_cameraController == null) return;
              if (_cameraController!.isSuppressingGesture) return;
              _cameraController!.markUserGesture();
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            cameraConstraint: _activeConstraint,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.stonetown.guide',
              maxNativeZoom: 19,
              tileProvider: TileCacheService.instance.tileProvider(),
            ),
            // Static (site / picker) markers + a BlocSelector-driven user
            // marker. The BlocSelector only rebuilds when the selected
            // value (LatLng? or hasPermission) actually changes, so the
            // MarkerLayer does NOT repaint on every GPS tick.
            BlocSelector<UserLocationCubit, UserLocationState, _UserMarkerData?>(
              selector: _userMarkerSelector,
              builder: (context, userMarker) {
                return MarkerLayer(
                  markers: <Marker>[
                    ...staticMarkers,
                    if (userMarker != null)
                      Marker(
                        point: userMarker.point,
                        width: 18 * 2.4,
                        height: 18 * 2.4,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity:
                              userMarker.isInUnguja ? 1.0 : 0.4,
                          child: UserMarker(
                            headingDeg: _headingSource.currentDeg,
                            color: context.semanticColors.mapUser,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: const [
                TextSourceAttribution('© OpenStreetMap contributors, © CARTO'),
              ],
            ),
            // Live scale bar — listens to the MapController and rebuilds
            // whenever the camera zooms or pans. Positioned above the
            // attribution row so both remain readable.
            Positioned(
              left: 12,
              bottom: 28,
              child: MapScaleBar(mapController: _mapController),
            ),
          ],
        ),
        // Top Right Locate / Reset controls
        if (widget.showLocateButton)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: AppRadius.smBorder,
              color: Theme.of(context).colorScheme.surface,
              child: InkWell(
                onTap: isPicker ? _useCurrentLocation : _locateUserFromCubit,
                borderRadius: AppRadius.smBorder,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPicker
                            ? PhosphorIconsRegular.navigationArrow
                            : PhosphorIconsRegular.navigationArrow,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _tr('my_location'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Bottom Right Zoom Controls
        Positioned(
          bottom: _selectedSite != null && !isPicker ? 200 : 24,
          right: 12,
          child: Material(
            elevation: 4,
            borderRadius: AppRadius.smBorder,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    PhosphorIconsRegular.plus,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _zoomIn,
                  tooltip: 'Zoom In',
                ),
                Container(
                  height: 1,
                  width: 32,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                IconButton(
                  icon: Icon(
                    PhosphorIconsRegular.minus,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _zoomOut,
                  tooltip: 'Zoom Out',
                ),
              ],
            ),
          ),
        ),
        // Floating Site Preview Sheet (Explore browse mode)
        if (_selectedSite != null && !isPicker && widget.sites.length > 1)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: _SitePreviewCard(
              site: _selectedSite!,
              onClose: () => setState(() => _selectedSite = null),
              onNavigate: () => safePushNavigation(context, _selectedSite!),
              onViewDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(siteId: _selectedSite!.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _watchHeadingFromCubit() {
    final cubit = _userLocCubit;
    if (cubit == null) return;
    final pos = cubit.state.position;
    if (pos != null) {
      _headingSource.onPosition(pos);
    }
  }

  /// Selector that returns a [_UserMarkerData] only when there is a real
  /// fix AND permission has been granted. The BlocSelector only rebuilds
  /// when this record actually changes, so the MarkerLayer does NOT
  /// repaint on every GPS tick.
  static _UserMarkerData? _userMarkerSelector(UserLocationState state) {
    if (state.position == null) return null;
    return _UserMarkerData(
      point: LatLng(state.position!.latitude, state.position!.longitude),
      isInUnguja: state.isInUnguja,
    );
  }

  /// Shows a permission-denied snackbar once per session. The cubit
  /// emits `hasPermission == false` after `ensurePermissionAndStart`
  /// runs — we listen for that transition and surface the action.
  void _maybeShowPermissionDeniedSnackbar() {
    final cubit = _userLocCubit;
    if (cubit == null) return;
    if (_permissionSnackbarShown) return;
    // No permission + we already completed the first probe.
    if (cubit.state.hasPermission) return;
    // The cubit's `hasPermission == false` is the initial state — only
    // fire the snackbar after the user has actually interacted with
    // the screen at least once. Defer the check to a microtask so the
    // first build doesn't double-fire.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _permissionSnackbarShown) return;
      final s = _userLocCubit?.state;
      if (s == null || s.hasPermission) return;
      _permissionSnackbarShown = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(_tr('location_permission_required')),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }
}

/// Minimal payload for the user marker — only the fields the
/// BlocSelector actually uses. Keeps rebuild scope tiny.
class _UserMarkerData {
  const _UserMarkerData({required this.point, required this.isInUnguja});
  final LatLng point;
  final bool isInUnguja;
}

/// Pure builder for the static (non-user) markers on the map. Pulled
/// out as a top-level helper so it can be unit-tested without mounting
/// the full HeritageMap widget (which depends on flutter_map's
/// `MapController` and tile providers — see
/// `test/heritage_map_bounds_test.dart` L11-13).
///
/// [onPickerDrag] is invoked with the new LatLng whenever the
/// draggable picker pin is moved; the caller is expected to update its
/// own state in response.
List<Marker> buildStaticMarkers({
  required List<SiteModel> sites,
  required SiteModel? selectedSite,
  required LatLng? pickedPoint,
  required bool isPicker,
  required double initialLat,
  required double initialLng,
  required BuildContext context,
  void Function(LatLng newPoint)? onPickerDrag,
  void Function(SiteModel site)? onSiteTap,
}) {
  if (isPicker) {
    final point = HeritageMap.clampForPicker(
      pickedPoint ?? LatLng(initialLat, initialLng),
      isPicker: true,
    );
    return [
      Marker(
        point: point,
        width: 60,
        height: 60,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onPanUpdate: (details) {
            final newLat = (point.latitude - details.delta.dy * 0.00005).clamp(
              AppConstants.stoneTownPickerMinLat,
              AppConstants.stoneTownPickerMaxLat,
            );
            final newLng =
                (point.longitude + details.delta.dx * 0.00005).clamp(
              AppConstants.stoneTownPickerMinLng,
              AppConstants.stoneTownPickerMaxLng,
            );
            final clamped = StoneTownBounds.clampPoint(
              LatLng(newLat, newLng),
            );
            onPickerDrag?.call(clamped);
          },
          child: const SelectedSiteMarker(
            label: 'Pin',
            color: Color(0xFF1D4ED8),
            icon: PhosphorIconsFill.mapPin,
            selected: true,
            isPicker: true,
          ),
        ),
      ),
    ];
  }

  return sites.map((site) {
    final isSelected = selectedSite?.id == site.id;
    final pinLabel = site.nameEn;
    final pinColor = _getCategoryColorFor(site.category ?? 'historic', context);
    final pinIcon = _getCategoryIconFor(site.category ?? 'historic');
    return Marker(
      point: LatLng(site.latitude, site.longitude),
      width: isSelected ? 120 : 90,
      height: isSelected ? 72 : 56,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () => onSiteTap?.call(site),
        child: isSelected
            ? SelectedSiteMarker(
                label: pinLabel,
                color: pinColor,
                icon: pinIcon,
              )
            : SiteMarker(label: pinLabel, color: pinColor, icon: pinIcon),
      ),
    );
  }).toList();
}

/// Top-level helpers for category icon + colour. Used both by
/// [_HeritageMapState] when rendering the new [SiteMarker] /
/// [SelectedSiteMarker] widgets.
IconData _getCategoryIconFor(String category) {
  switch (category.toLowerCase()) {
    case 'historic':
      return PhosphorIconsRegular.bank;
    case 'cultural':
      return PhosphorIconsRegular.maskHappy;
    case 'religious':
      return PhosphorIconsRegular.mosque;
    case 'architecture':
      return PhosphorIconsRegular.buildings;
    case 'museum':
      return PhosphorIconsRegular.building;
    case 'market':
      return PhosphorIconsRegular.shoppingBag;
    case 'admin':
      return PhosphorIconsFill.mapPin;
    default:
      return PhosphorIconsRegular.mapPin;
  }
}

Color _getCategoryColorFor(String category, BuildContext context) {
  if (category.toLowerCase() == 'admin') {
    return Theme.of(context).colorScheme.primary;
  }
  switch (category.toLowerCase()) {
    case 'historic':
      return const Color(0xFFD97706); // Amber / ochre
    case 'cultural':
      return const Color(0xFFE11D48); // Rose / coral
    case 'religious':
      return const Color(0xFF0D9488); // Teal
    case 'architecture':
      return const Color(0xFF1D4ED8); // Indigo
    case 'museum':
      return const Color(0xFF7C3AED); // Violet
    case 'market':
      return const Color(0xFFCA8A04); // Mustard
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

/// Floating site preview card shown when a site marker is tapped in browse mode.
class _SitePreviewCard extends StatelessWidget {
  const _SitePreviewCard({
    required this.site,
    required this.onClose,
    required this.onNavigate,
    required this.onViewDetails,
  });

  final SiteModel site;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final uiLanguage =
        context.read<LocalizationCubit>().state.currentLanguage;

    return Material(
      elevation: 8,
      borderRadius: AppRadius.mdBorder,
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdBorder,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.smBorder,
                  child: CachedNetworkImage(
                    imageUrl: site.primaryImage,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 64,
                      height: 64,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Theme.of(context).colorScheme.outline,
                        size: 20,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              site.getName(uiLanguage),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(PhosphorIconsRegular.x, size: 18),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        site.displayAddress,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: AppRadius.xsBorder,
                            ),
                            child: Text(
                              (site.category ?? 'historic').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          if (site.descriptionEn.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(
                              PhosphorIconsRegular.headphones,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Audio Guide',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewDetails,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNavigate,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(
                      PhosphorIconsFill.navigationArrow,
                      size: 16,
                    ),
                    label: const Text('Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
