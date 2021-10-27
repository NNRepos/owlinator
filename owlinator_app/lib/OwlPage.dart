import 'package:Owlinator/data/OwlSettings.dart';
import 'package:Owlinator/data/OwlSettingsDao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'data/CommandDao.dart';
import 'data/UserData.dart';
import 'data/Command.dart';
import 'data/OwlSettings.dart';

// ignore: must_be_immutable
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
    settingsDao = OwlSettingsDao();
  }

  @override
  void initState() {
    super.initState();
    imageUrls = _getImageUrls();
  }

  late Future<List<Map<String, dynamic>>> imageUrls;
  late UserData userData;
  late OwlSettingsDao settingsDao;
  List<String> commands = [
    "Trigger Alarm",
    "Stop Alarm",
  ];
  String deviceName = 'Owl';
  int _selectedIndex = 0;
  late CommandDao commandDao;
  static firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instanceFor(bucket: 'taken-images');
  OwlSettings settings = OwlSettings.defaultSettings(Device("-1", "-1"), "-1");
  TextEditingController _OwlNameController = TextEditingController();

  Widget build(BuildContext context) {
    List<Widget> _widgetOptions = <Widget>[
      OwlsTabs(),
      DetectionTab(),
      SettingsTab()
    ];
    settingsDao.getSettingsQuery(widget.device.id).then((result) {
      setState(() {
        if (this.mounted) {
          settings = result!;
        }
      });
    });

    deviceName = widget.device.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName +
            [" Controls", " Detections", " Settings"][_selectedIndex]),
      ),
      body:  RefreshIndicator(
      onRefresh: updateDetections,
      child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: buildBottomNavigationBar(),
    );
  }

 Future<void> updateDetections() async {
   setState(() {
     imageUrls = _getImageUrls();
   });
 }

  BottomNavigationBar buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: (value) {
        setState(() {
          if (this.mounted) {
            _selectedIndex = value;
          }
        });
      },
      items: [
        BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/thunder.png'), size: 20),
            label: "Actions"),
        BottomNavigationBarItem(
            icon: Icon(Icons.photo_library), label: "Detections"),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_circle), label: "Settings"),
      ],
    );
  }

  void sendCommand(String commandName) {
    Command command =
        Command(widget.device.id, DateTime.now(), commandName, false);
    commandDao.sendCommand(command, widget.device);
    //setState(() {});
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
                if (this.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Executing ' + commandName)));
                }
              },
              child: Container(
                  padding: EdgeInsets.all(10),
                  child: Center(
                      child: Text(commandName,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10)),
                  )));
        }).toList(),
      ),
      Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        Container(
            child: Align(
              child: Text("Actions",
                  style: TextStyle(fontSize: 20, color: Colors.grey)),
              alignment: Alignment.centerLeft,
            ),
            padding: const EdgeInsets.only(left: 20, bottom: 5)),
        Container(
            child: Align(
              child: Text("Detections",
                  style: TextStyle(fontSize: 20, color: Colors.grey)),
              alignment: Alignment.centerLeft,
            ),
            padding: const EdgeInsets.only(left: 20, bottom: 5))
      ]),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        child:
            Container(height: 1.0, width: double.infinity, color: Colors.grey),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        commandDao.getCommandList(widget.device),
        commandDao.getDetectionList(widget.device)
      ])
    ]);
  }

  Widget DetectionTab() {
    Widget noImagesWidget = Center(
        child: Text("There are no detections", style: TextStyle(fontSize: 30)));
    Widget errorWidget = Center(
        child: Text("There was an error while retrieving detections",
            style: TextStyle(fontSize: 30)));
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: imageUrls,
        builder: (BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              print(snapshot.error);
              return errorWidget;
            }
            if (snapshot.hasData) {
              return snapshot.data!.length == 0
                  ? noImagesWidget
                  : GridView.builder(
                      primary: true,
                      padding: const EdgeInsets.all(20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2),
                      shrinkWrap: false,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          child: Column(children: [
                            Container(
                                padding: const EdgeInsets.fromLTRB(5, 0, 5, 10),
                                width: 200.0,
                                height: 150.0,
                                child: Image.network(
                                    snapshot.data![index]['url']! as String,
                                    loadingBuilder: (BuildContext context,
                                        Widget child,
                                        ImageChunkEvent? loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                                    fit: BoxFit.scaleDown,
                                    width: 200.0,
                                    height: 150.0)),
                            Row(
                              children: [
                                Text(snapshot.data![index]['date']! as String,
                                    style: TextStyle(fontSize: 10)),
                                Text(
                                    "Confidence: ${(snapshot.data![index]['confidence']! as double)}%  ",
                                    style: TextStyle(fontSize: 10))
                              ],
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            )
                          ]),
                        );
                      });
            } else {
              return noImagesWidget;
            }
          } else {
            return Center(child: CircularProgressIndicator());
          }
        });
  }

  Future<List<Map<String, dynamic>>> _getImageUrls() async {
    firebase_storage.ListResult allImages =
        await storage.ref(widget.device.id).listAll();
    List<Map<String, dynamic>> urls = [];
    allImages.items.forEach((firebase_storage.Reference ref) async {
      String url = await ref.getDownloadURL();
      List<String> decomp = ref.name.split("_");
      List<int> dateParts =
          decomp[0].split("-").map((e) => int.parse(e)).toList();
      DateTime date = DateTime(dateParts[0], dateParts[1], dateParts[2],
          dateParts[3], dateParts[4], dateParts[5]);
      var regex = RegExp(r'\d*.?\d{1,2}');
      double confidence = double.parse(regex.firstMatch(decomp[1])!.group(0)!);
      urls.add(<String, dynamic>{
        'url': url,
        'confidence': confidence,
        'date':
            " ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}",
        'Date': date
      });
      urls.sort((a, b) =>
          -(a['Date'] as DateTime).compareTo((b['Date'] as DateTime)));
    });

    return urls;
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
                if (this.mounted) {
                  settings.mute = value;
                  settingsDao.updateSettings(settings);
                }
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
                  color: Colors.white12,
                  border: Border(
                      bottom: BorderSide(width: .5, color: Colors.grey))),
              child: Slider(
                  value: settings.volume.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: settings.mute == true
                      ? null
                      : (double value) {
                          setState(() {
                            if (this.mounted) {
                              settings.volume = value.toInt();
                              settingsDao.updateSettings(settings);
                            }
                          });
                        })),
          Container(
              decoration: BoxDecoration(
                  color: Colors.white12,
                  border: Border(
                      bottom: BorderSide(width: .5, color: Colors.grey))),
              child: SettingsTile.switchTile(
                title: 'Fixed Body',
                subtitle: "Fix body to specified angle",
                leading: Icon(settings.fixedHead == true
                    ? Icons.gps_fixed
                    : Icons.rotate_left),
                onToggle: (bool value) {
                  setState(() {
                    if (this.mounted) {
                      settings.fixedHead = value;
                      settingsDao.updateSettings(settings);
                    }
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
                  color: Colors.white12,
                  border: Border(
                      bottom: BorderSide(width: .5, color: Colors.grey))),
              child: Slider(
                  value: settings.angle.toDouble(),
                  min: 0,
                  max: 180,
                  divisions: 180,
                  onChanged: settings.fixedHead == false
                      ? null
                      : (double value) {
                          setState(() {
                            if (this.mounted) {
                              settings.angle = value.toInt();
                              settingsDao.updateSettings(settings);
                            }
                          });
                        })),
          SettingsTile.switchTile(
            title: 'Enable Notifications',
            subtitle: 'Receive notifications on\nbird detection.',
            leading: Icon(Icons.notifications_active),
            switchValue: settings.notify,
            onToggle: (value) {
              settings.notify = value;
              settingsDao.updateSettings(settings);
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
                      final index = currentDevices.indexWhere(
                          (element) => element.id == widget.device.id);
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
                        if (this.mounted) {
                          deviceName = newName;
                          settings.device.name = newName;
                        }
                      });
                      settingsDao.updateSettings(settings);
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
