import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print("Error en Google Sign-In: $e");
      return null;
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;

        final OAuthCredential credential =
        FacebookAuthProvider.credential(accessToken.token);

        final userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      } else {
        print("Facebook login cancelled o fallido: ${result.status}");
        return null;
      }
    } catch (e) {
      print("Error en Facebook Sign-In: $e");
      return null;
    }
  }

  Future<User?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(displayName);

      await userCredential.user?.sendEmailVerification();

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error en registro: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("Error inesperado en registro: $e");
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null && userCredential.user!.emailVerified) {
        return userCredential.user;
      } else {
        print("El correo no ha sido verificado");
        await _auth.signOut();
        return null;
      }
    } on FirebaseAuthException catch (e) {
      print("Error en Email Sign-In: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("Error inesperado en Email Sign-In: $e");
      return null;
    }
  }

  Future<void> sendEmailVerification(User user) async {
    try {
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print("Error al enviar correo de verificación: $e");
    }
  }



  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await FacebookAuth.instance.logOut();
    } catch (e) {
      print("Error al cerrar sesión: $e");
    }
    await _auth.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
