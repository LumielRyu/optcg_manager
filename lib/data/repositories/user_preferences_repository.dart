import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_client_provider.dart';

final userPreferencesRepositoryProvider =
    Provider<UserPreferencesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UserPreferencesRepository(client);
});

class UserPreferences {
  final String themeMode;
  final String collectionViewMode;

  const UserPreferences({
    required this.themeMode,
    required this.collectionViewMode,
  });
}

class UserPreferencesRepository {
  final SupabaseClient _client;

  UserPreferencesRepository(this._client);

  Future<UserPreferences> load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const UserPreferences(
        themeMode: 'light',
        collectionViewMode: 'grid',
      );
    }

    final row = await _client
        .from('profiles')
        .select('theme_mode, collection_view_mode')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      return const UserPreferences(
        themeMode: 'light',
        collectionViewMode: 'grid',
      );
    }

    return UserPreferences(
      themeMode: (row['theme_mode'] ?? 'light').toString(),
      collectionViewMode: (row['collection_view_mode'] ?? 'grid').toString(),
    );
  }

  Future<void> saveThemeMode(String mode) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'theme_mode': mode,
    });
  }

  Future<void> saveCollectionViewMode(String mode) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'collection_view_mode': mode,
    });
  }
}