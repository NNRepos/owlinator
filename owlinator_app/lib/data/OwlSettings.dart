import 'UserData.dart';

class OwlSettings {
  Device device;
  bool mute;
  bool fixedHead;
  bool notify;
  int angle;
  int volume;
  String assicatedUid;

  OwlSettings(this.device, this.mute, this.fixedHead, this.notify, this.angle, this.volume, this.assicatedUid);

  OwlSettings.fromJson(Map<dynamic, dynamic> json)
      : device = (Device.fromJson(json['device'] as Map<dynamic, dynamic>)),
        mute = json['settings']['mute'] as bool,
        fixedHead = json['settings']['fixedHead'] as bool,
        notify = json['settings']['notify'] as bool,
        angle = (json['settings']['angle'] as int),
        volume = (json['settings']['volume'] as int),
        assicatedUid = json['settings']['assicatedUid'] as String;

  OwlSettings.defaultSettings(Device device, String uid)
      : device = device,
        mute = false,
        fixedHead = false,
        notify = true,
        angle = 0,
        volume = 100,
        assicatedUid = uid;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'device': device.toJson(),
        'settings': {
          'mute': mute,
          'fixedHead': fixedHead,
          'notify': notify,
          'angle': angle,
          'volume': volume,
          'assicatedUid': assicatedUid
        }
      };
}
