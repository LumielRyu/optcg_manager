import 'package:supabase_flutter/supabase_flutter.dart';

bool isApplicationAdmin(User? user) {
  final value = user?.appMetadata['is_weekly_admin'];
  return value == true || value?.toString() == 'true';
}
