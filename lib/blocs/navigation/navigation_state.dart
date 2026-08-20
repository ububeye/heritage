import 'package:equatable/equatable.dart';
import '../../data/models/navigation_state.dart';

class NavigationCubitState extends Equatable {
  const NavigationCubitState({
    this.navigationState = const NavigationState(),
    this.currentSiteId,
    this.isNavigating = false,
  });
  final NavigationState navigationState;
  final String? currentSiteId;
  final bool isNavigating;

  NavigationCubitState copyWith({
    NavigationState? navigationState,
    String? currentSiteId,
    bool? isNavigating,
  }) {
    return NavigationCubitState(
      navigationState: navigationState ?? this.navigationState,
      currentSiteId: currentSiteId ?? this.currentSiteId,
      isNavigating: isNavigating ?? this.isNavigating,
    );
  }

  @override
  List<Object?> get props => [navigationState, currentSiteId, isNavigating];
}
