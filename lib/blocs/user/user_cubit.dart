import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/services/firestore_service.dart';

class UserCubit extends Cubit<UserState> {
  final FirestoreService _firestoreService = FirestoreService();

  UserCubit() : super(const UserState());

  Future<void> loadUsers() async {
    emit(state.copyWith(status: UserStatus.loading, error: null));

    try {
      final users = await _firestoreService.getAllUsers();
      final total = users.length;
      final premium = users.where((u) => u.role == UserRole.premium).length;
      final admins = users.where((u) => u.role == UserRole.admin).length;

      emit(state.copyWith(
        status: UserStatus.loaded,
        users: users,
        totalUsers: total,
        premiumUsers: premium,
        adminUsers: admins,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: UserStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestoreService.updateUserRole(userId, newRole);
      await loadUsers();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _firestoreService.deleteUser(userId);
      await loadUsers();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void searchUsers(String query) {
    emit(state.copyWith(searchQuery: query));
  }
}

class UserState {
  final UserStatus status;
  final List<UserModel> users;
  final String searchQuery;
  final String? error;
  final int totalUsers;
  final int premiumUsers;
  final int adminUsers;

  const UserState({
    this.status = UserStatus.initial,
    this.users = const [],
    this.searchQuery = '',
    this.error,
    this.totalUsers = 0,
    this.premiumUsers = 0,
    this.adminUsers = 0,
  });

  UserState copyWith({
    UserStatus? status,
    List<UserModel>? users,
    String? searchQuery,
    String? error,
    int? totalUsers,
    int? premiumUsers,
    int? adminUsers,
  }) {
    return UserState(
      status: status ?? this.status,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      error: error,
      totalUsers: totalUsers ?? this.totalUsers,
      premiumUsers: premiumUsers ?? this.premiumUsers,
      adminUsers: adminUsers ?? this.adminUsers,
    );
  }

  List<UserModel> get filteredUsers {
    if (searchQuery.isEmpty) return users;
    return users.where((user) {
      final email = user.email.toLowerCase();
      final name = user.displayName?.toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return email.contains(query) || name.contains(query);
    }).toList();
  }
}

enum UserStatus { initial, loading, loaded, error }