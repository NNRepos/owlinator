import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import '../CommandWidget.dart';
import 'Command.dart';
import 'UserData.dart';

class CommandDao {
  final UserData userData;

  late DatabaseReference _commandsRef;

  CommandDao(this.userData){
    _commandsRef = FirebaseDatabase.instance.reference().child('users').child(userData.uid).child("commands").child('device');
  }



  ScrollController _scrollController = ScrollController();

  void sendCommand(Command command, Device device) {
    _commandsRef.child(device.id).push().set(command.toJson());
  }

  Query getCommandQuery() {
    return _commandsRef;
  }

  Widget getCommandList(Device device) {
    return Expanded(
      child: FirebaseAnimatedList(
        shrinkWrap: true,
        controller: _scrollController,
        query: _commandsRef.child(device.id),
        sort: (a,b) {
          return -(DateTime.parse(a.value['date'] as String)).compareTo(DateTime.parse(b.value['date'] as String));
        },
        itemBuilder: (context, snapshot, animation, index) {
          final json = snapshot.value as Map<dynamic, dynamic>;
          final command = Command.fromJson(json);
          return CommandWidget( command.command, command.date);
        },
      ),
    );
  }

  void deleteDeviceCommands(String id){
    _commandsRef.child(id).remove();
  }
}
