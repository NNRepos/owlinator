import 'package:Owlinator/Mapping.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'validator.dart';
import 'HomePage.dart';
import 'new_page.dart';
import 'Mapping.dart';
import 'Authentication.dart';
import 'LoginRegister.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp();
  runApp(App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Owlinator',
      theme: ThemeData(
          primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity),
      home: MappingPage(auth: Auth()),
    );
  }
}


