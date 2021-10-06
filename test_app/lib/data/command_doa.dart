import 'package:firebase_database/firebase_database.dart';
import 'command.dart';

class CommandDao {
  final DatabaseReference _commandsRef =
  FirebaseDatabase.instance.reference().child('commands');




  void sendCommand(Command command) {
    _commandsRef.set(command.toJson());
    // _commandsRef.push().set(command.toJson());
  }

  Query getCommandQuery() {
    return _commandsRef;
  }
}

