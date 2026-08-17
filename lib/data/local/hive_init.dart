import 'package:hive_flutter/hive_flutter.dart';

import '../models/card_record.dart';
import 'hive_boxes.dart';

class HiveInit {
  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CardRecordAdapter());
    }

    // These boxes are independent. Opening them together shortens the cold
    // start, especially after the browser has evicted IndexedDB connections.
    await Future.wait<Object>([
      Hive.openBox<CardRecord>(HiveBoxes.collection),
      Hive.openBox(HiveBoxes.libraryPrefs),
      Hive.openBox(HiveBoxes.apiCache),
      Hive.openBox(HiveBoxes.appPrefs),
    ]);
  }
}
