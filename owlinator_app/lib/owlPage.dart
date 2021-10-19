import 'package:flutter/material.dart';

class OwlPage extends StatefulWidget {

  OwlPage({required this.id});
  String id;


  @override
  _OwlPageState createState() => _OwlPageState();
}








class _OwlPageState extends State<OwlPage> {

  List<String> commands = [
    "Trigger Alarm",
    "Stop Alarm",
  ];
  int _selectedIndex = 0;


  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));
    List<Widget> _widgetOptions = <Widget>[
      GridView.count(
        primary: false,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        crossAxisCount: 2,
        children: commands.map((command) {
          return InkWell(
            onTap: () {

            },
            child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(10),
                child: Text(command)),
          );
        }).toList(),
      ),
      Text("Settings"),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Panel'),

      ),
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
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
}
