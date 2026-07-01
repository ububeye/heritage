import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/shared_prefs_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {

  AuthCubit({
    AuthService? authService,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        super(const AuthState());
  final AuthService _authService;
  final FirestoreService _firestoreService;

  Future<void> checkAuthStatus() async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel != null) {
        // Authoritative role source: roles/{uid}.
        // Legacy fallback: users/{uid}.role for users created before the
        // roles collection existed.
        // TODO(phase-3+): remove the users/{uid}.role fallback once a Cloud
        // Function has backfilled roles/{uid} for every legacy user.
        UserModel resolved = userModel;
        final roleFromRoles =
            await _firestoreService.getUserRole(userModel.id);
        if (roleFromRoles != null) {
          resolved = resolved.copyWith(role: roleFromRoles);
        } else {
          final firestoreUser =
              await _firestoreService.getUserById(userModel.id);
          if (firestoreUser != null) {
            resolved = resolved.copyWith(role: firestoreUser.role);
          }
        }
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: resolved.id,
          userRole: resolved.role.name,
        );
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: resolved,
        ),);
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null) {
        // Refresh from Firebase Auth (claims, etc.) then re-resolve role
        // from roles/{uid} so first sign-in lands with the canonical role.
        final refreshedUser = await _authService.reloadUser();
        final base = refreshedUser ?? user;
        final liveRole =
            await _firestoreService.getUserRole(base.id);
        final resolved = liveRole == null
            ? base
            : base.copyWith(role: liveRole);
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: resolved.id,
          userRole: resolved.role.name,
        );
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: resolved,
        ),);
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Sign in failed',
        ),);
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = await _authService.signUpWithEmail(email, password);
      if (user != null) {
        // Resolve the canonical role from roles/{uid}. A brand-new user has
        // no roles/{uid} doc yet, so this falls through and we keep the
        // service's default (`free`).
        final liveRole = await _firestoreService.getUserRole(user.id);
        final resolved = liveRole == null
            ? user
            : user.copyWith(role: liveRole);
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: resolved.id,
          userRole: resolved.role.name,
        );
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: resolved,
        ),);
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Sign up failed',
        ),);
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        final liveRole = await _firestoreService.getUserRole(user.id);
        final resolved = liveRole == null
            ? user
            : user.copyWith(role: liveRole);
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: resolved.id,
          userRole: resolved.role.name,
        );
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: resolved,
        ),);
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      await _authService.signOut();
      // Clear saved user data
      await SharedPrefsService.instance.setUserLoggedIn(false);
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  Future<void> resetPassword(String email) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      await _authService.resetPassword(email);
      emit(state.copyWith(status: AuthStatus.authenticated));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  Future<void> updateUserRole(UserRole role) async {
    if (state.user == null) return;
    try {
      // Optimistic local update so the UI reflects the change instantly.
      emit(state.copyWith(
        user: state.user!.copyWith(role: role),
      ),);
      // Persist to roles/{uid}. Failure surfaces as an error state but the
      // optimistic update is left in place so the admin can retry.
      await _firestoreService.setUserRole(state.user!.id, role);
      await SharedPrefsService.instance.setUserLoggedIn(
        true,
        userId: state.user!.id,
        userRole: role.name,
      );
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to update role: $e',
      ),);
    }
  }

  /// Update the user's display name. Persists to Firebase Auth, then
  /// refreshes the local user model so the UI updates.
  Future<void> updateDisplayName(String displayName) async {
    if (state.user == null) return;
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authService.updateDisplayName(displayName);
      final refreshed = await _authService.reloadUser();
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: refreshed ?? state.user!.copyWith(displayName: displayName),
      ),);
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  /// Re-authenticate with the current password then change to a new one.
  /// Firebase requires a recent login for sensitive operations.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.user == null) return;
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authService.changePassword(
        email: state.user!.email,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      emit(state.copyWith(status: AuthStatus.authenticated));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }
}
