import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
      await _syncUserToFirestore(userModel);
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
      await _syncUserToFirestore(userModel);
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final firebaseUser = await _auth.signInWithCredential(credential);
      if (firebaseUser.user == null) return null;
      final userModel = await _createUserModel(firebaseUser.user!);
      await _syncUserToFirestore(userModel);
      return userModel;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  Future<void> _syncUserToFirestore(UserModel user) async {
    try {
      final existingUser = await _firestoreService.getUserById(user.id);
      if (existingUser == null) {
        await _firestoreService.createUser(user);
      }
      // Do NOT overwrite role here. roles/{uid} is the source of truth;
      // the previous behaviour of calling updateUserRole() on every login
      // would silently undo admin demotions and re-promote anyone whose
      // email happened to start with "admin" or "premium".
    } catch (e) {
      // Don't fail auth if Firestore sync fails
      debugPrint('Failed to sync user to Firestore: $e');
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
  /// canonical role from `roles/{uid}`. New signups default to `free`.
  ///
  /// TODO(phase-3+): drop the `users/{uid}.role` fallback once a Cloud
  /// Function has backfilled `roles/{uid}` for every legacy user.
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
    );
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
