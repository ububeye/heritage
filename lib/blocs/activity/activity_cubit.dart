import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/firestore_service.dart';
import 'activity_state.dart';

class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const ActivityState());

  final FirestoreService _firestoreService;

  Future<void> loadActivities({int limit = 10}) async {
    emit(state.copyWith(status: ActivityStatus.loading));
    try {
      final activities =
          await _firestoreService.getRecentActivities(limit: limit);
      emit(
        state.copyWith(status: ActivityStatus.loaded, activities: activities),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ActivityStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
