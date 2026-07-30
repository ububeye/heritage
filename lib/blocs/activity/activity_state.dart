import '../../data/models/activity_model.dart';

enum ActivityStatus { initial, loading, loaded, error }

class ActivityState {
  const ActivityState({
    this.status = ActivityStatus.initial,
    this.activities = const [],
    this.errorMessage,
  });

  final ActivityStatus status;
  final List<ActivityModel> activities;
  final String? errorMessage;

  ActivityState copyWith({
    ActivityStatus? status,
    List<ActivityModel>? activities,
    String? errorMessage,
  }) {
    return ActivityState(
      status: status ?? this.status,
      activities: activities ?? this.activities,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
