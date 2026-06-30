import 'package:flutter/material.dart';

import '../../data/models/site_model.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../core/constants/app_constants.dart';
import '../../ui/screens/navigation_screen.dart';
import '../../ui/screens/navigation_screen_open.dart';

/// Whether the Google-Maps-backed navigation screen can be opened safely.
///
/// `google_maps_flutter` crashes on emulators and devices that lack Google
/// Play services (or when no API key is configured for the project). The
/// app gates [NavigationScreen] behind an explicit "is the SDK usable
/// here" check via [AppConstants.googleMapsApiKey].
bool get isGoogleMapsEnabled =>
    (AppConstants.googleMapsApiKey?.isNotEmpty ?? false);

/// Whether the user has opted into the Google provider (vs. the default
/// open-source provider). Reads from shared preferences so the choice
/// survives across launches.
bool isGoogleProviderSelected() {
  try {
    return SharedPrefsService.instance.mapProvider ==
        AppConstants.mapProviderGoogle;
  } catch (_) {
    // SharedPrefsService may not be initialised yet (e.g. in tests).
    return false;
  }
}

/// Push the live-navigation screen, choosing the appropriate
/// implementation:
///
/// * **Open-source path** ([NavigationScreenOpen]) — always works, uses
///   OpenStreetMap tiles and an OSRM foot route. No API key, no Play
///   services dependency.
/// * **Google path** ([NavigationScreen]) — only when the user has opted
///   in *and* a Google Maps API key is configured. Otherwise the open
///   screen is used instead (with a one-time hint the first time).
///
/// Use this everywhere instead of `Navigator.push(... NavigationScreen ...)`
/// so the user always reaches a working navigation experience.
void safePushNavigation(BuildContext context, SiteModel site) {
  if (!isGoogleMapsEnabled && isGoogleProviderSelected()) {
    // User picked Google but no key is configured — fall back to the
    // open-source path. Mention this once so the user understands why.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Google Maps key not configured — using the open-source map.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  final useGoogle =
      isGoogleMapsEnabled && isGoogleProviderSelected();

  if (useGoogle) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NavigationScreen(site: site)),
    );
  } else {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NavigationScreenOpen(site: site)),
    );
  }
}
