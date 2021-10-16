import 'package:flutter/material.dart';
import 'Authentication.dart';
import 'HomePage.dart';
import 'LoginRegister.dart';

class MappingPage extends StatefulWidget {
  final AuthImplementation auth;

  MappingPage({
    required this.auth,
  });

  @override
  _MappingPageState createState() => _MappingPageState();
}

enum AuthStatus { notSignedIn, signedIn }

class _MappingPageState extends State<MappingPage> {
  AuthStatus _authStatus = AuthStatus.notSignedIn;

  @override
  void initState() {
    super.initState();
    widget.auth.getCurrentUser().then((user) {
      setState(() {
        _authStatus =
            user == null ? AuthStatus.notSignedIn : AuthStatus.signedIn;
      });
    });
  }

  void _signedIn() {
    setState(() {
      _authStatus = AuthStatus.signedIn;
    });
  }

  void _signedOut() {
    setState(() {
      _authStatus = AuthStatus.notSignedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_authStatus) {
      case AuthStatus.notSignedIn:
        return new LoginRegisterPage(
          auth: widget.auth,
          onSignedIn: _signedIn,
        );
      case AuthStatus.signedIn:
        return new HomePage(
          auth: widget.auth,
          onSignedOut: _signedOut,
        );
    }
  }
}
