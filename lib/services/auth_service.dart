import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signUp(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    if (name.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.reload();
    }
  }

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists with this email. Try signing in.';
        case 'weak-password':
          return 'Password is too weak - use at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Google sign-in was cancelled.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled. Enable it in Firebase Console > Authentication > Sign-in method.';
        case 'unauthorized-domain':
          return 'This domain is not authorised. Add "localhost" in Firebase Console > Authentication > Settings > Authorized domains.';
        default:
          return e.message ?? 'Authentication failed (${e.code}).';
      }
    }
    return e.toString();
  }
}
