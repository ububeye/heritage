import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

enum NavigationStatus { idle, navigating, arrived, error }

class NavigationState extends Equatable {
  const NavigationState({
    this.status = NavigationStatus.idle,
    this.currentPosition,
    this.distanceToSite,
    this.estimatedTime,
    this.hasArrived = false,
    this.recalculatingRoute = false,
    this.errorMessage,
    this.errorCode,
  });
  final NavigationStatus status;
  final Position? currentPosition;
  final double? distanceToSite;
  final Duration? estimatedTime;
  final bool hasArrived;

  /// True when a route recalculation is currently in flight (e.g. after
  /// an off-route detection). The UI uses this to render the
  /// "Recalculating route…" banner.
  final bool recalculatingRoute;

  /// Localized-friendly error description. Non-null on [NavigationStatus.error].
  final String? errorMessage;

  /// Machine-readable error code, set together with [errorMessage].
  /// Known values:
  ///   * `'permission_denied'` — the user hasn't granted location
  ///     permission. The UI should render a localized SnackBar with
  ///     an "Open Settings" CTA pointing at `Geolocator.openAppSettings()`.
  ///   * `'destination_out_of_bounds'` — the site is outside Stone Town.
  ///   * `'gps_error'` — anything else (Geolocator stream error).
  final String? errorCode;

  NavigationState copyWith({
    NavigationStatus? status,
    Position? currentPosition,
    double? distanceToSite,
    Duration? estimatedTime,
    bool? hasArrived,
    bool? recalculatingRoute,
    String? errorMessage,
    String? errorCode,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      distanceToSite: distanceToSite ?? this.distanceToSite,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      hasArrived: hasArrived ?? this.hasArrived,
      recalculatingRoute: recalculatingRoute ?? this.recalculatingRoute,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentPosition,
    distanceToSite,
    estimatedTime,
    hasArrived,
    recalculatingRoute,
    errorMessage,
    errorCode,
  ];
}
