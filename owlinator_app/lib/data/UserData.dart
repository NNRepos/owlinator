import 'package:firebase_database/firebase_database.dart';

import 'CommandDao.dart';

class UserData {
  final String firstName;
  final String lastName;
  final String uid;
  final String email;
  List<Device> devices;
  String? notificationToken;

  UserData(this.firstName, this.lastName, this.uid, this.email, this.devices,
      this.notificationToken);

  UserData.fromJson(Map<dynamic, dynamic> json)
      : firstName = json['firstName'] as String,
        lastName = json['lastName'] as String,
        uid = json['uid'] as String,
        email = json['email'] as String,
        notificationToken = json['notificationToken'] == null
            ? null
            : json['notificationToken'] as String,
        devices = (json['devices'] == null
            ? List<Device>.empty()
            : (json['devices'] as List<dynamic>)
                .map((dynamic e) => Device.fromJson(e as Map<dynamic, dynamic>))
                .toList());

  UserData.emptyUser()
      : firstName = '',
        lastName = '',
        uid = '',
        email = '',
        notificationToken = '',
        devices = List<Device>.empty();

  Map<dynamic, dynamic> toJson() {
    return <dynamic, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'uid': uid,
      'email': email,
      'notificationToken': notificationToken,
      'devices': (devices.map((e) => e.toJson()).toList())
    };
  }

  static void createUserData(UserData userData) async {
    await FirebaseDatabase.instance
        .reference()
        .child('userdata')
        .child(userData.uid)
        .set(userData.toJson());
  }

  static Future<UserData> getUserData(String uid) async {
    var snapshot = await FirebaseDatabase.instance
        .reference()
        .child('userdata')
        .child(uid)
        .get();
    return UserData.fromJson(snapshot.value as Map<dynamic, dynamic>);
  }

  static void updateNotificationToken(String uid, String token) async {
    UserData user = await getUserData(uid);
    user.notificationToken = token;
    createUserData(user);
  }

  void removeDevice(List<Device> remainingDevices, Device item) async {
    UserData user = await getUserData(uid);
    user.devices = remainingDevices;
    createUserData(user);
    CommandDao(this).deleteDeviceCommands(item.id);
  }

  void addDevice(List<Device> newDevices) async {
    UserData user = await getUserData(uid);
    user.devices = newDevices;
    createUserData(user);
  }
}

class Device {
  String id;
  String name;

  Device(this.id, this.name);

  Device.fromJson(Map<dynamic, dynamic> json)
      : id = json['id'] == null ? 'Invalid Id' : json['id'].toString(),
        name = json['name'] == null ? 'Invalid Id' : json['name'].toString();

  Map<dynamic, dynamic> toJson() => <dynamic, dynamic>{'id': id, 'name': name};
}
