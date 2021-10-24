import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm;
  String? token;

  PushNotificationService(this._fcm);

  Future initialise() async {
    if (Platform.isIOS) {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('User granted permission: ${settings.authorizationStatus}');
    }

    // If you want to test the push notification locally,
    // you need to get the token and input to the Firebase console
    // https://console.firebase.google.com/project/YOUR_PROJECT_ID/notification/compose
    token = await _fcm.getToken();
    print("FirebaseMessaging token: $token");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');

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
    });

    // FirebaseMessaging.on
  }
}

class PushNotificationMessage {
  final String title;
  final String body;
  final String? imageUrl;
  PushNotificationMessage(
      {required this.title, required this.body, required this.imageUrl});
}
