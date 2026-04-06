import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_client_provider.dart';
import 'user_preferences_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(userPreferencesRepositoryProvider);
  return AuthRepository(client, prefs);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser;
});

class AuthRepository {
  final SupabaseClient _client;
  final UserPreferencesRepository _prefs;

  AuthRepository(this._client, this._prefs);

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String whatsAppPhone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Usuário não retornado pelo Supabase.');
      }

      await _prefs.ensureProfile(
        email: email,
        name: name,
        whatsAppPhone: whatsAppPhone,
      );
    } catch (e) {
      print('ERRO REAL SIGNUP: $e');
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('SIGNIN USER: ${response.user?.id}');
      print('SIGNIN EMAIL: ${response.user?.email}');
      print('SIGNIN SESSION: ${response.session != null ? 'OK' : 'NULL'}');

      if (response.user == null) {
        throw Exception('Usuário não retornado no login.');
      }
    } catch (e) {
      print('ERRO REAL SIGNIN: $e');
      rethrow;
    }
  }

  Future<bool> needsWhatsAppCompletion() async {
    final phone = await _prefs.getCurrentWhatsAppPhone();
    return phone.isEmpty;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
