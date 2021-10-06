class Command {
  final String deviceId;
  final DateTime date;
  final String command;
  final bool applied;

  Command(this.deviceId, this.date, this.command, this.applied);


  Command.fromJson(Map<dynamic, dynamic> json)
        :deviceId = json['deviceId'] as String,
        date = DateTime.parse(json['date'] as String),
        command = json['command'] as String,
        applied = json['applied'] as bool;

  Map<dynamic, dynamic> toJson() => <dynamic, dynamic>{
        'deviceId': deviceId,
        'date': date.toString(),
        'command': command,
        'applied': applied.toString(),
      };
}