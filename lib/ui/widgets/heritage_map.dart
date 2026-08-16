import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../blocs/localization/localization_cubit.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/utils/nav_guard.dart';
import '../../core/utils/stone_town_bounds.dart';
import '../../core/utils/unguja_bounds.dart';
import '../../data/models/site_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/tile_cache_service.dart';
import '../screens/detail_screen.dart';

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
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  LatLng? _pickedPoint;
  SiteModel? _selectedSite;
  bool _firstFitDone = false;

  CameraConstraint get _activeConstraint =>
      HeritageMap.constraintFor(isPicker: widget.draggableMarker);

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

  void _resetToAllSites() {
    setState(() => _selectedSite = null);
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
    _safeMove(LatLng(site.latitude, site.longitude), 16.5);
    widget.onSiteTap?.call(site);
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
            onTap: _onMapTap,
            onMapReady: _onMapReady,
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
            MarkerLayer(markers: markers),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: const [
                TextSourceAttribution('© OpenStreetMap contributors, © CARTO'),
              ],
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
                onTap: isPicker ? _useCurrentLocation : _resetToAllSites,
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
                            : Icons.center_focus_strong,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPicker ? 'My location' : 'Reset view',
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

  List<Marker> _buildMarkers() {
    if (widget.draggableMarker) {
      final point = HeritageMap.clampForPicker(
        _pickedPoint ?? LatLng(widget.initialLat, widget.initialLng),
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
              final newLng = (point.longitude + details.delta.dx * 0.00005).clamp(
                AppConstants.stoneTownPickerMinLng,
                AppConstants.stoneTownPickerMaxLng,
              );
              final clamped = StoneTownBounds.clampPoint(LatLng(newLat, newLng));
              setState(() => _pickedPoint = clamped);
              widget.onLocationPicked?.call(clamped.latitude, clamped.longitude);
            },
            child: const _HeritagePin(
              category: 'admin',
              isSelected: true,
              isPicker: true,
            ),
          ),
        ),
      ];
    }

    return widget.sites.map((site) {
      final isSelected = _selectedSite?.id == site.id;
      return Marker(
        point: LatLng(site.latitude, site.longitude),
        width: isSelected ? 120 : 90,
        height: isSelected ? 72 : 56,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => _selectSite(site),
          child: _HeritagePin(
            label: site.nameEn,
            category: site.category ?? 'historic',
            isSelected: isSelected,
          ),
        ),
      );
    }).toList();
  }
}

/// Category-accented heritage pin marker.
class _HeritagePin extends StatelessWidget {
  const _HeritagePin({
    this.label,
    required this.category,
    this.isSelected = false,
    this.isPicker = false,
  });

  final String? label;
  final String category;
  final bool isSelected;
  final bool isPicker;

  IconData _getCategoryIcon() {
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

  Color _getCategoryColor(BuildContext context) {
    if (isPicker) return Theme.of(context).colorScheme.primary;
    switch (category.toLowerCase()) {
      case 'historic':
        return const Color(0xFFD97706); // Amber / ochre
      case 'cultural':
        return const Color(0xFFE11D48); // Rose / coral
      case 'religious':
        return const Color(0xFF0D9488); // Teal
      case 'architecture':
        return const Color(0xFF2563EB); // Royal blue
      case 'museum':
        return const Color(0xFF7C3AED); // Purple
      case 'market':
        return const Color(0xFF059669); // Emerald
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = _getCategoryColor(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (label != null && label!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: AppRadius.xsBorder,
              border: Border.all(
                color: isSelected ? pinColor : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 1.5 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(maxWidth: isSelected ? 110 : 85),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: isSelected ? 11 : 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isPicker
              ? 38
              : (isSelected ? 36 : 28),
          height: isPicker
              ? 38
              : (isSelected ? 36 : 28),
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: pinColor.withValues(alpha: isSelected ? 0.45 : 0.25),
                blurRadius: isSelected ? 10 : 6,
                spreadRadius: isSelected ? 2 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _getCategoryIcon(),
              size: isPicker
                  ? 20
                  : (isSelected ? 18 : 14),
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
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
