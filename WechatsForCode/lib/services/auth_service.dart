import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user == null) {
        throw 'Failed to create user account';
      }

      await result.user!.updateDisplayName(displayName);

      final userModel = UserModel(
        uid: result.user!.uid,
        email: email,
        displayName: displayName,
        photoUrl: '',
        status: 'Hey, I am using Chat App',
        lastSeen: DateTime.now(),
        isOnline: true,
      );
      
      _databaseService.createUserProfile(userModel)
        .catchError((e) => debugPrint('Error creating user profile: $e'));

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        _updateUserStatusBackground(result.user!.uid, email);
      }

      return result;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'Aucun utilisateur trouvé pour cet email';
        case 'wrong-password':
          throw 'Mot de passe incorrect';
        case 'user-disabled':
          throw 'Ce compte a été désactivé';
        default:
          throw 'Une erreur est survenue: ${e.message}';
      }
    }
  }

  void _updateUserStatusBackground(String uid, String email) {
    _databaseService.getUserById(uid).then((userDoc) {
      if (userDoc == null) {
        _databaseService.createUserProfile(UserModel(
          uid: uid,
          email: email,
          displayName: email.split('@')[0],
          photoUrl: '',
          status: 'Hey, I am using Chat App',
          lastSeen: DateTime.now(),
          isOnline: true,
        ));
      } else {
        _databaseService.updateUserStatus(uid, true);
      }
    }).catchError((e) {
      debugPrint('Error updating user status: $e');
    });
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw 'Connexion Google annulée';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null) {
        throw 'Impossible d\'obtenir le token d\'accès Google';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);

      if (result.user != null) {
        _databaseService.createUserProfile(UserModel(
          uid: result.user!.uid,
          email: result.user!.email ?? '',
          displayName: result.user!.displayName ?? '',
          photoUrl: result.user!.photoURL ?? '',
          status: 'Hey, I am using Chat App',
          lastSeen: DateTime.now(),
          isOnline: true,
        )).catchError((e) => debugPrint('Error updating Google user profile: $e'));
      }

      return result;
    } catch (e) {
      debugPrint('Erreur de connexion Google: $e');
      throw 'Échec de la connexion avec Google: ${e.toString()}';
    }
  }

  Future<UserCredential> signInWithFacebook() async {
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login();

      if (loginResult.status != LoginStatus.success) {
        throw 'Facebook sign in failed: ${loginResult.message}';
      }

      final OAuthCredential credential = FacebookAuthProvider.credential(
        loginResult.accessToken!.token,
      );

      final result = await _auth.signInWithCredential(credential);

      if (result.user != null) {
        _databaseService.createUserProfile(
          UserModel(
            uid: result.user!.uid,
            email: result.user!.email ?? '',
            displayName: result.user!.displayName ?? '',
            photoUrl: result.user!.photoURL ?? '',
            status: 'Hey, I am using Chat App',
            lastSeen: DateTime.now(),
            isOnline: true,
          ),
        ).catchError((e) => debugPrint('Error updating Facebook user profile: $e'));
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        _databaseService.updateUserStatus(
          currentUser.uid,
          false,
          lastSeen: DateTime.now(),
        ).catchError((e) => debugPrint('Error updating status during signout: $e'));
      }

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
        FacebookAuth.instance.logOut(),
      ], eagerError: false);
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  Future<void> signOutFromAllProviders() async {
    return signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}