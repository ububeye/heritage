import 'package:equatable/equatable.dart';
import '../../data/models/user_model.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,

  /// Sign-in / sign-up / role-update errors land here. errorMessage on
  /// the state carries the human-readable reason.
  error,

  /// Password-reset email was sent — user is still unauthenticated.
  /// The screen that triggered the reset listens for this status to
  /// show a "check your inbox" SnackBar; the previous behaviour of
  /// flipping to `authenticated` for a logged-out user is a bug.
  passwordResetSent,

  /// Email/password sign-up succeeded but the user has *not* been
  /// signed in. The register screen's BlocListener routes to the
  /// login screen on this status; the user enters their credentials
  /// to actually authenticate. `isAuthenticated` returns false here
  /// by construction (AuthState.isAuthenticated only matches
  /// `authenticated`), so the root router stays on the auth shell.
  registered,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isPremium => user?.isPremium ?? false;
  bool get isAdmin => user?.isAdmin ?? false;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
