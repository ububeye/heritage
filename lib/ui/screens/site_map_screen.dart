import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../blocs/language/language_cubit.dart';
import '../../data/models/site_model.dart';
import '../widgets/heritage_map.dart';
import '../../core/utils/nav_guard.dart';

/// Full-screen map view for a single site. Shows the site as a labeled pin
/// on an OpenStreetMap tile layer, with a Navigate FAB that pushes the
/// live-navigation screen.
class SiteMapScreen extends StatelessWidget {
  final SiteModel site;

  const SiteMapScreen({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(site.getName(uiLanguage)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: Stack(
        children: [
          HeritageMap.singleSite(site: site),
          // Address chip overlay
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        site.displayAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${site.latitude.toStringAsFixed(4)}, ${site.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontFeatures: [FontFeature.tabularFigures()],
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
        onPressed: () => safePushNavigation(context, site),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.navigation),
        label: const Text('Navigate'),
      ),
    );
  }
}
