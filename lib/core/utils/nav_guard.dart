import 'package:flutter/material.dart';

import '../../data/models/site_model.dart';
import '../../ui/screens/navigation_screen_open.dart';

/// Push the live-navigation screen.
///
/// The app is **Stone Town only** and OSM coverage at z=16–18 over the
/// peninsula is as good as a paid map provider — so we use a single
/// open-source navigation screen and skip the Google Maps SDK entirely.
///
/// Callers should always go through this helper rather than instantiating
/// [NavigationScreenOpen] directly so the screen remains a single swap point.
void safePushNavigation(BuildContext context, SiteModel site) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => NavigationScreenOpen(site: site)),
  );
}