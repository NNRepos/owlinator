import 'dart:io' show Platform;

import 'package:Owlinator/Mapping.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  pushNotificationService.initialise();
  print("Firebase Messaging Initialization Completed");
  runApp(App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
        child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Owlinator',
      theme: ThemeData(
          primarySwatch: Colors.red,
          visualDensity: VisualDensity.adaptivePlatformDensity),
      home: MappingPage(auth: Auth()),
      builder: EasyLoading.init(),
    ));
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Got a message whilst in the background!');

  if (message.notification != null) {
    var notification = PushNotificationMessage(
        title: message.notification!.title!,
        body: message.notification!.body!,
        imageUrl: (message.data["url"] != null
            ? message.data["url"] as String?
            : (Platform.isAndroid
                ? message.notification!.android!.imageUrl
                : message.notification!.apple!.imageUrl)));

    print('Message notification: \n'
        'title: ${notification.title}\n'
        'body: ${notification.body}\n'
        'imageUrl: ${notification.imageUrl}');

    showSimpleNotification(
        Container(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Container(
                  alignment: Alignment.centerLeft,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification.title,
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 20.0)),
                        Text(notification.body,
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 15.0))
                      ])),
              notification.imageUrl == null
                  ? Container()
                  : Image.network(notification.imageUrl!,
                      width: 80.0, height: 80.0)
            ])),
        position: NotificationPosition.top,
        background: Colors.lightBlueAccent);
  }
}
