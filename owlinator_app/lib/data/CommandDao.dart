import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import '../CommandWidget.dart';
import 'Command.dart';
import 'UserData.dart';

class CommandDao {
  final UserData userData;

  late DatabaseReference _commandsRef;
  late DatabaseReference _detectionsRef;

  CommandDao(this.userData) {
    _commandsRef =
        FirebaseDatabase.instance.reference().child('users').child(userData.uid)
            .child("commands")
            .child('device');
    _detectionsRef =
        FirebaseDatabase.instance.reference().child('users').child(userData.uid)
            .child("detections")
            .child('device');
  }

  void sendCommand(Command command, Device device) {
    _commandsRef.child(device.id).push().set(command.toJson());
  }

  ScrollController _scrollControllerCommands = ScrollController();
  ScrollController _scrollControllerDetections = ScrollController();

  Widget getCommandList(Device device) {
    return SizedBox(
      height: 480,
      width: 225,
      child: FirebaseAnimatedList(
        shrinkWrap: true,
        controller: _scrollControllerCommands,
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

  Widget getDetectionList(Device device) {
    return SizedBox(
      height: 480,
      width: 225,
      child: FirebaseAnimatedList(
        shrinkWrap: true,
        controller: _scrollControllerDetections,
        query: _detectionsRef.child(device.id),
        sort: (a,b) {
          List<String> dpa = (a.value['time'] as String).split("-");
          DateTime datea = DateTime.parse('${dpa[0]}-${dpa[1]}-${dpa[2]} ${dpa[3]}:${dpa[4]}:${dpa[5]}.0');
          List<String> dpb = (b.value['time'] as String).split("-");
          DateTime dateb = DateTime.parse('${dpb[0]}-${dpb[1]}-${dpb[2]} ${dpb[3]}:${dpb[4]}:${dpb[5]}.0');
          return -(datea.compareTo(dateb));
        },
        itemBuilder: (context, snapshot, animation, index) {
          final json = snapshot.value as Map<dynamic, dynamic>;
          final detection = Detection.fromJson(json);
          return CommandWidget('Bird Detected: ${detection.confidence}% confidence', detection.date);
        },
      ),
    );
  }

  void deleteDeviceCommands(String id){
    _commandsRef.child(id).remove();
  }
}

