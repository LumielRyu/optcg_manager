import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/hive_boxes.dart';
import '../services/supabase_client_provider.dart';

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>((
  ref,
) {
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
  static const _profileUserIdKey = 'profile_user_id';
  static const _profileNameKey = 'profile_name';
  static const _profileWhatsAppKey = 'profile_whatsapp_phone';

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

  String? _currentUserIdOrNull() => _client.auth.currentUser?.id;

  bool _hasCachedProfileForCurrentUser() {
    final userId = _currentUserIdOrNull();
    if (userId == null) return false;

    return _appPrefsBox.get(_profileUserIdKey) == userId;
  }

  String getCachedDisplayName() {
    if (!_hasCachedProfileForCurrentUser()) return '';
    final value = _appPrefsBox.get(_profileNameKey);
    return value is String ? value.trim() : '';
  }

  String getCachedWhatsAppPhone() {
    if (!_hasCachedProfileForCurrentUser()) return '';
    final value = _appPrefsBox.get(_profileWhatsAppKey);
    return value is String ? value.trim() : '';
  }

  bool? getCachedProfileCompletionStatus() {
    if (!_hasCachedProfileForCurrentUser()) return null;
    final name = getCachedDisplayName();
    final phone = getCachedWhatsAppPhone();
    return name.isNotEmpty && phone.isNotEmpty;
  }

  void _cacheProfileSnapshot({
    required String userId,
    String? name,
    String? whatsAppPhone,
  }) {
    _appPrefsBox.put(_profileUserIdKey, userId);
    if (name != null) {
      _appPrefsBox.put(_profileNameKey, name.trim());
    }
    if (whatsAppPhone != null) {
      _appPrefsBox.put(_profileWhatsAppKey, whatsAppPhone.trim());
    }
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
    final collectionViewMode = (row['collection_view_mode'] ?? '')
        .toString()
        .trim();

    if (themeMode.isNotEmpty) {
      _appPrefsBox.put(_themeModeKey, themeMode);
    }

    if (collectionViewMode.isNotEmpty) {
      _appPrefsBox.put(_collectionViewModeKey, collectionViewMode);
    }

    _cacheProfileSnapshot(
      userId: user.id,
      name: (row['name'] ?? '').toString(),
      whatsAppPhone: (row['whatsapp_phone'] ?? '').toString(),
    );

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

    _cacheProfileSnapshot(
      userId: user.id,
      name: name ?? getCachedDisplayName(),
      whatsAppPhone: whatsAppPhone ?? getCachedWhatsAppPhone(),
    );
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

    _cacheProfileSnapshot(
      userId: user.id,
      name: getCachedDisplayName(),
      whatsAppPhone: phone,
    );
  }

  Future<void> saveDisplayName(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'name': name.trim(),
    });

    _cacheProfileSnapshot(
      userId: user.id,
      name: name,
      whatsAppPhone: getCachedWhatsAppPhone(),
    );
  }

  Future<void> saveProfileDetails({
    required String name,
    required String whatsAppPhone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'name': name.trim(),
      'whatsapp_phone': whatsAppPhone.trim(),
    });

    _cacheProfileSnapshot(
      userId: user.id,
      name: name,
      whatsAppPhone: whatsAppPhone,
    );
  }

  Future<bool> hasCompletedProfile({bool preferCache = true}) async {
    final cached = getCachedProfileCompletionStatus();
    if (preferCache && cached != null) {
      return cached;
    }

    final prefs = await load();
    return prefs.displayName.trim().isNotEmpty &&
        prefs.whatsAppPhone.trim().isNotEmpty;
  }

  Future<String> getCurrentWhatsAppPhone() async {
    final cached = getCachedWhatsAppPhone();
    if (cached.isNotEmpty) return cached;
    final prefs = await load();
    return prefs.whatsAppPhone.trim();
  }

  Future<String> getCurrentDisplayName() async {
    final cached = getCachedDisplayName();
    if (cached.isNotEmpty) return cached;
    final prefs = await load();
    return prefs.displayName.trim();
  }
}
