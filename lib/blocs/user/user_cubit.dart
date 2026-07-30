import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/services/firestore_service.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(const UserState());
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> loadUsers() async {
    emit(state.copyWith(status: UserStatus.loading, error: null));

    try {
      final users = await _firestoreService.getAllUsers();
      // Roles live in roles/{uid}, not on the user profile. Enrich each
      // user with the canonical role for display in the admin table.
      final roles = await _firestoreService.bulkGetRoles(
        users.map((u) => u.id),
      );
      final enriched =
          users.map((u) {
            final r = roles[u.id];
            return r == null ? u : u.copyWith(role: r);
          }).toList();
      final total = enriched.length;
      final premium = enriched.where((u) => u.role == UserRole.premium).length;
      final admins = enriched.where((u) => u.role == UserRole.admin).length;

      emit(
        state.copyWith(
          status: UserStatus.loaded,
          users: enriched,
          totalUsers: total,
          premiumUsers: premium,
          adminUsers: admins,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: UserStatus.error, error: e.toString()));
    }
  }

  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestoreService.setUserRole(userId, newRole);
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

  void setRoleFilter(UserRole? role) {
    emit(state.copyWith(roleFilter: () => role));
  }

  void setSortOrder(UserSortOrder sortOrder) {
    emit(state.copyWith(sortOrder: sortOrder));
  }
}

enum UserSortOrder { nameAsc, nameDesc, newestFirst }

class UserState {
  const UserState({
    this.status = UserStatus.initial,
    this.users = const [],
    this.searchQuery = '',
    this.error,
    this.totalUsers = 0,
    this.premiumUsers = 0,
    this.adminUsers = 0,
    this.roleFilter,
    this.sortOrder = UserSortOrder.nameAsc,
  });
  final UserStatus status;
  final List<UserModel> users;
  final String searchQuery;
  final String? error;
  final int totalUsers;
  final int premiumUsers;
  final int adminUsers;
  final UserRole? roleFilter;
  final UserSortOrder sortOrder;

  UserState copyWith({
    UserStatus? status,
    List<UserModel>? users,
    String? searchQuery,
    String? error,
    int? totalUsers,
    int? premiumUsers,
    int? adminUsers,
    UserRole? Function()? roleFilter,
    UserSortOrder? sortOrder,
  }) {
    return UserState(
      status: status ?? this.status,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      error: error,
      totalUsers: totalUsers ?? this.totalUsers,
      premiumUsers: premiumUsers ?? this.premiumUsers,
      adminUsers: adminUsers ?? this.adminUsers,
      roleFilter: roleFilter != null ? roleFilter() : this.roleFilter,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  List<UserModel> get filteredUsers {
    List<UserModel> result = users;

    if (roleFilter != null) {
      result = result.where((u) => u.role == roleFilter).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((user) {
        final email = user.email.toLowerCase();
        final name = user.displayName?.toLowerCase() ?? '';
        return email.contains(query) || name.contains(query);
      }).toList();
    }

    result = List.from(result);
    switch (sortOrder) {
      case UserSortOrder.nameAsc:
        result.sort((a, b) => (a.displayName ?? a.email)
            .toLowerCase()
            .compareTo((b.displayName ?? b.email).toLowerCase()));
        break;
      case UserSortOrder.nameDesc:
        result.sort((a, b) => (b.displayName ?? b.email)
            .toLowerCase()
            .compareTo((a.displayName ?? a.email).toLowerCase()));
        break;
      case UserSortOrder.newestFirst:
        result.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        break;
    }

    return result;
  }
}

enum UserStatus { initial, loading, loaded, error }
