import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'Authentication.dart';

class LoginRegisterPage extends StatefulWidget {
  LoginRegisterPage({required this.auth, required this.onSignedIn, required this.token});
  final AuthImplementation auth;
  final VoidCallback onSignedIn;
  final String? token;

  @override
  _LoginRegisterPageState createState() => _LoginRegisterPageState();
}

enum FormType { login, register }

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  final formKey = new GlobalKey<FormState>();
  FormType _formType = FormType.login;
  String _email = '';
  String _password = '';
  String _firstName = '';
  String _lastName = '';
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //methods
  bool validateAndSave() {
    final form = formKey.currentState!;
    if (form.validate()) {
      form.save();
      return true;
    } else {
      return false;
    }
  }

  Future<Widget?> validateAndSubmit() async {
    FocusScope.of(context).unfocus();
    if (validateAndSave()) {
      try {
        if (_formType == FormType.login) {
          EasyLoading.show(status: 'Loading...');
          String userId = await widget.auth.signIn(_email, _password);
          EasyLoading.dismiss();
          print("userId: " + userId + " logged in");
        } else {
          EasyLoading.show(status: 'Loading...');
          String userId = await widget.auth.signUp(_email, _password);
          EasyLoading.dismiss();
          final Map<String, String> userData = {
            'firstName': _firstName,
            'lastName': _lastName,
            'email': _email,
            'uid': userId,
            'notificationToken': widget.token ?? ''
          };
          await _firestore.collection('UserData').doc(userId).set(userData);
          print("userId: " + userId + " sign up");
        }

        widget.onSignedIn();
      } on FirebaseAuthException catch (e) {
        print(e.code);
        EasyLoading.dismiss();
        return showDialog(
          context: context,
          builder: (BuildContext context) => _buildPopupDialog(
              context, "Authentication Error", widget.auth.getErrorMessage(e)),
        );
      }
    }
  }

  void moveToRegister() {
    formKey.currentState!.reset();
    setState(() {
      _formType = FormType.register;
    });
  }

  void moveToLogin() {
    formKey.currentState!.reset();
    setState(() {
      _formType = FormType.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title:
                _formType == FormType.login ? Text("Login") : Text("Register")),
        body: SingleChildScrollView(
            child: Container(
                margin: EdgeInsets.all(15.0),
                child: Form(
                    key: formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: createInputs() + createButtons())))));
  }

  List<Widget> createInputs() {
    List<Widget> logoWidget = [
      logo(),
    ];

    List<Widget> names = [
      SizedBox(height: 10.0),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Expanded(
          child: TextFormField(
              decoration: InputDecoration(labelText: 'First Name*'),
              validator: (name) {
                return name == null ? "First Name is required" : null;
              },
              onSaved: (value) {
                _firstName = value!;
              }),
        ),
        Expanded(
          child: TextFormField(
              decoration: InputDecoration(labelText: 'Last Name*'),
              validator: (name) {
                return name == null ? "Last Name is required" : null;
              },
              onSaved: (value) {
                _lastName = value!;
              }),
        )
      ])
    ];

    List<Widget> emailAndPassword = [
      SizedBox(height: 10.0),
      TextFormField(
          decoration: InputDecoration(labelText: 'Email*'),
          validator: (email) {
            if (email == null || email.isEmpty) {
              return 'Please enter an email';
            } else {
              bool emailValid = RegExp(
                      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                  .hasMatch(email);
              if (!emailValid) {
                return 'Please enter a valid email';
              }
            }
            return null;
          },
          onSaved: (value) {
            _email = value!;
          }),
      SizedBox(height: 10.0),
      TextFormField(
          decoration: InputDecoration(labelText: 'Password*'),
          obscureText: true,
          validator: (pass) {
            if (pass == null) {
              return 'Password is required';
            } else if (pass.isEmpty) {
              return 'Password is required';
            }
            return null;
          },
          onSaved: (value) {
            _password = value!;
          }),
    ];

    return _formType == FormType.register
        ? [...logoWidget, ...names, ...emailAndPassword]
        : [...logoWidget, ...emailAndPassword];
  }

  Widget logo() {
    return Image.asset('assets/logo.png',
        width: 200.0, height: 200.0, color: Colors.red);
  }

  List<Widget> createButtons() {
    if (_formType == FormType.login) {
      return [
        TextButton(
            child: Text('Do Not Have an Account? Create Account',
                style: TextStyle(fontSize: 13.0)),
            style: TextButton.styleFrom(primary: Colors.red),
            onPressed: moveToRegister),
        TextButton(
            child: Text('Login', style: TextStyle(fontSize: 20.0)),
            style: TextButton.styleFrom(
                primary: Colors.white, backgroundColor: Colors.green),
            onPressed: validateAndSubmit),
      ];
    } else {
      return [
        TextButton(
            child: Text('Already Have an Account? Login',
                style: TextStyle(fontSize: 13.0)),
            style: TextButton.styleFrom(primary: Colors.red),
            onPressed: moveToLogin),
        TextButton(
            child: Text('Create Account', style: TextStyle(fontSize: 20.0)),
            style: TextButton.styleFrom(
                primary: Colors.white, backgroundColor: Colors.green),
            onPressed: validateAndSubmit),
      ];
    }
  }

  Widget _buildPopupDialog(BuildContext context, String title, String message) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(primary: Colors.black),
          child: Text('Close'),
        ),
      ],
    );
  }
}
