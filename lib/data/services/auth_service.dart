import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  UserModel? getCurrentUserModel() {
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
      final userModel = _createUserModel(credential.user!);
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
      final userModel = _createUserModel(credential.user!);
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
      final userModel = _createUserModel(firebaseUser.user!);
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
      } else {
        await _firestoreService.updateUserRole(user.id, user.role);
      }
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

  Future<UserModel?> reloadUser() async {
    await _auth.currentUser?.reload();
    return getCurrentUserModel();
  }

  UserModel _createUserModel(User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      role: _determineUserRole(user),
      createdAt: user.metadata.creationTime,
    );
  }

  UserRole _determineUserRole(User user) {
    final email = user.email?.toLowerCase() ?? '';
    final emailLocalPart = email.split('@').first; // get part before @

    // Check for admin - any email starting with "admin" (e.g., admin@gmail.com, admin@mydomain.com)
    if (emailLocalPart.toLowerCase().startsWith('admin')) {
      return UserRole.admin;
    }

    // Check for premium - any email starting with "premium"
    if (emailLocalPart.toLowerCase().startsWith('premium')) {
      return UserRole.premium;
    }

    return UserRole.free;
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