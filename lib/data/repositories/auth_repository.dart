import 'package:flutter/foundation.dart';
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
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser;
});

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

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
      if (name.trim().isEmpty) {
        throw Exception('Informe seu nome.');
      }
      if (whatsAppPhone.trim().isEmpty) {
        throw Exception('Informe seu telefone/WhatsApp.');
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Usuario nao retornado pelo Supabase.');
      }

      await _prefs.ensureProfile(
        email: email,
        name: name,
        whatsAppPhone: whatsAppPhone,
      );
    } catch (e) {
      _debugLog('SIGNUP ERROR: $e');
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Usuario nao retornado no login.');
      }
    } catch (e) {
      _debugLog('SIGNIN ERROR: $e');
      rethrow;
    }
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    try {
      final redirectTo = kIsWeb ? Uri.base.origin : null;
      final opened = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
      );

      if (!opened) {
        throw Exception('Nao foi possivel abrir o login social.');
      }
    } catch (e) {
      _debugLog('OAUTH SIGNIN ERROR: $e');
      rethrow;
    }
  }

  Future<bool> needsWhatsAppCompletion() async {
    return !(await _prefs.hasCompletedProfile());
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
