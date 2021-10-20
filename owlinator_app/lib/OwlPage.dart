import 'package:flutter/material.dart';

import 'data/CommandDao.dart';
import 'data/UserData.dart';
import 'data/Command.dart';

class OwlPage extends StatefulWidget {
  OwlPage({required this.device, required this.userData});
  final Device device;
  final UserData userData;

  @override
  _OwlPageState createState() => _OwlPageState(userData);
}

class _OwlPageState extends State<OwlPage> {
  _OwlPageState(this.userData) {
    commandDao = CommandDao(userData);
  }

  UserData userData;
  List<String> commands = [
    "Trigger Alarm",
    "Stop Alarm",
  ];
  int _selectedIndex = 0;
  late CommandDao commandDao;

  Widget build(BuildContext context) {
    List<Widget> _widgetOptions = <Widget>[
      OwlsTabs(),
      SettingsTab()
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
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
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Colors.red,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset: Offset(0, 3), // changes position of shadow
                      ),
                    ],
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
    return Align(child: Text("Settings"));
  }
}
