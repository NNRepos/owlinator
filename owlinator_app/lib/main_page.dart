import 'owl_page.dart';
import 'package:flutter/material.dart';


class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}


class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1;

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
        BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: "Account Settings")
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