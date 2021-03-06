import 'package:Owlinator/Authentication.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import 'OwlPage.dart';
import 'package:flutter/material.dart';
import 'data/OwlSettings.dart';
import 'data/UserData.dart';
import 'data/OwlSettingsDao.dart';

class HomePage extends StatefulWidget {
  HomePage(
      {required this.auth,
      required this.firestore,
      required this.onSignedOut,
      required this.token});
  final AuthImplementation auth;
  final VoidCallback onSignedOut;
  final FirebaseFirestore firestore;
  final String? token;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<Device> _devices = [];
  UserData _userData = UserData.emptyUser();

  void _logoutUser() async {
    try {
      await widget.auth.signOut();
      widget.onSignedOut();
    } catch (e) {
      print("Error: " + e.toString());
    }
  }

  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    _updateDeviceList();
    bool noDevices = _devices.length == 0;

    List<Widget> _widgetOptions = <Widget>[
      ListView.builder(
          itemCount: noDevices ? 1 : _devices.length,
          itemBuilder: (BuildContext context, int index) {
            Device? item = noDevices ? null : _devices[index];
            return Dismissible(
                key: Key(noDevices ? "-1" : item!.id),
                onDismissed: (direction) {
                  if (!noDevices) {
                    if (this.mounted)
                      setState(() {
                        _removeDevice(item!);
                        _updateDeviceList();
                      });
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(item!.name + ' was deleted')));
                  }
                },
                confirmDismiss: (DismissDirection direction) async {
                  if (noDevices) return null;
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Confirm"),
                        content: const Text(
                            "Are you sure you wish to delete this item?"),
                        actions: <Widget>[
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text(
                                "DELETE",
                                style: TextStyle(color: Colors.redAccent),
                              )),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("CANCEL",
                                style: TextStyle(color: Colors.black)),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: noDevices
                    ? Card(
                        child: ListTile(
                            title: Text(
                                'You do not have any devices registered to your account. Pressed the plus button to add a device')))
                    : Card(
                        shadowColor: Colors.grey,
                        child: ListTile(
                          leading: ImageIcon(AssetImage('assets/logo.png'),
                              size: 40, color: Colors.red),
                          title: Text(item!.name),
                          subtitle: Text('ID: ' + item.id),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute<OwlPage>(
                                    builder: (context) => OwlPage(
                                          device: item,
                                          userData: _userData,
                                          firestore: widget.firestore,
                                        )));
                          },
                        )));
          }),
      ListView(
        physics: BouncingScrollPhysics(),
        children: [
          SizedBox(height: 200),
          buildName(_userData),
          SizedBox(height: 50),
          Center(
              child: Column(
            children: [
              IconButton(
                  icon: Icon(Icons.cancel),
                  iconSize: 50,
                  color: Colors.red,
                  onPressed: _logoutUser),
              Text(
                'Log Out',
                style: optionStyle,
              ),
            ],
          ))
        ],
      ),
    ];

    return Scaffold(
      appBar: buildAppBar(),
      body: RefreshIndicator(
          onRefresh: _updateDeviceList,
          child: Center(child: _widgetOptions.elementAt(_selectedIndex))),
      bottomNavigationBar: buildBottomNavigationBar(),
      floatingActionButton: _selectedIndex == 1
          ? null
          : FloatingActionButton(
              child: Icon(Icons.add),
              onPressed: () {
                _addDevice(context);
                _updateDeviceList();
              }),
    );
  }

  BottomNavigationBar buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: (value) {
        if (this.mounted)
          setState(() {
            _selectedIndex = value;
          });
      },
      items: [
        BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/logo.png'), size: 20),
            label: "Owls"),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_circle), label: "Account Settings"),
      ],
    );
  }

  AppBar buildAppBar() {
    return AppBar(automaticallyImplyLeading: false, title: Text("Owlinator"));
  }

  Widget buildName(UserData user) => Column(
        children: [
          Text(
            user.firstName + ' ' + user.lastName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(color: Colors.grey),
          )
        ],
      );

  Future<void> _updateDeviceList() async {
    User? user = await widget.auth.getCurrentUser();
    if (user != null) {
      var tempUser = await UserData.getUserData(user.uid);
      setState( () {
        _userData = tempUser;
        _devices = _userData.devices;
      });
    }

    if (widget.token != null &&
        (_userData.notificationToken != widget.token ||
            _userData.notificationToken == null)) {
      print("Updated notification Token");
      UserData.updateNotificationToken(_userData.uid, widget.token!);
    }
  }

  TextEditingController _deviceIdController = TextEditingController();
  TextEditingController _deviceNameController = TextEditingController();

  void _removeDevice(Device item) async {
    _devices.remove(item);
    _userData.removeDevice(_devices, item);
  }

  void _addDevice(BuildContext context) async {
    List<int> existingIds = await OwlSettingsDao().getAllOwlIds();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextField(
                controller: _deviceIdController,
                decoration: InputDecoration(hintText: "Enter the device ID"),
              ),
              TextField(
                controller: _deviceNameController,
                decoration: InputDecoration(hintText: "Enter a friendly name"),
              )
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
                _deviceNameController.clear();
                _deviceIdController.clear();
              },
            ),
            TextButton(
              child: Text('Ok'),
              onPressed: () async {
                String newId = _deviceIdController.text;
                String newName = _deviceNameController.text;
                Device newDevice = Device(newId, newName);
                if (!_devices.contains(newDevice) &&
                    newId.isNotEmpty &&
                    newName.isNotEmpty) {
                  if (existingIds.contains(newId)) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            "Cannot add Owl with id: $newId. Already connected to an account")));
                  } else {
                    List<Device> newDevices = [..._devices, newDevice];
                    newDevices.sort((a, b) {
                      return int.parse(a.id).compareTo(int.parse(b.id));
                    });
                    _userData.addDevice(newDevices);
                    OwlSettings settings =
                        OwlSettings.defaultSettings(newDevice, _userData.uid);
                    OwlSettingsDao().setSettings(settings);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(newName + ' added')));
                  }
                }
                _updateDeviceList();
                Navigator.pop(context);
                _deviceNameController.clear();
                _deviceIdController.clear();
              },
            ),
          ],
        );
      },
    );
  }
}
