import 'message_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'data/command.dart';
import 'data/command_dao.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';

class CommandListState extends State<CommandList> {
  TextEditingController _commandController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance!.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Command History'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _getCommandList(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: TextField(
                      keyboardType: TextInputType.text,
                      controller: _commandController,
                      onChanged: (text) => setState(() {}),
                      onSubmitted: (input) {
                        _sendCommand();
                      },
                      decoration:
                          const InputDecoration(hintText: 'Enter new Command'),
                    ),
                  ),
                ),
                IconButton(
                    icon: Icon(_canSendCommand()
                        ? CupertinoIcons.arrow_right_circle_fill
                        : CupertinoIcons.arrow_right_circle),
                    onPressed: () {
                      _sendCommand();
                    })
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendCommand() {
    if (_canSendCommand()) {
      final command = Command("1", DateTime.now(), _commandController.text, false);
      widget.commandDao.sendCommand(command);
      _commandController.clear();
      setState(() {});
    }
  }

  Widget _getCommandList() {
    return Expanded(
      child: FirebaseAnimatedList(
        controller: _scrollController,
        query: widget.commandDao.getCommandQuery(),
        itemBuilder: (context, snapshot, animation, index) {
          final json = snapshot.value as Map<dynamic, dynamic>;
          final command = Command.fromJson(json);
          return MessageWidget("Device: " + command.deviceId.toString() + ", Command: " + command.command, command.date);
        },
      ),
    );
  }

  bool _canSendCommand() => _commandController.text.length > 0;

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
}

class CommandList extends StatefulWidget {
  CommandList({Key? key}) : super(key: key);

  final commandDao = CommandDao();

  @override
  CommandListState createState() => CommandListState();
}
