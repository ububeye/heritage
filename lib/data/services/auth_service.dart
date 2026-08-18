import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const ['email']);
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Read the current Firebase Auth user and resolve their [UserModel].
  /// Async because role resolution now hits Firestore (roles/{uid} →
  /// fallback users/{uid}.role for legacy users).
  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _createUserModel(user);
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) return null;
      final userModel = await _createUserModel(credential.user!);
      try {
        await _syncUserToFirestore(userModel);
      } catch (_) {
        // Profile sync is best-effort here; the user is already
        // signed-in via Firebase Auth. The legacy role fallback in
        // _createUserModel has already applied the correct role, so
        // admin promotions reach the user on the next login. Don't
        // fail auth over a profile-write race.
      }
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<UserModel?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) return null;
      final userModel = await _createUserModel(credential.user!);
      try {
        await _syncUserToFirestore(userModel);
      } catch (_) {
        // Profile sync is best-effort — see signInWithEmail.
      }
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Sign in with Google. Returns null only when the user cancels the
  /// picker; any real failure (missing SHA-1, OAuth client misconfigured,
  /// no Play Services, network down) throws a clean, localised message
  /// the caller can show in a SnackBar.
  ///
  /// The previous version re-threw a generic `Exception` whose `$e` was
  /// a raw `PlatformException` or `FirebaseAuthException`. The cubit
  /// threw that string verbatim into the SnackBar, which the user
  /// reported as "Google sign-in doesn't work". Routing Firebase errors
  /// through [_handleAuthError] and GoogleSignIn errors through a
  /// dedicated localised message keeps the UI readable.
  Future<UserModel?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } on FirebaseAuthException catch (e) {
      // _googleSignIn.signIn() can throw FirebaseAuthException directly
      // when the underlying auth provider is unavailable (e.g. an
      // emulator with no Google Play Services). Route through the same
      // mapper as the email path.
      throw _handleAuthError(e);
    } catch (_) {
      // PlatformException from google_sign_in (missing SHA-1, OAuth
      // client id, no Play Services) and any other native failure. The
      // raw exception isn't user-actionable, so swap it for a friendly
      // localised message.
      throw Exception('Google sign-in is unavailable on this device');
    }
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final firebaseUser = await _auth.signInWithCredential(credential);
    if (firebaseUser.user == null) {
      // Hard failure — credential exchange came back empty. Surface as
      // a typed FirebaseAuthException so the cubit can route through
      // _handleAuthError and the user sees a clean message instead of
      // a silent no-op.
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Google sign-in returned no user',
      );
    }
    final userModel = await _createUserModel(firebaseUser.user!);
    try {
      await _syncUserToFirestore(userModel);
    } catch (_) {
      // Profile sync is best-effort — see signInWithEmail.
    }
    return userModel;
  }

  /// Persist the user record so admin role changes, preferences, and
  /// future Firestore-backed features can resolve them. Failures used
  /// to be swallowed by [debugPrint] — that hid the path where a user
  /// signs in but has no Firestore profile, so admin demotions never
  /// reach them and the `users/{uid}.role` legacy fallback doesn't
  /// fire either. Re-throw so [AuthCubit] can surface a
  /// "profile couldn't be saved" error and the caller can retry.
  ///
  /// Returns true when the sync succeeded, false when the user already
  /// existed (a no-op success). Throws on any network / Firestore error.
  Future<bool> _syncUserToFirestore(UserModel user) async {
    try {
      final existingUser = await _firestoreService.getUserById(user.id);
      if (existingUser == null) {
        await _firestoreService.createUser(user);
        return true;
      }
      // Do NOT overwrite role here. roles/{uid} is the source of truth;
      // the previous behaviour of calling updateUserRole() on every login
      // would silently undo admin demotions and re-promote anyone whose
      // email happened to start with "admin" or "premium".
      return false;
    } catch (e) {
      throw Exception('Failed to sync user profile to Firestore: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    if (_auth.currentUser == null) return;
    await _auth.currentUser!.updateDisplayName(displayName);
  }

  Future<void> updatePhotoUrl(String photoUrl) async {
    if (_auth.currentUser == null) return;
    await _auth.currentUser!.updatePhotoURL(photoUrl);
  }

  /// Re-authenticate with the current password, then update to a new one.
  /// Firebase requires a recent login for the updatePassword call.
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('No signed-in user');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await _auth.currentUser!.reauthenticateWithCredential(credential);
    await _auth.currentUser!.updatePassword(newPassword);
  }

  Future<UserModel?> reloadUser() async {
    await _auth.currentUser?.reload();
    return getCurrentUserModel();
  }

  /// Build a [UserModel] from a Firebase Auth [User], resolving the
  /// canonical role from `roles/{uid}` with fallback to `users/{uid}.role`.
  /// New signups default to `free`.
  Future<UserModel> _createUserModel(User user) async {
    UserRole role = UserRole.free;
    try {
      final fromRoles = await _firestoreService.getUserRole(user.uid);
      if (fromRoles != null) {
        role = fromRoles;
      } else {
        // Legacy fallback: pre-Phase-3 users have role on users/{uid}.
        final profile = await _firestoreService.getUserById(user.uid);
        if (profile != null) role = profile.role;
      }
    } catch (_) {
      // Don't fail auth if Firestore is unreachable; default stays free.
    }
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      role: role,
      createdAt: user.metadata.creationTime,
      signInProvider: _resolveProvider(user),
    );
  }

  /// Map Firebase Auth's provider list to a single [SignInProvider].
  /// Google users have `google.com` in their providerData; password
  /// users have `password`; everything else falls back to password.
  SignInProvider _resolveProvider(User user) {
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return SignInProvider.google;
    }
    return SignInProvider.password;
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
