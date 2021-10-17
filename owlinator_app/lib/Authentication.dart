import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthImplementation {
  Future<String> signIn(String email, String pass);
  Future<String> signUp(String email, String pass);
  Future<User?> getCurrentUser();
  Future<void> signOut();
}

class Auth implements AuthImplementation {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<String> signIn(String email, String pass) async {
    UserCredential userCred = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: pass);
    final User user = userCred.user!;
    return user.uid;
  }

  Future<String> signUp(String email, String pass) async {
    UserCredential userCred = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: pass);
    final User user = userCred.user!;
    return user.uid;
  }

  Future<User?> getCurrentUser() async {
    return await _firebaseAuth.currentUser;

  }

  Future<void> signOut() async {
    _firebaseAuth.signOut();
  }

  String getErrorMessage(FirebaseAuthException e){
    String errorMessage = '';
    switch (e.code) {
      case "invalid-email":
        errorMessage = "Your email address appears to be malformed.";
        break;
      case "wrong-password":
        errorMessage = "Your password is wrong.";
        break;
      case "user-not-found":
        errorMessage = "User with this email doesn't exist.";
        break;
      case "user-disabled":
        errorMessage = "User with this email has been disabled.";
        break;
      case "too-many-requests":
        errorMessage = "Too many requests. Try again later.";
        break;
      case "operation-not-allowed":
        errorMessage = "Signing in with Email and Password is not enabled.";
        break;
      case "invalid-password":
        errorMessage = "Password must be at lease six characters";
        break;
      case "weak-password":
        errorMessage = "Password must be at lease six characters";
        break;
      case "email-already-exists":
        errorMessage = "The email used already exists.";
        break;
      default:
        errorMessage = "An undefined Error happened.";
    }
    return errorMessage;
  }
}