import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/op_card.dart';
import '../models/wanted_card_listing.dart';
import '../services/op_api_service.dart';
import '../services/supabase_client_provider.dart';
import 'user_preferences_repository.dart';

final wantedCardsRepositoryProvider = Provider<WantedCardsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final opApi = ref.watch(opApiServiceProvider);
  final prefs = ref.watch(userPreferencesRepositoryProvider);
  return WantedCardsRepository(client, opApi, prefs);
});

class WantedCardsRepository {
  final SupabaseClient _client;
  final OpApiService _opApi;
  final UserPreferencesRepository _prefs;

  static const String _columns =
      'id, user_id, card_code, quantity, is_public, is_active, contact_info, '
      'notes, created_at, image_url, name, set_name, rarity, color, type, '
      'text, attribute';

  final Map<String, OpCard?> _apiCardCache = {};
  final Map<String, String> _seekerNameCache = {};

  WantedCardsRepository(this._client, this._opApi, this._prefs);

  Future<List<WantedCardListing>> getGlobalWantedCards() {
    return _fetchWantedCards(onlyPublic: true);
  }

  Future<List<WantedCardListing>> getMyWantedCards() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    return _fetchWantedCards(userId: user.id, onlyPublic: false);
  }

  Future<void> addWantedCard({
    required String rawCardCode,
    required int quantity,
    required String notes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final normalizedCode = _opApi.normalizeCode(rawCardCode);
    if (normalizedCode.isEmpty) {
      throw Exception('Codigo da carta invalido.');
    }

    final card = await _opApi.findCardByCode(normalizedCode);
    if (card == null) {
      throw Exception('Carta nao encontrada na biblioteca One Piece.');
    }

    final whatsAppPhone = await _prefs.getCurrentWhatsAppPhone();

    await _client.from('wanted_cards').insert({
      'user_id': user.id,
      'card_code': card.code,
      'quantity': quantity.clamp(1, 999),
      'is_public': true,
      'is_active': true,
      'contact_info': whatsAppPhone,
      'notes': notes.trim(),
      'image_url': card.image,
      'name': card.name,
      'set_name': card.setName,
      'rarity': card.rarity,
      'color': card.color,
      'type': card.type,
      'text': card.text,
      'attribute': card.attribute,
    });
  }

  Future<void> updateWantedCard({
    required String id,
    required int quantity,
    required String notes,
    required bool isActive,
  }) async {
    final whatsAppPhone = await _prefs.getCurrentWhatsAppPhone();

    await _client
        .from('wanted_cards')
        .update({
          'quantity': quantity.clamp(1, 999),
          'notes': notes.trim(),
          'is_active': isActive,
          'contact_info': whatsAppPhone,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteWantedCard(String id) async {
    await _client.from('wanted_cards').delete().eq('id', id);
  }

  Future<List<WantedCardListing>> _fetchWantedCards({
    String? userId,
    required bool onlyPublic,
  }) async {
    await _opApi.preload();

    var query = _client.from('wanted_cards').select(_columns);

    if (userId != null) {
      query = query.eq('user_id', userId);
    }

    if (onlyPublic) {
      query = query.eq('is_public', true).eq('is_active', true);
    }

    final response = await query.order('created_at', ascending: false);
    final rows = (response as List)
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);

    final cardCodes = <String>{};
    final userIds = <String>{};
    for (final row in rows) {
      final cardCode = (row['card_code'] ?? '').toString().trim().toUpperCase();
      if (cardCode.isNotEmpty) cardCodes.add(cardCode);

      final ownerId = (row['user_id'] ?? '').toString().trim();
      if (ownerId.isNotEmpty) userIds.add(ownerId);
    }

    await Future.wait([
      _warmUpApiCards(cardCodes),
      _warmUpSeekerNames(userIds),
    ]);

    return rows.map(_mapRowToListing).toList(growable: false);
  }

  Future<void> _warmUpApiCards(Set<String> cardCodes) async {
    final missingCodes = cardCodes
        .where((code) => code.isNotEmpty && !_apiCardCache.containsKey(code))
        .toList(growable: false);

    if (missingCodes.isEmpty) return;

    await Future.wait(
      missingCodes.map((code) async {
        _apiCardCache[code] = await _opApi.findCardByCode(code);
      }),
    );
  }

  Future<void> _warmUpSeekerNames(Set<String> userIds) async {
    final missingUserIds = userIds
        .where((id) => !_seekerNameCache.containsKey(id))
        .toList(growable: false);

    if (missingUserIds.isEmpty) return;

    final response = await _client.rpc(
      'get_public_seller_profiles',
      params: {'user_ids': missingUserIds},
    );

    for (final raw in (response as List)) {
      final row = Map<String, dynamic>.from(raw);
      final id = (row['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      _seekerNameCache[id] = (row['name'] ?? '').toString().trim();
    }

    for (final id in missingUserIds) {
      _seekerNameCache.putIfAbsent(id, () => '');
    }
  }

  WantedCardListing _mapRowToListing(Map<String, dynamic> map) {
    final cardCode = (map['card_code'] ?? '').toString().trim().toUpperCase();
    final ownerUserId = (map['user_id'] ?? '').toString().trim();
    final apiCard = _apiCardCache[cardCode];

    String stored(String key) => (map[key] ?? '').toString();

    return WantedCardListing(
      id: map['id'].toString(),
      ownerUserId: ownerUserId,
      seekerName: _seekerNameCache[ownerUserId] ?? '',
      cardCode: cardCode,
      name: stored('name').isNotEmpty
          ? stored('name')
          : (apiCard?.name ?? cardCode),
      imageUrl: stored('image_url').isNotEmpty
          ? stored('image_url')
          : (apiCard?.image ?? ''),
      createdAtUtc:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      setName: stored('set_name').isNotEmpty
          ? stored('set_name')
          : (apiCard?.setName ?? ''),
      rarity: stored('rarity').isNotEmpty
          ? stored('rarity')
          : (apiCard?.rarity ?? ''),
      color: stored('color').isNotEmpty
          ? stored('color')
          : (apiCard?.color ?? ''),
      type: stored('type').isNotEmpty ? stored('type') : (apiCard?.type ?? ''),
      text: stored('text').isNotEmpty ? stored('text') : (apiCard?.text ?? ''),
      attribute: stored('attribute').isNotEmpty
          ? stored('attribute')
          : (apiCard?.attribute ?? ''),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      isPublic: (map['is_public'] as bool?) ?? false,
      isActive: (map['is_active'] as bool?) ?? true,
      contactInfo: stored('contact_info'),
      notes: stored('notes'),
    );
  }
}
