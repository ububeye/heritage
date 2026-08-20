import 'package:flutter/material.dart';

/// App-specific semantic roles that aren't represented by Material's
/// [ColorScheme]. Examples include map-specific colours, ratings, and
/// fixed-content colours that must remain stable across light and dark
/// themes (typically text and icons rendered over photographs).
///
/// Lives on [ThemeData.extensions] and is read via
/// `context.semanticColors`. A null-extension lookup is treated as a
/// programmer error — the theme should always register the extension —
/// but in practice the extension is always present in both light and dark
/// themes.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.rating,
    required this.mapRoute,
    required this.mapUser,
    required this.mapMarker,
    required this.onImage,
    required this.onImageMuted,
    required this.imageScrim,
    required this.shadow,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;
  final Color rating;

  // Map-specific roles. Distinct from the brand `secondary` because the
  // navigation arrow on the map should not change hue with the theme.
  final Color mapRoute;
  final Color mapUser;
  final Color mapMarker;

  /// Foreground colour for text and icons rendered over a photograph or
  /// hero image. White in both themes — these surfaces do not adapt.
  final Color onImage;

  /// Muted variant of [onImage] for de-emphasised labels (subtitles,
  /// counts, secondary captions). White at 80% alpha in both themes.
  final Color onImageMuted;

  /// Scrim colour for image overlays (gallery gradient, status pills,
  /// modal sheets). Black at ~60% alpha in both themes.
  final Color imageScrim;

  /// Neutral shadow tone for card and overlay elevation. Black at low
  /// alpha in light mode, white at low alpha in dark mode — keeps
  /// shadows visible on dark surfaces.
  final Color shadow;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? rating,
    Color? mapRoute,
    Color? mapUser,
    Color? mapMarker,
    Color? onImage,
    Color? onImageMuted,
    Color? imageScrim,
    Color? shadow,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      rating: rating ?? this.rating,
      mapRoute: mapRoute ?? this.mapRoute,
      mapUser: mapUser ?? this.mapUser,
      mapMarker: mapMarker ?? this.mapMarker,
      onImage: onImage ?? this.onImage,
      onImageMuted: onImageMuted ?? this.onImageMuted,
      imageScrim: imageScrim ?? this.imageScrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      rating: Color.lerp(rating, other.rating, t)!,
      mapRoute: Color.lerp(mapRoute, other.mapRoute, t)!,
      mapUser: Color.lerp(mapUser, other.mapUser, t)!,
      mapMarker: Color.lerp(mapMarker, other.mapMarker, t)!,
      onImage: Color.lerp(onImage, other.onImage, t)!,
      onImageMuted: Color.lerp(onImageMuted, other.onImageMuted, t)!,
      imageScrim: Color.lerp(imageScrim, other.imageScrim, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSemanticColors &&
        other.success == success &&
        other.onSuccess == onSuccess &&
        other.warning == warning &&
        other.onWarning == onWarning &&
        other.info == info &&
        other.onInfo == onInfo &&
        other.rating == rating &&
        other.mapRoute == mapRoute &&
        other.mapUser == mapUser &&
        other.mapMarker == mapMarker &&
        other.onImage == onImage &&
        other.onImageMuted == onImageMuted &&
        other.imageScrim == imageScrim &&
        other.shadow == shadow;
  }

  @override
  int get hashCode => Object.hash(
    success,
    onSuccess,
    warning,
    onWarning,
    info,
    onInfo,
    rating,
    mapRoute,
    mapUser,
    mapMarker,
    onImage,
    onImageMuted,
    imageScrim,
    shadow,
  );
}

/// Convenience accessor for [AppSemanticColors]. Crashes loudly via the
/// `!` if the extension is missing — that would indicate a theme was
/// built without registering the extension, which is a bug.
extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
