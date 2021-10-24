import 'package:Owlinator/Mapping.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

import 'Mapping.dart';
import 'Authentication.dart';
import 'data/PushNotificationService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp().whenComplete(() {
    print("Firebase Initialization Completed");
  });
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final pushNotificationService = PushNotificationService(_firebaseMessaging);
   pushNotificationService.initialise();
  print("Firebase Messaging Initialization Completed");
  String? token = await _firebaseMessaging.getToken();
  runApp(App(token));
}

class App extends StatelessWidget {
  const App(this.token, {Key? key}) : super(key: key);
  final String? token;
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return OverlaySupport.global(
        child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Owlinator',
      theme: ThemeData(
          primarySwatch: Colors.red,
          visualDensity: VisualDensity.adaptivePlatformDensity),
      home: MappingPage(auth: Auth(), token: token),
      builder: EasyLoading.init(),
    ));
  }
}
