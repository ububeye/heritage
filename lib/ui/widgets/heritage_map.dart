import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/colors.dart';
import '../../data/models/site_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/tile_cache_service.dart';

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
    this.initialLat = -6.1621,
    this.initialLng = 39.1835,
    this.initialZoom = 14,
  })  : onLocationPicked = null,
        showLocateButton = false,
        draggableMarker = false;

  const HeritageMap.picker({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.onLocationPicked,
    this.initialZoom = 15,
    this.showLocateButton = true,
  })  : sites = const [],
        onSiteTap = null,
        draggableMarker = true;

  HeritageMap.singleSite({
    super.key,
    required SiteModel site,
    this.onSiteTap,
    this.initialZoom = 17,
  })  : sites = [site],
        onLocationPicked = null,
        initialLat = -6.1621,
        initialLng = 39.1835,
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
    _pickedPoint = LatLng(widget.initialLat, widget.initialLng);
  }

  @override
  void didUpdateWidget(covariant HeritageMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLat != oldWidget.initialLat ||
        widget.initialLng != oldWidget.initialLng) {
      _pickedPoint = LatLng(widget.initialLat, widget.initialLng);
    }
  }

  void _onMapReady() {
    // Auto-fit camera to all markers (browse mode) on first build.
    if (_firstFitDone) return;
    _firstFitDone = true;

    if (widget.sites.isNotEmpty && widget.sites.length > 1) {
      final points = widget.sites
          .map((s) => LatLng(s.latitude, s.longitude))
          .toList();
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
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
    final newPoint = LatLng(position.latitude, position.longitude);
    setState(() => _pickedPoint = newPoint);
    _mapController.move(newPoint, 17);
    widget.onLocationPicked?.call(position.latitude, position.longitude);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.draggableMarker) return;
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
            initialCenter: _pickedPoint ?? LatLng(widget.initialLat, widget.initialLng),
            initialZoom: widget.initialZoom,
            onTap: isPicker ? _onMapTap : null,
            onMapReady: _onMapReady,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _useCurrentLocation,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location, size: 18, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('My location',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    if (widget.draggableMarker) {
      // Single draggable pin.
      final point = _pickedPoint ?? LatLng(widget.initialLat, widget.initialLng);
      return [
        Marker(
          point: point,
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onPanUpdate: (_) {},
            child: const _PinMarker(label: null),
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
  const _PinMarker({required this.label});
  final String? label;

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
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                label!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
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
            size: 14,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
