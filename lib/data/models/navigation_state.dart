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
  });
  final NavigationStatus status;
  final Position? currentPosition;
  final double? distanceToSite;
  final Duration? estimatedTime;
  final bool hasArrived;
  final String? errorMessage;

  NavigationState copyWith({
    NavigationStatus? status,
    Position? currentPosition,
    double? distanceToSite,
    Duration? estimatedTime,
    bool? hasArrived,
    String? errorMessage,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      distanceToSite: distanceToSite ?? this.distanceToSite,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      hasArrived: hasArrived ?? this.hasArrived,
      errorMessage: errorMessage,
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
      ];
}
