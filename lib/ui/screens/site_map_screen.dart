import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../blocs/language/language_cubit.dart';
import '../../data/models/site_model.dart';
import '../widgets/heritage_map.dart';
import '../../core/utils/nav_guard.dart';

/// Full-screen map view for a single site. Shows the site as a labeled pin
/// on an OpenStreetMap tile layer, with a Navigate FAB that pushes the
/// live-navigation screen.
class SiteMapScreen extends StatelessWidget {

  const SiteMapScreen({super.key, required this.site});
  final SiteModel site;

  @override
  Widget build(BuildContext context) {
    final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(site.getName(uiLanguage)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        site.displayAddress,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    Text(
                      '${site.latitude.toStringAsFixed(4)}, ${site.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontSize: 11,
                            color: AppColors.textHint,
                            fontFeatures: const [FontFeature.tabularFigures()],
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.navigation),
        label: const Text('Navigate'),
      ),
    );
  }
}
