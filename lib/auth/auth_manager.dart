// lib/auth/auth_manager.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Liste des emails modérateurs autorisés
  static const List<String> _moderatorEmails = [
    'moderator@example.com', // à remplacer par ta vraie liste
  ];

  // Callbacks
  void Function()? onSignInSuccess;
  void Function()? onSignUpSuccess;
  void Function()? onSignOutSuccess;
  void Function(String message)? onError;

  // --- Auth ---

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      onSignInSuccess?.call();
    } on FirebaseAuthException catch (e) {
      onError?.call(_signInErrorMessage(e.code));
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({'email': email.trim(), 'createdAt': FieldValue.serverTimestamp()});
      onSignUpSuccess?.call();
    } on FirebaseAuthException catch (e) {
      onError?.call(_signUpErrorMessage(e.code));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    onSignOutSuccess?.call();
  }

  // --- Utilitaires ---

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  bool isModerator() {
    final email = _auth.currentUser?.email;
    return email != null && _moderatorEmails.contains(email);
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Messages d'erreur localisés ---

  String _signInErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé pour cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessaie plus tard.';
      default:
        return 'Erreur de connexion. Vérifie ta connexion internet.';
    }
  }

  String _signUpErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      default:
        return 'Erreur lors de la création du compte.';
    }
  }
}