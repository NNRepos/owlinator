import 'package:flutter/material.dart';

class OwlPage extends StatefulWidget {
  @override
  _OwlPageState createState() => _OwlPageState();
}


class _OwlPageState extends State<OwlPage> {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Panel'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
      ),
    );
  }
}