import 'package:Owlinator/Authentication.dart';

import 'owl_page.dart';
import 'package:flutter/material.dart';


class HomePage extends StatefulWidget {

  HomePage({required this.auth, required this.onSignedOut});
  final AuthImplementation auth;
  final VoidCallback onSignedOut;
  @override
  _HomePageState createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _logoutUser() async {
    try {
      await widget.auth.signOut();
      widget.onSignedOut();
    } catch(e) {
      print("Error: " + e.toString());
    }
  }

  static const TextStyle optionStyle =
  TextStyle(fontSize: 30, fontWeight: FontWeight.bold);
  Widget build(BuildContext context) {

    List<Widget> _widgetOptions = <Widget>[
      ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          ListTile(
            title: Text("Balcony Owl"), //Text(device.name)
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OwlPage())); //OwlPage(device.id)
            },
          ),
          ListTile( title: Text("Roof Owl")),
        ],
      ),
      Text(
        'Index 1: Add Device',
        style: optionStyle,
      ),
      Text(
        'Index 2: Account Settings',
        style: optionStyle,
      ),
      IconButton(
        icon: Icon(Icons.cancel),
        iconSize: 50,
        color: Colors.red,
        onPressed: _logoutUser
      )
    ];



    return Scaffold(
      appBar: buildAppBar(),
      body: Center( child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: buildBottomNavigationBar()
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
        BottomNavigationBarItem(icon: Icon(Icons.flutter_dash), label: "Owls"),
        BottomNavigationBarItem(icon: Icon(Icons.add), label: "Add Device"),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: "Account Settings"),
        BottomNavigationBarItem(icon: Icon(Icons.cancel), label: "Log Out")
      ],
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text("Owlinator")
    );
  }
}