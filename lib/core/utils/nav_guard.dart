import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/site_model.dart';
import '../../ui/screens/navigation_screen.dart';

/// Whether the live-navigation screen can be opened safely.
///
/// `google_maps_flutter` crashes on emulators and devices that lack Google
/// Play services (or when no API key is configured for the project). The
/// app gates NavigationScreen behind an explicit "is the SDK usable here"
/// check via [AppConstants.googleMapsApiKey].
bool get isGoogleMapsEnabled =>
    (AppConstants.googleMapsApiKey?.isNotEmpty ?? false);

/// Push the live-navigation screen, or show a friendly snackbar if the
/// Google Maps SDK isn't usable on this build.
///
/// Use this everywhere instead of `Navigator.push(... NavigationScreen ...)`
/// so the user gets a clear explanation instead of a process kill on
/// emulators / sandboxed devices.
void safePushNavigation(BuildContext context, SiteModel site) {
  if (!isGoogleMapsEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Live navigation requires a Google Maps API key.\n'
          'The map view works without one — set the key in\n'
          'lib/core/constants/app_constants.dart to enable this screen.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => NavigationScreen(site: site)),
  );
}
