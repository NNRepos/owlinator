class UserData {
  final String firstName;
  final String lastName;
  final String uid;
  final String email;
  List<Device> devices;

  UserData(this.firstName, this.lastName, this.uid, this.email, this.devices);

  UserData.fromJson(Map<dynamic, dynamic> json)
      : firstName = json['firstName'] as String,
        lastName = json['lastName'] as String,
        uid = json['uid'] as String,
        email = json['email'] as String,
        devices = (json['devices'] == null ?  List<Device>.empty()  : (json['devices'] as List<dynamic>)
            .map((dynamic e) => Device.fromJson(e as Map<dynamic, dynamic>))
            .toList());

  UserData.emptyUser():
      firstName = '',
      lastName = '',
      uid = '',
      email = '',
      devices = List<Device>.empty();


  Map<dynamic, dynamic> toJson() => <dynamic, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'uid': uid,
        'email': email,
        'devices': devices.map((e) => e.toJson).toList()
      };
}

class Device {
  String id;
  String name;

  Device(this.id, this.name);

  Device.fromJson(Map<dynamic, dynamic> json)
      : id = json['id'] == null ? 'Invalid Id' : json['id'] as String,
        name = json['name'] == null ? 'Invalid Id' : json['name'] as String;

  Map<dynamic, dynamic> toJson() => <dynamic, dynamic>{'id': id, 'name': name};
}
