import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommandWidget extends StatelessWidget {
  final String message;
  final DateTime date;

  CommandWidget(this.message, this.date);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(width: 1.0, color: Colors.grey)),
        color: Colors.white,
      ),
      child: Column(children: [
          Container(
          height: 30,
          child:MaterialButton(
          disabledTextColor: Colors.black,
          padding: EdgeInsets.only(left: 15, top: 10),
          onPressed: null,
          child:  Align(
            child: Text(message, style: TextStyle(fontSize: 12)),
            alignment: Alignment.centerLeft,
          ),
        )),
        Align(
            alignment: Alignment.bottomRight,
            child: Text(
              DateFormat('yyyy-MM-dd, kk:mma').format(date).toString(),
              style: TextStyle(color: Colors.grey, fontSize: 9),
            )),
      ]),
    );
  }
}
