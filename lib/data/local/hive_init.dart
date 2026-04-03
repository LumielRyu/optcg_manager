import 'package:hive_flutter/hive_flutter.dart';

import '../models/card_record.dart';
import 'hive_boxes.dart';

class HiveInit {
  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CardRecordAdapter());
    }

    await Hive.openBox<CardRecord>(HiveBoxes.collection);
  }
}