import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/hive_boxes.dart';
import '../services/supabase_client_provider.dart';

final userPreferencesRepositoryProvider =
    Provider<UserPreferencesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UserPreferencesRepository(client);
});

class UserPreferences {
  final String themeMode;
  final String collectionViewMode;
  final String whatsAppPhone;
  final String displayName;

  const UserPreferences({
    required this.themeMode,
    required this.collectionViewMode,
    required this.whatsAppPhone,
    required this.displayName,
  });
}

class UserPreferencesRepository {
  final SupabaseClient _client;
  static const _themeModeKey = 'theme_mode';
  static const _collectionViewModeKey = 'collection_view_mode';

  UserPreferencesRepository(this._client);

  Box get _appPrefsBox => Hive.box(HiveBoxes.appPrefs);

  String getSavedThemeMode() {
    final value = _appPrefsBox.get(_themeModeKey);
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return 'light';
  }

  String getSavedCollectionViewMode() {
    final value = _appPrefsBox.get(_collectionViewModeKey);
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return 'grid';
  }

  Future<UserPreferences> load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return UserPreferences(
        themeMode: getSavedThemeMode(),
        collectionViewMode: getSavedCollectionViewMode(),
        whatsAppPhone: '',
        displayName: '',
      );
    }

    final row = await _client
        .from('profiles')
        .select('theme_mode, collection_view_mode, whatsapp_phone, name')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      return UserPreferences(
        themeMode: getSavedThemeMode(),
        collectionViewMode: getSavedCollectionViewMode(),
        whatsAppPhone: '',
        displayName: '',
      );
    }

    final themeMode = (row['theme_mode'] ?? '').toString().trim();
    final collectionViewMode = (row['collection_view_mode'] ?? '').toString().trim();

    if (themeMode.isNotEmpty) {
      _appPrefsBox.put(_themeModeKey, themeMode);
    }

    if (collectionViewMode.isNotEmpty) {
      _appPrefsBox.put(_collectionViewModeKey, collectionViewMode);
    }

    return UserPreferences(
      themeMode: themeMode.isNotEmpty ? themeMode : getSavedThemeMode(),
      collectionViewMode: collectionViewMode.isNotEmpty
          ? collectionViewMode
          : getSavedCollectionViewMode(),
      whatsAppPhone: (row['whatsapp_phone'] ?? '').toString(),
      displayName: (row['name'] ?? '').toString(),
    );
  }

  Future<void> ensureProfile({
    String? name,
    String? email,
    String? whatsAppPhone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': email ?? user.email,
      if (name != null) 'name': name.trim(),
      if (whatsAppPhone != null) 'whatsapp_phone': whatsAppPhone.trim(),
    });
  }

  Future<void> saveThemeMode(String mode) async {
    await _appPrefsBox.put(_themeModeKey, mode);

    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'theme_mode': mode,
    });
  }

  Future<void> saveCollectionViewMode(String mode) async {
    await _appPrefsBox.put(_collectionViewModeKey, mode);

    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'collection_view_mode': mode,
    });
  }

  Future<void> saveWhatsAppPhone(String phone) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'whatsapp_phone': phone.trim(),
    });
  }

  Future<String> getCurrentWhatsAppPhone() async {
    final prefs = await load();
    return prefs.whatsAppPhone.trim();
  }
}
