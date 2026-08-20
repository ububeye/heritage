import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

/// State of the always-on user-position stream consumed by the tourist-facing
/// maps (Explore + SiteDetail). Separate from [NavigationCubit], which only
/// emits a position while a navigation session is active.
///
/// The cubit shares a single GPS subscription across map screens via a
/// refcount; a screen calls [UserLocationCubit.ref] on mount and
/// [UserLocationCubit.unref] on dispose.
class UserLocationState extends Equatable {
  const UserLocationState({
    this.position,
    this.hasPermission = false,
    this.isInUnguja = false,
    this.errorMessage,
  });

  /// Most recent GPS fix, or null if no fix has arrived yet.
  final Position? position;

  /// True once [LocationService.checkPermission] returns `true`. Sticky:
  /// once granted, stays granted even after [UserLocationCubit.stop] (the
  /// OS keeps the grant until the user revokes it).
  final bool hasPermission;

  /// True if [position] is inside the Unguja island box. Used by the map
  /// to dim the user dot when the user is on a ferry / outside coverage.
  final bool isInUnguja;

  /// Last surfaced GPS error (verbatim from the stream). Cleared on the
  /// next successful fix.
  final String? errorMessage;

  UserLocationState copyWith({
    Position? position,
    bool? hasPermission,
    bool? isInUnguja,
    String? errorMessage,
    bool clearError = false,
    bool clearPosition = false,
  }) {
    return UserLocationState(
      position: clearPosition ? null : (position ?? this.position),
      hasPermission: hasPermission ?? this.hasPermission,
      isInUnguja: isInUnguja ?? this.isInUnguja,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [position, hasPermission, isInUnguja, errorMessage];
}