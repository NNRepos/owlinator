import 'package:firebase_database/firebase_database.dart';
import 'OwlSettings.dart';

class OwlSettingsDao {



  void setSettings(OwlSettings settings) {
    DatabaseReference _owlSerttingsRef = FirebaseDatabase.instance.reference().child('owls').child(settings.device.id);
    _owlSerttingsRef.set(settings.toJson());
  }

  void updateSettings(OwlSettings settings) {
    DatabaseReference _owlSerttingsRef = FirebaseDatabase.instance.reference().child('owls').child(settings.device.id);
    _owlSerttingsRef.update(settings.toJson());
  }

  Future<OwlSettings?> getSettingsQuery(String deviceId) async {
    OwlSettings? settings = null;
    DatabaseReference _owlSerttingsRef = FirebaseDatabase.instance.reference().child('owls').child(deviceId);
    var snapshot = await _owlSerttingsRef.get();
    settings = OwlSettings.fromJson(snapshot.value as Map<dynamic, dynamic>);
    return settings;
  }

 Future<List<int>> getAllOwlIds() async {
   DatabaseReference _owlSerttingsRef = FirebaseDatabase.instance.reference().child('owls');
    var result = await _owlSerttingsRef.get();
    var intList = result.value == null ? List<int>.empty() : ((result.value as Map< Object?,  Object?>).keys).map((e)=>int.parse(e as String)).toList();
    return intList;
  }
}
