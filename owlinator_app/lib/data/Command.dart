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
        applied = json['applied'] == "false" ? false : true;

  Map<dynamic, dynamic> toJson() => <dynamic, dynamic>{
    'deviceId': deviceId,
    'date': date.toString(),
    'command': command,
    'applied': applied.toString(),
  };
}

class Detection {
  final int confidence;
  final DateTime date;



  Detection(this.confidence, this.date);

  static Detection fromJson(Map<dynamic, dynamic> json){
    int confidence = json['confidence'] as int;
    List<String> dp = (json['time'] as String).split("-");
    DateTime date = DateTime.parse('${dp[0]}-${dp[1]}-${dp[2]} ${dp[3]}:${dp[4]}:${dp[5]}.0');
    return Detection(confidence, date);
  }


}