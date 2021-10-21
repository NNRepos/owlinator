import 'package:Owlinator/data/OwlSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import 'data/CommandDao.dart';
import 'data/UserData.dart';
import 'data/Command.dart';
import 'data/OwlSettings.dart';

class OwlPage extends StatefulWidget {
  OwlPage(
      {required this.device, required this.userData, required this.firestore});
  Device device;
  final UserData userData;
  final FirebaseFirestore firestore;

  @override
  _OwlPageState createState() => _OwlPageState(userData);
}

class _OwlPageState extends State<OwlPage> {
  _OwlPageState(this.userData) {
    commandDao = CommandDao(userData);
  }

  late UserData userData;
  List<String> commands = [
    "Trigger Alarm",
    "Stop Alarm",
  ];
  String deviceName = 'Owl';
  int _selectedIndex = 0;
  late CommandDao commandDao;
  OwlSettings settings = OwlSettings.defaultSettings(Device("-1", "-1"), "-1");
  TextEditingController _OwlNameController = TextEditingController();

  Widget build(BuildContext context) {
    List<Widget> _widgetOptions = <Widget>[OwlsTabs(), SettingsTab()];
    getSettingsQuery(widget.device.id).then((result) {
      setState(() {
        settings = result!;
      });
    });

    deviceName = widget.device.name;
    return Scaffold(
      appBar: AppBar(
        title: Text("Owl" + (_selectedIndex == 0 ? " Controls" : " Settings")),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: buildBottomNavigationBar(),
    );
  }

  BottomNavigationBar buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: (value) {
        setState(() {
          _selectedIndex = value;
        });
      },
      items: [
        BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/thunder.png'), size: 20),
            label: "Actions"),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_circle), label: "Settings"),
      ],
    );
  }

  void sendCommand(String commandName) {
    Command command =
        Command(widget.device.id, DateTime.now(), commandName, false);
    commandDao.sendCommand(command, widget.device);
    setState(() {});
  }

  Widget OwlsTabs() {
    return Column(children: [
      GridView.count(
        primary: false,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        crossAxisCount: 2,
        shrinkWrap: true,
        children: commands.map((commandName) {
          return InkWell(
              onTap: () {
                sendCommand(commandName);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Executing ' + commandName)));
              },
              child: Container(
                  padding: EdgeInsets.all(10),
                  child: Center(
                      child: Text(commandName,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  decoration: BoxDecoration(
                    // gradient: LinearGradient(
                    //   begin: Alignment.topCenter,
                    //   end: Alignment.bottomCenter,
                    //   colors: [
                    //     Color(0xFFEF5350),
                    //     Color(0xFFB71C1C),
                    //   ],
                    // ),
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10)),
                    // boxShadow: [
                    //   BoxShadow(
                    //     color: Colors.grey.withOpacity(0.7),
                    //     spreadRadius: 5,
                    //     blurRadius: 5,
                    //     offset: Offset(3, 7), // changes position of shadow
                    //   ),
                    // ],
                  )));
        }).toList(),
      ),
      Container(
          child: Align(
            child: Text("Action History",
                style: TextStyle(fontSize: 20, color: Colors.grey)),
            alignment: Alignment.centerLeft,
          ),
          padding: const EdgeInsets.only(left: 20, bottom: 5)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        child:
            Container(height: 1.0, width: double.infinity, color: Colors.grey),
      ),
      commandDao.getCommandList(widget.device),
    ]);
  }

  Widget SettingsTab() {
    return SettingsList(
      sections: [
        SettingsSection(
          title: "",
          tiles: [],
        ),
        SettingsSection(title: 'Owl Settings ', tiles: [
          SettingsTile(
              title: 'Owl Name',
              subtitle: widget.device.name,
              leading: ImageIcon(AssetImage('assets/logo.png')),
              trailing: Icon(Icons.edit),
              onPressed: (BuildContext context) {
                _changeDeviceName();
              }),
          SettingsTile.switchTile(
            title: 'Mute',
            subtitle: "Mute sound when bird is detected.",
            leading: Icon(
                settings.mute == true ? Icons.volume_off : Icons.volume_up),
            onToggle: (bool value) {
              setState(() {
                settings.mute = value;
                updateSettings(settings);
              });
            },
            switchValue: settings.mute,
          ),
        ]),
        CustomSection(
            child: Column(children: [
          SettingsTile(
            title: 'Volume',
            subtitle: settings.volume.round().toString(),
            leading: Icon(
                settings.volume >= 50.0 ? Icons.volume_up : Icons.volume_down),
          ),
          Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom: BorderSide(width: .5, color: Colors.grey))),
              child: Slider(
                  value: settings.volume,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: settings.mute == true
                      ? null
                      : (double value) {
                          setState(() {
                            settings.volume = value;
                            updateSettings(settings);
                          });
                        })),
          Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom: BorderSide(width: .5, color: Colors.grey))),
              child: SettingsTile.switchTile(
                title: 'Fixed Head',
                subtitle: "Fix head to specified angle",
                leading: Icon(settings.fixedHead == true
                    ? Icons.gps_fixed
                    : Icons.rotate_left),
                onToggle: (bool value) {
                  setState(() {
                    settings.fixedHead = value;
                    updateSettings(settings);
                  });
                },
                switchValue: settings.fixedHead,
              )),
          SettingsTile(
            title: 'Head Angle',
            subtitle: settings.angle.round().toString(),
            leading: Icon(Icons.rotate_left),
          ),
          Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom: BorderSide(width: .5, color: Colors.grey))),
              child: Slider(
                  value: settings.angle,
                  min: 0,
                  max: 180,
                  divisions: 180,
                  onChanged: settings.fixedHead == false
                      ? null
                      : (double value) {
                          setState(() {
                            settings.angle = value;
                            updateSettings(settings);
                          });
                        })),
          SettingsTile.switchTile(
            title: 'Enable Notifications',
            subtitle: 'Receive notifications on\nbird detection.',
            leading: Icon(Icons.notifications_active),
            switchValue: settings.notify,
            onToggle: (value) {
              settings.notify = value;
              updateSettings(settings);
            },
          ),
        ])),
        CustomSection(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 8),
                child: Image.asset(
                  'assets/logo.png',
                  height: 50,
                  width: 50,
                  color: Color(0xFF777777),
                ),
              ),
              Text(
                'Version: 1.0.0',
                style: TextStyle(color: Color(0xFF777777)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _changeDeviceName() async {
    _OwlNameController.text = deviceName;
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              title: Text('Change Owl Name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextField(
                    controller: _OwlNameController,
                    decoration: InputDecoration(hintText: "Enter a new name"),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.pop(context);
                    _OwlNameController.clear();
                  },
                ),
                TextButton(
                  child: Text('Ok'),
                  onPressed: () async {
                    String newName = _OwlNameController.text;
                    Device newDevice = Device(widget.device.id, newName);
                    if (newName.isNotEmpty) {
                      List<Device> currentDevices = userData.devices;
                      final index = currentDevices.indexWhere((element) => element.id == widget.device.id);
                      currentDevices.removeAt(index);
                      List<Device> newDevices = [
                        ...(currentDevices),
                        newDevice
                      ];
                      print((newDevices.map((e) => e.toJson()).toList()));
                      newDevices.sort((a, b) {
                        return int.parse(a.id).compareTo(int.parse(b.id));
                      });
                      userData.devices = newDevices;
                      await widget.firestore
                          .collection('UserData')
                          .doc(userData.uid)
                          .set(<String, List<Map<dynamic, dynamic>>>{
                        'devices': (newDevices.map((e) => e.toJson()).toList())
                      }, SetOptions(merge: true));

                      setState(() {
                        deviceName = newName;
                        settings.device.name = newName;
                      });
                      updateSettings(settings);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Changed name to " + newName)));
                    }
                    //_updateDeviceList();
                    Navigator.pop(context);
                    _OwlNameController.clear();
                  },
                )
              ]);
        });
  }

  void setSettings(OwlSettings settings) {
    FirebaseFirestore.instance
        .collection("Owls")
        .doc(settings.device.id)
        .set(settings.toJson());
  }

  void updateSettings(OwlSettings settings) {
    FirebaseFirestore.instance
        .collection("Owls")
        .doc(settings.device.id)
        .update(settings.toJson());
  }

  Future<OwlSettings?> getSettingsQuery(String deviceId) async {
    OwlSettings? settings = null;
    await FirebaseFirestore.instance
        .collection("Owls")
        .doc(deviceId)
        .get()
        .then<dynamic>((DocumentSnapshot<Object?> snapshot) {
      settings = OwlSettings.fromJson(snapshot.data() as Map<String, dynamic>);
    });
    return settings;
  }
}
