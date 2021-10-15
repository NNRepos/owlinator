import 'package:firebase_database/firebase_database.dart';
import 'command.dart';

class CommandDao {
  final DatabaseReference _commandsRef =
      FirebaseDatabase.instance.reference().child("messages");

  void sendCommand(Command command) {
    _commandsRef.push().set(command.toJson());
    print("message saved");
  }

  Query getCommandQuery() {
    return _commandsRef;
  }
}
