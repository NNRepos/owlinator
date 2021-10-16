import 'package:flutter/material.dart';
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
    return await _firebaseAuth.currentUser!;

  }

  Future<void> signOut() async {
    _firebaseAuth.signOut();
  }
}