import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/stone_town_bounds.dart';
import '../../core/utils/unguja_bounds.dart';
import '../../data/models/site_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/tile_cache_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Wraps `flutter_map` (OpenStreetMap tiles) with the project's color theme.
///
/// Two variants:
/// - [HeritageMap.browse] — show all sites as markers (Explore / single-site view)
/// - [HeritageMap.picker] — single draggable marker (admin add/edit forms)
///
/// Both variants hide the underlying `flutter_map` + `latlong2` details so the
/// rest of the app stays decoupled from the map library.
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
       initialLat = -6.1619,
       initialLng = 39.1936,
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

  /// Camera bounds for the picker / browse variants. Picker uses the
  /// wider [StoneTownBounds.pickerCameraBounds] (~20 % buffer) so the
  /// admin can zoom out slightly without hitting the constraint wall;
  /// browse / single-site span all of Unguja so a tourist in Nungwi can
  /// plan a route to Forodhani. Exposed as a static so widget tests can
  /// pin the policy without spinning up a MapController.
  static LatLngBounds boundsFor({required bool isPicker}) {
    return isPicker
        ? StoneTownBounds.pickerCameraBounds
        : UngujaBounds.cameraBounds;
  }

  /// Clamp a coordinate into the variant's bounding box. Picker clamps
  /// to the strict Stone Town box (for routing / pin position); browse
  /// clamps to Unguja. Exposed as a static so widget tests and call
  /// sites can apply the same policy.
  static LatLng clampForPicker(LatLng point, {required bool isPicker}) {
    return isPicker
        ? StoneTownBounds.clampPoint(point)
        : UngujaBounds.clampPoint(point);
  }

  /// Camera constraint for the variant. Picker uses `containCenter` on the
  /// wider pickerCameraBounds so the camera *centre* stays in the buffered
  /// Stone Town area but the viewport can spill past the box when zoomed
  /// out — this is the only constraint shape that can never return `null`
  /// from `constrain()`, which is why it's the one we use on the picker:
  /// a `null` return is what trips the `'MapCamera is no longer within the
  /// cameraConstraint'` assertion and surfaces as the "Access blocked" red
  /// overlay. Browse uses `contain` because the larger Unguja box
  /// comfortably fits the viewport at every permitted zoom.
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
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  LatLng? _pickedPoint;
  bool _firstFitDone = false;

  /// Camera constraint for the current variant. Delegates to
  /// [HeritageMap.constraintFor] so widget code and tests share one
  /// definition. Picker uses `containCenter` so the camera *centre*
  /// stays in Stone Town but the viewport can spill past the box
  /// when zoomed out — this is the only constraint shape that never
  /// returns `null` from `constrain()`, which is why the picker uses
  /// it: a `null` return is what trips the `'MapCamera is no longer
  /// within the cameraConstraint after an option change'` assertion
  /// and surfaces as the "Access blocked" red overlay. Browse uses
  /// `contain` because the larger Unguja box comfortably fits the
  /// viewport at every permitted zoom.
  CameraConstraint get _activeConstraint =>
      HeritageMap.constraintFor(isPicker: widget.draggableMarker);

  @override
  void initState() {
    super.initState();
    // Clamp to the variant's box up-front — if the seed coordinates
    // are outside (e.g. a developer testing with fake data, or a
    // bad manual edit) the CameraConstraint.contain assertion in
    // flutter_map will trip on the first rebuild. Clamping here keeps
    // the constraint strict for pan/zoom without crashing on bad input.
    _pickedPoint = HeritageMap.clampForPicker(
      LatLng(widget.initialLat, widget.initialLng),
      isPicker: widget.draggableMarker,
    );
  }

  @override
  void didUpdateWidget(covariant HeritageMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLat != oldWidget.initialLat ||
        widget.initialLng != oldWidget.initialLng) {
      _pickedPoint = HeritageMap.clampForPicker(
        LatLng(widget.initialLat, widget.initialLng),
        isPicker: widget.draggableMarker,
      );
    }
  }

  void _onMapReady() {
    // Auto-fit camera to all markers (browse mode) on first build.
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
    // Emulator GPS without a mock fix typically returns (0, 0) — well
    // outside the variant's box — which would trip the
    // CameraConstraint.contain assertion on the next rebuild. Clamp to
    // the variant's box (Stone Town for picker, Unguja for browse) and
    // surface a SnackBar so the admin understands why their fix wasn't
    // used.
    final rawPoint = LatLng(position.latitude, position.longitude);
    final clampedPoint = HeritageMap.clampForPicker(rawPoint, isPicker: widget.draggableMarker);
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
                ? 'Location is outside Stone Town — snapped to the closest point.'
                : 'Location is outside Unguja — snapped to the closest point.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Re-fit the camera to all sites (browse) or centre on the single site.
  /// Used by the "Reset view" button on the explore map.
  void _resetToAllSites() {
    if (widget.sites.length > 1) {
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
    } else {
      _safeMove(UngujaBounds.centre, widget.initialZoom);
    }
  }

  void _zoomIn() {
    final cam = _mapController.camera;
    // Clamp the target zoom into the permitted range AND the centre
    // into the variant's box BEFORE calling move. Without these clamps,
    // tapping "+" at maxZoom (or "−" at minZoom) or with the camera
    // panned to the edge of the box asked the controller for an
    // out-of-bounds camera; on the next rebuild the
    // `CameraConstraint.contain` assertion fired ('MapCamera is no
    // longer within the cameraConstraint after an option change') and
    // surfaced to the user as the "Access blocked" red overlay.
    // Clamping both keeps the camera always inside the constraint so
    // the assertion can never trip.
    final nextZoom = (cam.zoom + 1).clamp(
      AppConstants.stoneTownMinZoom,
      AppConstants.stoneTownMaxZoom,
    );
    final nextCenter = HeritageMap.clampForPicker(
      cam.center,
      isPicker: widget.draggableMarker,
    );
    _safeMove(nextCenter, nextZoom);
  }

  void _zoomOut() {
    final cam = _mapController.camera;
    final nextZoom = (cam.zoom - 1).clamp(
      AppConstants.stoneTownMinZoom,
      AppConstants.stoneTownMaxZoom,
    );
    final nextCenter = HeritageMap.clampForPicker(
      cam.center,
      isPicker: widget.draggableMarker,
    );
    _safeMove(nextCenter, nextZoom);
  }

  /// Wraps [_mapController.move] with a defensive try/catch. The
  /// `CameraConstraint.contain` assertion is debug-only but on a real
  /// device the user sees the red "Access blocked" overlay when an
  /// out-of-bounds camera slips through. The clamps in [_zoomIn] /
  /// [_zoomOut] / [_onMapTap] / `_useCurrentLocation` should make the
  /// catch unreachable, but we wrap it anyway — losing a zoom tap is
  /// cheap, crashing the screen is not.
  void _safeMove(LatLng center, double zoom) {
    try {
      _mapController.move(center, zoom);
    } catch (_) {
      // Silent recovery — the next valid interaction will produce a
      // legal camera. Avoid surfacing the assertion to the user.
    }
  }

  /// Same as [_safeMove] but for [_mapController.fitCamera]. Used by
  /// the "reset to all sites" / on-map-ready paths. `fitCamera` can
  /// also trip the camera-constraint assertion when the bounds it
  /// computed from marker positions land partially outside the
  /// constraint box.
  ///
  /// IMPORTANT: previously this method called itself (infinite recursion bug)
  /// which meant fitCamera was never called and the map camera stayed
  /// un-initialised, causing the "Access Blocked" overlay on zoom/scroll.
  void _safeFitCamera(CameraFit fit) {
    try {
      _mapController.fitCamera(fit);
    } catch (_) {
      // Silent recovery — same rationale as _safeMove.
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.draggableMarker) return;
    // Map tap is bounded by the camera constraint, so the point is
    // always inside the box — no clamp needed here. Just propagate.
    setState(() => _pickedPoint = point);
    widget.onLocationPicked?.call(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final isPicker = widget.draggableMarker;
    final markers = _buildMarkers();

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
            onTap: isPicker ? _onMapTap : null,
            onMapReady: _onMapReady,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            cameraConstraint: _activeConstraint,
          ),
          children: [
            TileLayer(
              // CartoDB Voyager: A free, lenient tile server perfect for demos
              // without needing an API key. Replaces OSM to prevent 403 errors.
              urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.stone_town_heritage_vt_guide',
              maxNativeZoom: 19,
              tileProvider: TileCacheService.instance.tileProvider(),
            ),
            MarkerLayer(markers: markers),
            if (isPicker && widget.sites.isEmpty)
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors, © CARTO'),
                ],
              ),
          ],
        ),
        if (widget.showLocateButton)
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: AppRadius.smBorder,
                  child: InkWell(
                    onTap:
                        widget.draggableMarker
                            ? _useCurrentLocation
                            : _resetToAllSites,
                    borderRadius: AppRadius.smBorder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: AppRadius.smBorder,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.draggableMarker
                                ? PhosphorIconsRegular.navigationArrow
                                : Icons.center_focus_strong,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.draggableMarker
                                ? 'My location'
                                : 'Reset view',
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          bottom: 16,
          right: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 4,
                borderRadius: AppRadius.smBorder,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Column(
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
                        color: Theme.of(context).colorScheme.outline,
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
            ],
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    if (widget.draggableMarker) {
      // Single draggable pin. Clamp to the variant's box (Stone Town
      // for picker, Unguja for browse) so the marker is always within
      // the camera constraint — the `??` fires before `_pickedPoint`
      // is set on the very first frame, and an out-of-bounds
      // `widget.initialLat/Lng` would render a marker the camera is
      // forbidden from centring on. (Heritage sites are authored from
      // Stone Town data, so the marker will sit inside Stone Town in
      // practice; the island clamp is just a safety net for browse.)
      final point = HeritageMap.clampForPicker(
        _pickedPoint ?? LatLng(widget.initialLat, widget.initialLng),
        isPicker: widget.draggableMarker,
      );
      return [
        Marker(
          point: point,
          width: 56,
          height: 56,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onPanUpdate: (_) {},
            child: const _PinMarker(label: null, isPicker: true),
          ),
        ),
      ];
    }

    // Browse / single-site: one marker per site.
    return widget.sites.map((site) {
      return Marker(
        point: LatLng(site.latitude, site.longitude),
        width: 80,
        height: 48,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => widget.onSiteTap?.call(site),
          child: _PinMarker(label: site.nameEn),
        ),
      );
    }).toList();
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.label, this.isPicker = false});
  final String? label;
  final bool isPicker;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              margin: const EdgeInsets.only(bottom: 1),
              decoration: BoxDecoration(
                // Map-marker label sits over a map tile — fixed white
                // background so the dark text is legible on any tile.
                color: context.semanticColors.onImage,
                borderRadius: AppRadius.xsBorder,
                boxShadow: AppShadows.mapPinFor(context.semanticColors.shadow),
              ),
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                label!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
        Container(
          width: isPicker ? 36 : 28,
          height: isPicker ? 36 : 28,
          decoration: BoxDecoration(
            color: context.semanticColors.mapMarker,
            shape: BoxShape.circle,
            // Border over the map tile — fixed white for contrast.
            border: Border.all(
              color: context.semanticColors.onImage,
              width: isPicker ? 4 : 3,
            ),
            boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
          ),
          child: Icon(
            PhosphorIconsRegular.mapPin,
            size: isPicker ? 20 : 14,
            // Pin icon over a coloured circle — use the onImage foreground
            // so it stays consistent across themes.
            color: context.semanticColors.onImage,
          ),
        ),
      ],
    );
  }
}
