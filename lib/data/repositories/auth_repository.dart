import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_client_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
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

  AuthRepository(this._client);

  Future<void> signUp({
  required String email,
  required String password,
}) async {
  try {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Usuário não retornado pelo Supabase');
    }
  } catch (e) {
    print('ERRO REAL SIGNUP: $e'); // 👈 MUITO IMPORTANTE
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

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}