import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/shared_prefs_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({AuthService? authService, FirestoreService? firestoreService})
    : _authService = authService ?? AuthService(),
      _firestoreService = firestoreService ?? FirestoreService(),
      super(const AuthState());
  final AuthService _authService;
  final FirestoreService _firestoreService;

  /// Re-fetch the current user from Firebase Auth + Firestore without
  /// flipping the [AuthStatus] to loading. Used by flows that just
  /// mutated an entitlement (e.g. billing) and want the user model to
  /// pick up the change without flashing the splash / login screen.
  Future<void> refreshUser() async {
    try {
      final refreshed = await _authService.reloadUser();
      if (refreshed == null) return;
      final resolved = await _resolveRoleWithDemoOverride(refreshed);
      emit(state.copyWith(user: resolved));
    } catch (e) {
      // Best-effort: keep the existing user model on failure.
    }
  }

  /// Look up the user's authoritative role in Firestore. Prefers the
  /// canonical `roles/{uid}` doc, falling back to the legacy
  /// `users/{uid}.role` field for documents predating the split.
  Future<UserRole?> _resolveLiveRole(UserModel base) async {
    final fromRoles = await _firestoreService.getUserRole(base.id);
    if (fromRoles != null) return fromRoles;
    final firestoreUser = await _firestoreService.getUserById(base.id);
    return firestoreUser?.role;
  }

  /// Resolve the user's role on this device. Authoritative source is
  /// Firestore (via [_resolveLiveRole]), but for the demo build we also
  /// honour the local "I bought premium on this device" flag so a
  /// purchase survives app restarts and sign-outs. There is no Cloud
  /// Function mirroring the store webhook back to Firestore, so without
  /// this override the server-side role would always read as `free` on
  /// the next launch and the 7 audio languages would re-lock.
  ///
  /// Admin wins over the demo override — an admin-promoted user keeps
  /// the `admin` role even if the device has a prior in-app purchase.
  Future<UserModel> _resolveRoleWithDemoOverride(UserModel base) async {
    final liveRole = await _resolveLiveRole(base);
    final fromServer = base.copyWith(role: liveRole ?? base.role);
    if (!SharedPrefsService.instance.isPremiumDemo) return fromServer;
    if (fromServer.role == UserRole.admin) return fromServer;
    return fromServer.copyWith(role: UserRole.premium);
  }

  Future<void> checkAuthStatus() async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel != null) {
        // Authoritative role source: roles/{uid}.
        // Backward-compatible fallback: users/{uid}.role for documents
        // where role is stored on the user profile. The demo override
        // (see _resolveRoleWithDemoOverride) then promotes the role to
        // premium if this device has a prior in-app purchase on record.
        final resolved = await _resolveRoleWithDemoOverride(userModel);
        if (resolved.disabled) {
          await _authService.signOut();
          emit(
            state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Your account has been suspended.',
            ),
          );
          return;
        }

        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: resolved.id,
          userRole: resolved.role.name,
        );
        emit(state.copyWith(status: AuthStatus.authenticated, user: resolved));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null) {
        // Refresh from Firebase Auth (claims, etc.) then re-resolve role
        // from roles/{uid} so first sign-in lands with the canonical role.
        // The demo override (see _resolveRoleWithDemoOverride) then
        // promotes the role to premium if this device has a prior
        // in-app purchase on record.
        final refreshedUser = await _authService.reloadUser();
        final base = refreshedUser ?? user;
        final resolved = await _resolveRoleWithDemoOverride(base);
        if (resolved.disabled) {
          await _authService.signOut();
          emit(
            state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Your account has been suspended.',
            ),
          );
          return;
        }

        await SharedPrefsService.instance.setUserLoggedIn(
          true,
          userId: resolved.id,
          userRole: resolved.role.name,
        );
        emit(state.copyWith(status: AuthStatus.authenticated, user: resolved));
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Sign in failed',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
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
        final resolved =
            liveRole == null ? user : user.copyWith(role: liveRole);
        // Intentionally do NOT call SharedPrefsService.setUserLoggedIn(true)
        // here. Sign-up creates the Firebase Auth account but does not
        // auto-sign-in. RegisterScreen's BlocListener watches for
        // AuthStatus.registered and routes to LoginScreen, so the user
        // reaches the home via the normal sign-in path. The persisted
        // logged-in flag is updated by signInWithEmail.
        emit(state.copyWith(status: AuthStatus.registered, user: resolved));
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Sign up failed',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    // Re-entrancy guard: the Google button previously had no loading
    // state, so a quick double-tap could race two credential exchanges
    // and leave the second call with a half-cancelled UI. Mirror the
    // email sign-in re-entrancy guard at the top of [signIn].
    if (state.status == AuthStatus.loading) return;

    // Wait for the native picker to resolve *before* emitting loading.
    // The previous behaviour emitted loading immediately, which made
    // both auth buttons show a spinner for the ~100-500ms gap between
    // the tap and the picker actually appearing on screen. Holding the
    // loading emit until we know the user didn't cancel eliminates the
    // spinner flash entirely.
    try {
      final user = await _authService.signInWithGoogle();
      if (isClosed) return;
      if (user == null) {
        // User cancelled the picker — return to the unauthenticated
        // baseline silently. The previous behaviour emitted
        // AuthStatus.unauthenticated here, which the login screen's
        // BlocListener has no branch for, so a real cancellation looked
        // like a silent failure to the user.
        emit(state.copyWith(status: AuthStatus.unauthenticated));
        return;
      }

      // Picker succeeded and Firebase credentials were exchanged —
      // now flip to loading so the buttons reflect the in-flight
      // role lookup (the only remaining async work).
      emit(state.copyWith(status: AuthStatus.loading));

      // Resolve the canonical role from roles/{uid} (with fallback to
      // users/{uid}.role). The demo override (see
      // _resolveRoleWithDemoOverride) then promotes the role to
      // premium if this device has a prior in-app purchase on record.
      final resolved = await _resolveRoleWithDemoOverride(user);
      if (isClosed) return;
      await SharedPrefsService.instance.setUserLoggedIn(
        true,
        userId: resolved.id,
        userRole: resolved.role.name,
      );
      if (isClosed) return;
      emit(state.copyWith(status: AuthStatus.authenticated, user: resolved));
    } catch (e) {
      // AuthService routes its own FirebaseAuthException through
      // _handleAuthError, which returns a localised String (the email
      // paths throw that string directly — same pattern). The Google
      // path also throws Exception('Google sign-in is unavailable on
      // this device') for PlatformException-style failures. e.toString()
      // gives the user-facing message either way, but strip the
      // leading "Exception: " prefix so the SnackBar reads cleanly.
      if (isClosed) return;
      final raw = e.toString();
      final message = raw.startsWith('Exception: ')
          ? raw.substring('Exception: '.length)
          : raw;
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: message),
      );
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
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Send a password-reset email. The user is *not* signed in here —
  /// they tapped "Forgot password" from the login screen — so the
  /// previous behaviour of emitting [AuthStatus.authenticated] was a
  /// bug that flipped the root navigator into the home shell. We
  /// surface the success via a dedicated [AuthStatus.passwordResetSent]
  /// status so a [BlocListener] on the login screen can show a
  /// "check your inbox" SnackBar.
  Future<void> resetPassword(String email) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      await _authService.resetPassword(email);
      if (isClosed) return;
      emit(state.copyWith(status: AuthStatus.passwordResetSent));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Flip the cubit back to a non-error idle state after the login
  /// screen has shown the password-reset SnackBar. Without this, the
  /// status would stay on [AuthStatus.passwordResetSent] and the next
  /// sign-in attempt would be misinterpreted by the [BlocListener].
  ///
  /// Idempotent: a no-op if we're already unauthenticated. Safe to call
  /// from a listener because it doesn't await anything.
  void emitIdleAfterReset() {
    if (state.status != AuthStatus.passwordResetSent) return;
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }

  Future<void> updateUserRole(UserRole role) async {
    if (state.user == null) return;
    try {
      // Optimistic local update so the UI reflects the change instantly.
      emit(state.copyWith(user: state.user!.copyWith(role: role)));
      // Persist to roles/{uid}. Failure surfaces as an error state but the
      // optimistic update is left in place so the admin can retry.
      await _firestoreService.setUserRole(state.user!.id, role);
      await SharedPrefsService.instance.setUserLoggedIn(
        true,
        userId: state.user!.id,
        userRole: role.name,
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Failed to update role: $e',
        ),
      );
    }
  }

  /// Optimistically flip the current user's role to premium (or back to
  /// free). Mirrors a successful purchase onto the auth state without
  /// waiting for a Firestore Cloud Function to update the user's role
  /// document. Until that Cloud Function is deployed, every screen that
  /// gates UX on [AuthState.isPremium] would still see "free" for hundreds
  /// of ms after a purchase — this lets the UI react instantly.
  ///
  /// Idempotent: a no-op if the requested value already matches the
  /// current role, so the [Cubit] equality check makes the no-op safe.
  void markUserPremiumOptimistic(bool value) {
    if (state.user == null) return;
    final target = value ? UserRole.premium : UserRole.free;
    if (state.user!.role == target) return;
    emit(state.copyWith(user: state.user!.copyWith(role: target)));
  }

  /// Update the user's display name. Persists to Firebase Auth, then
  /// refreshes the local user model so the UI updates.
  Future<void> updateDisplayName(String displayName) async {
    if (state.user == null) return;
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authService.updateDisplayName(displayName);
      final refreshed = await _authService.reloadUser();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: refreshed ?? state.user!.copyWith(displayName: displayName),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
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
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }
}
