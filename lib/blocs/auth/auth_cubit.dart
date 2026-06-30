import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/shared_prefs_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthCubit({
    AuthService? authService,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        super(const AuthState());

  Future<void> checkAuthStatus() async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final userModel = _authService.getCurrentUserModel();
      if (userModel != null) {
        // Trust the role persisted in Firestore, not the email-prefix heuristic.
        // This prevents an admin demotion from being silently undone on the
        // next app launch.
        final firestoreUser = await _firestoreService.getUserById(userModel.id);
        final resolvedUser = firestoreUser ?? userModel;
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: resolvedUser.id,
          userRole: resolvedUser.role.name,
        );
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: resolvedUser,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null) {
        // Save to SharedPreferences for auto-login
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: user.id,
          userRole: user.role.name,
        );
        // Reload to ensure latest user data/claims
        final refreshedUser = await _authService.reloadUser();
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: refreshedUser ?? user,
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Sign in failed',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = await _authService.signUpWithEmail(email, password);
      if (user != null) {
        // Save to SharedPreferences for auto-login
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: user.id,
          userRole: user.role.name,
        );
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Sign up failed',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        // Save to SharedPreferences for auto-login
        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: user.id,
          userRole: user.role.name,
        );
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
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
      ));
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
      ));
    }
  }

  Future<void> updateUserRole(UserRole role) async {
    if (state.user == null) return;
    try {
      // Optimistic local update so the UI reflects the change instantly.
      emit(state.copyWith(
        user: state.user!.copyWith(role: role),
      ));
      // Persist to Firestore. Failure surfaces as an error state but the
      // optimistic update is left in place so the admin can retry.
      await _firestoreService.updateUserRole(state.user!.id, role);
      await SharedPrefsService.instance.setUserLoggedIn(
        true,
        userId: state.user!.id,
        userRole: role.name,
      );
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to update role: $e',
      ));
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
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
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
      ));
    }
  }
}