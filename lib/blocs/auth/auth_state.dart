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
