import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Convertit un téléphone en email interne Firebase (invisible pour l'utilisateur)
  String _phoneToEmail(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    return '$clean@kumakan.app';
  }

  /// Complète un PIN court (< 6) en mot de passe valide pour Firebase
  String _pinToPassword(String pin) {
    final padded = pin.padRight(6, '0');
    return padded;
  }

  Future<String?> signUp({
    required String fullName,
    required String phone,
    String? email,
    required String pin,
  }) async {
    try {
      final firebaseEmail = (email == null || email.trim().isEmpty)
          ? _phoneToEmail(phone)
          : email.trim();

      debugPrint('[AUTH] signup email=$firebaseEmail');
      debugPrint('[AUTH] signup password length=${_pinToPassword(pin).length}');

      final cred = await _auth.createUserWithEmailAndPassword(
        email: firebaseEmail,
        password: _pinToPassword(pin),
      );

      final uid = cred.user!.uid;
      debugPrint('[AUTH] signup auth OK uid=$uid');

      // Générer un numéro de compte
      final accountNumber =
          'ML06${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

      debugPrint('[AUTH] signup écriture Firestore...');
      await _db.collection('users').doc(uid).set({
        'fullName': fullName,
        'phone': phone,
        'email': email?.trim().isEmpty ?? true ? null : email?.trim(),
        'accountNumber': accountNumber,
        'balance': 50000,
        'locale': 'bm',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[AUTH] signup Firestore OK');

      return null;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AUTH] signup FAILED code=${e.code}');
      debugPrint('[AUTH] signup message=${e.message}');
      debugPrint('[AUTH] signup plugin=${e.plugin}');
      debugPrintStack(stackTrace: st);
      return _mapAuthError(e);
    } catch (e, st) {
      debugPrint('[AUTH] signup OTHER error: $e');
      debugPrintStack(stackTrace: st);
      return e.toString();
    }
  }

  Future<String?> signIn({
    String? phone,
    String? email,
    required String pin,
  }) async {
    try {
      final firebaseEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : _phoneToEmail(phone ?? '');

      debugPrint('[AUTH] signin email=$firebaseEmail');

      await _auth.signInWithEmailAndPassword(
        email: firebaseEmail,
        password: _pinToPassword(pin),
      );
      debugPrint('[AUTH] signin succeeded email=$firebaseEmail');
      return null;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AUTH] signin FAILED code=${e.code}');
      debugPrint('[AUTH] signin message=${e.message}');
      debugPrintStack(stackTrace: st);
      return _mapAuthError(e);
    } catch (e, st) {
      debugPrint('[AUTH] signin OTHER error: $e');
      debugPrintStack(stackTrace: st);
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    debugPrint('[AUTH] signed out');
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ce numéro ou cet email est déjà associé à un compte.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Identifiants ou code PIN incorrect.';
      case 'weak-password':
        return 'Le code PIN est trop faible.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'network-request-failed':
        return 'Connexion réseau impossible.';
      case 'operation-not-allowed':
        return 'Email/Password n\'est pas activé dans Firebase.';
      case 'configuration-not-found':
        return 'Configuration Firebase introuvable.';
      default:
        return '${e.code}: ${e.message ?? "Erreur inconnue."}';
    }
  }
}