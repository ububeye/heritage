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
    this.initialZoom = 15,
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

  @override
  State<HeritageMap> createState() => _HeritageMapState();
}

class _HeritageMapState extends State<HeritageMap> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  LatLng? _pickedPoint;
  bool _firstFitDone = false;

  @override
  void initState() {
    super.initState();
    // Clamp to the Unguja box up-front — if the seed coordinates
    // are outside (e.g. a developer testing with fake data, or a
    // bad manual edit) the CameraConstraint.contain assertion in
    // flutter_map will trip on the first rebuild. Clamping here keeps
    // the constraint strict for pan/zoom without crashing on bad input.
    _pickedPoint = UngujaBounds.clampPoint(
      LatLng(widget.initialLat, widget.initialLng),
    );
  }

  @override
  void didUpdateWidget(covariant HeritageMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLat != oldWidget.initialLat ||
        widget.initialLng != oldWidget.initialLng) {
      _pickedPoint = UngujaBounds.clampPoint(
        LatLng(widget.initialLat, widget.initialLng),
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
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
          maxZoom: AppConstants.markerZoom,
          minZoom: AppConstants.stoneTownMinZoom,
        ),
      );
    } else if (widget.sites.length == 1) {
      _mapController.move(
        LatLng(widget.sites.first.latitude, widget.sites.first.longitude),
        widget.initialZoom,
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null || !mounted) return;
    // Emulator GPS without a mock fix typically returns (0, 0) — well
    // outside Unguja — which would trip the CameraConstraint.contain
    // assertion on the next rebuild. Clamp to the island box and
    // surface a SnackBar so the admin understands why their fix wasn't
    // used.
    final rawPoint = LatLng(position.latitude, position.longitude);
    final clampedPoint = UngujaBounds.clampPoint(rawPoint);
    final wasOutsideBox = !UngujaBounds.contains(rawPoint);
    setState(() => _pickedPoint = clampedPoint);
    _mapController.move(clampedPoint, 17);
    widget.onLocationPicked?.call(
      clampedPoint.latitude,
      clampedPoint.longitude,
    );
    if (wasOutsideBox && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Location is outside Unguja — snapped to the closest point.',
          ),
          duration: Duration(seconds: 2),
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
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
          maxZoom: AppConstants.markerZoom,
          minZoom: AppConstants.stoneTownMinZoom,
        ),
      );
    } else if (widget.sites.length == 1) {
      _mapController.move(
        LatLng(widget.sites.first.latitude, widget.sites.first.longitude),
        widget.initialZoom,
      );
    } else {
      _mapController.move(UngujaBounds.centre, widget.initialZoom);
    }
  }

  void _zoomIn() {
    final zoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoom + 1);
  }

  void _zoomOut() {
    final zoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoom - 1);
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
            cameraConstraint: CameraConstraint.contain(
              bounds: UngujaBounds.cameraBounds,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.stone_town_heritage_vt_guide',
              maxNativeZoom: 19,
              tileProvider: TileCacheService.instance.tileProvider(),
            ),
            MarkerLayer(markers: markers),
            if (isPicker && widget.sites.isEmpty)
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
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
      // Single draggable pin. Clamp to the Unguja box so the marker is
      // always within the camera constraint — the `??` fires before
      // `_pickedPoint` is set on the very first frame, and an
      // out-of-bounds `widget.initialLat/Lng` would render a marker
      // the camera is forbidden from centring on. (Heritage sites are
      // authored from Stone Town data, so the marker will sit inside
      // Stone Town in practice; the island clamp is just a safety net.)
      final point = UngujaBounds.clampPoint(
        _pickedPoint ?? LatLng(widget.initialLat, widget.initialLng),
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
