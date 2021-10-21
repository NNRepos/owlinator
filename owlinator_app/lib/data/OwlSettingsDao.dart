import 'package:cloud_firestore/cloud_firestore.dart';
import 'OwlSettings.dart';

class OwlSettingsDao {
  void setSettings(OwlSettings settings) {
    FirebaseFirestore.instance
        .collection("Owls")
        .doc(settings.device.id)
        .set(settings.toJson());
  }

  void updateSettings(OwlSettings settings) {
    FirebaseFirestore.instance
        .collection("Owls")
        .doc(settings.device.id)
        .update(settings.toJson());
  }

  Future<OwlSettings?> getSettingsQuery(String deviceId) async {
    OwlSettings? settings = null;
    await FirebaseFirestore.instance
        .collection("Owls")
        .doc(deviceId)
        .get()
        .then<dynamic>((DocumentSnapshot<Object?> snapshot) {
      settings = OwlSettings.fromJson(snapshot.data() as Map<String, dynamic>);
    });
    return settings;
  }

 Future<List<String>> getAllOwlIds() async {
    final QuerySnapshot<Map<String, dynamic>> result = await FirebaseFirestore.instance
        .collection("Owls")
        .get(GetOptions(source: Source.server));
    return result.docs.map((e) => e.id).toList();
  }
}
