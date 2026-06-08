import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/navigation/navigation_cubit.dart';
import '../../blocs/navigation/navigation_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../data/models/site_model.dart';
import '../../data/models/navigation_state.dart' as nav_model;
import '../widgets/arrival_overlay.dart';

class NavigationScreen extends StatefulWidget {
  final SiteModel site;

  const NavigationScreen({super.key, required this.site});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  bool _showArrivalOverlay = false;

  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  void _startNavigation() {
    context.read<NavigationCubit>().startNavigation(
          siteId: widget.site.id,
          siteLat: widget.site.latitude,
          siteLng: widget.site.longitude,
          entryRadiusM: widget.site.entryRadiusM,
        );
  }

  @override
  void dispose() {
    context.read<NavigationCubit>().stopNavigation();
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.site.latitude, widget.site.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.site.nameEn,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NavigationCubit, NavigationCubitState>(
      listener: (context, state) {
        if (state.navigationState.status == nav_model.NavigationStatus.arrived && !_showArrivalOverlay) {
          setState(() => _showArrivalOverlay = true);
        }

        if (_mapController != null && state.navigationState.currentPosition != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(
                state.navigationState.currentPosition!.latitude,
                state.navigationState.currentPosition!.longitude,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final navState = state.navigationState;
        final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.site.latitude, widget.site.longitude),
                  zoom: AppConstants.defaultZoom,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: _buildMarkers(),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: FloatingActionButton.small(
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: AppColors.surface,
                  child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                ),
              ),
              // Friendly explanation when the Google Maps API key isn't
              // configured. The map tiles render blank; navigation logic
              // (distance, ETA, arrival) still works via Geolocator.
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 64),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Map tiles disabled — add a Google Maps API key\nto enable the live map. Navigation still works.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
              if (_showArrivalOverlay)
                ArrivalOverlay(
                  site: widget.site,
                  uiLanguage: uiLanguage,
                  onPlayAudio: () {
                    final audioLang = context.read<LanguageCubit>().state.audioLanguage;
                    final isPremium = context.read<AuthCubit>().state.isPremium;
                    context.read<SiteDetailCubit>().playAudio(audioLang, isPremium: isPremium);
                    setState(() => _showArrivalOverlay = false);
                  },
                  onClose: () => setState(() => _showArrivalOverlay = false),
                ),
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
                              child: Image.network(
                                widget.site.cloudinaryImageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 60,
                                  height: 60,
                                  color: AppColors.surfaceDark,
                                  child: const Icon(Icons.image, color: AppColors.textHint),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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