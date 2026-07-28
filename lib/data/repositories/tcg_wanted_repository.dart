import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tcg_collection_item.dart';
import '../models/tcg_wanted_listing.dart';
import '../services/supabase_client_provider.dart';
import 'user_preferences_repository.dart';

final tcgWantedRepositoryProvider = Provider<TcgWantedRepository>((ref) {
  return TcgWantedRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(userPreferencesRepositoryProvider),
  );
});

class TcgWantedRepository {
  static const _columns =
      'id, user_id, game_slug, catalog_card_id, variant_id, card_code, '
      'quantity, is_public, is_active, contact_info, notes, created_at, '
      'image_url, name, set_name, rarity, color, type, text, attribute';
  static const _publicColumns =
      'id, user_id, game_slug, catalog_card_id, variant_id, card_code, '
      'quantity, is_public, is_active, notes, created_at, image_url, name, '
      'set_name, rarity, color, type, text, attribute';

  final SupabaseClient _client;
  final UserPreferencesRepository _preferences;

  const TcgWantedRepository(this._client, this._preferences);

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('É necessário entrar para gerenciar cartas procuradas.');
    }
    return user;
  }

  Future<List<TcgWantedListing>> listMine(String gameSlug) async {
    final user = _requireUser();
    return _fetch(
      gameSlug: gameSlug,
      userId: user.id,
      onlyPublic: false,
      includeContact: true,
    );
  }

  Future<List<TcgWantedListing>> listPublic(String gameSlug) {
    return _fetch(gameSlug: gameSlug, onlyPublic: true, includeContact: false);
  }

  Future<List<TcgWantedListing>> listPublicByUser({
    required String gameSlug,
    required String userId,
  }) {
    return _fetch(
      gameSlug: gameSlug,
      userId: userId,
      onlyPublic: true,
      includeContact: false,
    );
  }

  Future<void> addOrIncrement(TcgCollectionDraft draft) async {
    final user = _requireUser();
    final existing = await _client
        .from('wanted_cards')
        .select('id, quantity')
        .eq('user_id', user.id)
        .eq('game_slug', draft.gameSlug)
        .eq('catalog_card_id', draft.catalogCardId)
        .eq('variant_id', draft.variantId)
        .limit(1);
    if (existing.isNotEmpty) {
      final row = Map<String, dynamic>.from(existing.first);
      final quantity = int.tryParse((row['quantity'] ?? 0).toString()) ?? 0;
      await _client
          .from('wanted_cards')
          .update({
            'quantity': (quantity + 1).clamp(1, 999),
            'is_active': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', row['id']);
      return;
    }

    final whatsApp = await _preferences.getCurrentWhatsAppPhone();
    await _client.from('wanted_cards').insert({
      'user_id': user.id,
      'game_slug': draft.gameSlug,
      'catalog_card_id': draft.catalogCardId,
      'variant_id': draft.variantId,
      'card_code': draft.cardCode,
      'quantity': 1,
      'is_public': true,
      'is_active': true,
      'contact_info': whatsApp,
      'notes': '',
      'image_url': draft.imageUrl,
      'name': draft.name,
      'set_name': draft.setName,
      'rarity': draft.rarity,
      'color': draft.color,
      'type': draft.type,
      'text': draft.text,
      'attribute': draft.attribute,
    });
  }

  Future<void> update({
    required String id,
    required int quantity,
    required String notes,
    required bool isActive,
    required bool isPublic,
  }) async {
    final user = _requireUser();
    final whatsApp = await _preferences.getCurrentWhatsAppPhone();
    await _client
        .from('wanted_cards')
        .update({
          'quantity': quantity.clamp(1, 999),
          'notes': notes.trim(),
          'is_active': isActive,
          'is_public': isPublic,
          'contact_info': whatsApp,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<void> delete(String id) async {
    final user = _requireUser();
    await _client
        .from('wanted_cards')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<String> getPublicContact(String id) async {
    _requireUser();
    final response = await _client.rpc(
      'get_public_wanted_card_contact',
      params: {'wanted_card_id': id},
    );
    return (response ?? '').toString();
  }

  Future<List<TcgWantedListing>> _fetch({
    required String gameSlug,
    required bool onlyPublic,
    required bool includeContact,
    String? userId,
  }) async {
    var query = _client
        .from('wanted_cards')
        .select(includeContact ? _columns : _publicColumns)
        .eq('game_slug', gameSlug);
    if (userId != null) query = query.eq('user_id', userId);
    if (onlyPublic) {
      query = query.eq('is_public', true).eq('is_active', true);
    }
    final response = await query.order('created_at', ascending: false);
    final rows = (response as List)
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    final names = await _loadSeekerNames(
      rows.map((row) => (row['user_id'] ?? '').toString()).toSet(),
    );
    return rows
        .map(
          (row) => TcgWantedListing.fromRow(
            row,
            seekerName: names[(row['user_id'] ?? '').toString()] ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, String>> _loadSeekerNames(Set<String> userIds) async {
    userIds.removeWhere((id) => id.isEmpty);
    if (userIds.isEmpty) return const {};
    final response = await _client.rpc(
      'get_public_seller_profiles',
      params: {'user_ids': userIds.toList(growable: false)},
    );
    return {
      for (final raw in response as List)
        (raw['id'] ?? '').toString(): (raw['name'] ?? '').toString(),
    };
  }
}
