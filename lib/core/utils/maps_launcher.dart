import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:url_launcher/url_launcher.dart';

/// Platform's preferred maps URI.
///
/// On Android/iOS this is the `geo:` scheme — the OS resolves it to
/// the user's installed maps app (Google Maps on most Android phones,
/// Apple Maps on iOS). The destination is encoded as a `q=` query so
/// the pin has a recognisable name in the receiving app.
///
/// On web/desktop the `geo:` scheme means nothing, so we fall back to
/// the Google Maps search URL.
Uri primaryMapsUri({
  required double lat,
  required double lng,
  String? label,
}) {
  final encoded = label == null || label.isEmpty
      ? '$lat,$lng'
      : '$lat,$lng(${Uri.encodeComponent(label)})';
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    return Uri.parse('geo:$lat,$lng?q=$encoded');
  }
  return Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
}

/// Universal fallback — Google Maps web. Works on every platform.
///
/// We always reach for this when [primaryMapsUri] fails (no app to
/// handle the `geo:` scheme, or `canLaunch` returned false) so the
/// tourist gets *something* rather than a silent failure.
Uri fallbackMapsUri({
  required double lat,
  required double lng,
  String? label,
}) {
  if (label == null || label.isEmpty) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
  }
  return Uri.parse(
    'https://www.google.com/maps/search/?api=1'
    '&query=$lat%2C$lng(${Uri.encodeComponent(label)})',
  );
}

/// Universal "Google Maps walking directions" URL.
///
/// Used when the chooser is asked to navigate to the destination as
/// a *destination* (not just "show me a pin"). Distinct from the
/// [fallbackMapsUri] which is a search URL — the directions URL
/// turns into "navigate to X" inside Google Maps and lets the OS
/// route to whichever navigation app it prefers.
Uri directionsMapsUri({
  required double lat,
  required double lng,
  String? label,
}) {
  return Uri(
    scheme: 'https',
    host: 'www.google.com',
    path: '/maps/dir/',
    queryParameters: {
      'api': '1',
      'destination': '$lat,$lng',
      if (label != null && label.isNotEmpty) 'destination_place_id': label,
      'travelmode': 'walking',
    },
  );
}

/// Hand a coordinate to the OS for navigation.
///
/// Tries up to three launch attempts in order:
///
///   1. [primaryMapsUri] with `LaunchMode.externalApplication` —
///      the OS picks the installed maps app.
///   2. [fallbackMapsUri] with `LaunchMode.externalApplication` —
///      covers desktops, web, and phones with no `geo:` handler
///      declared in the manifest.
///   3. [fallbackMapsUri] with `LaunchMode.platformDefault` —
///      catches emulators that reject `externalApplication`.
///
/// Returns `true` if any handler took the URI. A 0,0 / NaN input
/// short-circuits to `false` so a denied-location fix never drops the
/// user in the Atlantic.
Future<bool> openNavigation({
  required double lat,
  required double lng,
  String? label,
}) async {
  // A pin at 0,0 is a stub or a failed location fetch. Refuse rather
  // than dropping the user in the Atlantic. NaN is the other failure
  // mode — a NaN coord on the wire either crashes the maps app or
  // pins to an undefined location.
  if (lat.isNaN || lng.isNaN || (lat == 0 && lng == 0)) return false;

  final primary = primaryMapsUri(lat: lat, lng: lng, label: label);
  final fallback = fallbackMapsUri(lat: lat, lng: lng, label: label);

  for (final (uri, mode) in <(Uri, LaunchMode)>[
    (primary, LaunchMode.externalApplication),
    (fallback, LaunchMode.externalApplication),
    (fallback, LaunchMode.platformDefault),
  ]) {
    try {
      if (await launchUrl(uri, mode: mode)) {
        await HapticFeedback.lightImpact();
        return true;
      }
    } catch (e) {
      // One tier failed — log and fall through to the next.
      debugPrint('maps_launcher: $uri failed: $e');
    }
  }
  return false;
}