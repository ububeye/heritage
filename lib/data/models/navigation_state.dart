import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

enum NavigationStatus {
  idle,
  navigating,
  arrived,
  completed,
  error,
}

class NavigationState extends Equatable {

  const NavigationState({
    this.status = NavigationStatus.idle,
    this.currentPosition,
    this.distanceToSite,
    this.estimatedTime,
    this.hasArrived = false,
    this.errorMessage,
    this.errorCode,
  });
  final NavigationStatus status;
  final Position? currentPosition;
  final double? distanceToSite;
  final Duration? estimatedTime;
  final bool hasArrived;
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
    String? errorMessage,
    String? errorCode,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      distanceToSite: distanceToSite ?? this.distanceToSite,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      hasArrived: hasArrived ?? this.hasArrived,
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
        errorMessage,
        errorCode,
      ];
}
