import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/site_model.dart';
import '../theme/app_radius.dart';
import 'maps_launcher.dart';
import 'nav_guard.dart';

/// Universal "Google Maps walking directions" URL.
///
/// Kept for callers that want the URL only (no launch). The chooser
/// now prefers [openNavigation] in [maps_launcher.dart] which tries
/// the `geo:` scheme first, then this web URL as a fallback.
///
/// Shape: `https://www.google.com/maps/dir/?api=1&destination=LAT,LNG&travelmode=walking`
Uri buildGoogleMapsDirectionsUri({
  required double latitude,
  required double longitude,
}) {
  return Uri(
    scheme: 'https',
    host: 'www.google.com',
    path: '/maps/dir/',
    queryParameters: {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'walking',
    },
  );
}

/// Show the navigate-chooser bottom sheet.
///
/// Replaces the detail screen's direct push of [NavigationScreenOpen].
/// Two options:
///   • Google Maps (Recommended) — launches the device's Google Maps
///     app (or browser) with the site prefilled as the walking
///     destination.
///   • In-app map (OSRM) — keeps the existing
///     `safePushNavigation` flow that renders OSM tiles inside the app.
///
/// The LocalizationCubit state is captured BEFORE `showModalBottomSheet`
/// so the sheet widget never depends on a `BuildContext` across an
/// await. (Same pattern as the audio-language picker in detail_screen.)
Future<void> showNavigateChooser(
  BuildContext context,
  SiteModel site,
) {
  final loc = context.read<LocalizationCubit>().state;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheetBorderSm),
      ),
    ),
    builder: (sheetContext) =>
        _NavigateChooserSheet(site: site, loc: loc),
  );
}

class _NavigateChooserSheet extends StatelessWidget {
  const _NavigateChooserSheet({required this.site, required this.loc});

  final SiteModel site;
  final LocalizationState loc;

  String _t(String key, String fallback) =>
      loc.translations[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCoords =
        site.latitude != 0.0 && site.longitude != 0.0;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle (matches detail_screen audio-language picker).
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: AppRadius.grabHandleBorder,
            ),
          ),
          // Title.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _t('navigate_chooser_title', 'Choose how to navigate'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Divider(height: 1),
          // Options.
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // ── Google Maps (Recommended) ──────────────────────
                ListTile(
                  enabled: hasCoords,
                  leading: const Icon(Icons.map_outlined),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _t('navigate_google_maps', 'Google Maps'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primaryContainer,
                          borderRadius: AppRadius.bannerBorder,
                        ),
                        child: Text(
                          _t('recommended', 'Recommended'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _t(
                      'navigate_google_maps_subtitle',
                      "Opens your phone's Google Maps app with this "
                      'location as the destination.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: hasCoords
                      ? () async {
                          // Pop the sheet synchronously before any
                          // await, so the closure doesn't drag a
                          // BuildContext across the await boundary.
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          navigator.pop();
                          await _launchGoogleMaps(
                            context: context,
                            messenger: messenger,
                          );
                        }
                      : null,
                ),
                const Divider(height: 1),
                // ── In-app map (OSRM) ─────────────────────────────
                ListTile(
                  leading: const Icon(Icons.alt_route),
                  title: Text(
                    _t('navigate_osrm', 'In-app map (OSRM)'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _t(
                      'navigate_osrm_subtitle',
                      'Use the in-app open-source map — no app switch.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    safePushNavigation(context, site);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchGoogleMaps({
    required BuildContext context,
    required ScaffoldMessengerState messenger,
  }) async {
    final errorMsg = _t(
      'navigate_external_failed',
      "Couldn't open a maps app on this device.",
    );
    final ok = await openNavigation(
      lat: site.latitude,
      lng: site.longitude,
      label: site.nameEn,
    );
    if (!ok) {
      _showLaunchError(messenger, errorMsg);
    }
  }

  void _showLaunchError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}