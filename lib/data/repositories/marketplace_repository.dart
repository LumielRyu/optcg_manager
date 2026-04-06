import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_listing.dart';
import '../models/op_card.dart';
import '../services/op_api_service.dart';
import '../services/supabase_client_provider.dart';
import 'user_preferences_repository.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final opApi = ref.watch(opApiServiceProvider);
  final prefs = ref.watch(userPreferencesRepositoryProvider);
  return MarketplaceRepository(client, opApi, prefs);
});

class MarketplaceRepository {
  final SupabaseClient _client;
  final OpApiService _opApi;
  final UserPreferencesRepository _prefs;
  final Map<String, OpCard?> _apiCardCache = {};

  MarketplaceRepository(this._client, this._opApi, this._prefs);

  Future<List<MarketplaceListing>> getMyListings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    return _fetchListings(userId: user.id, onlyPublic: false);
  }

  Future<List<MarketplaceListing>> getPublicListingsByUser(String userId) {
    return _fetchListings(userId: userId, onlyPublic: true);
  }

  Future<MarketplaceListing?> getPublicListingByShareCode(
    String shareCode,
  ) async {
    await _opApi.preload();

    final row = await _client
        .from('collection_items')
        .select()
        .eq('share_code', shareCode)
        .eq('is_public', true)
        .eq('collection_type', 'forSale')
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final map = Map<String, dynamic>.from(row);
    final cardCode = (map['card_code'] ?? '').toString().trim().toUpperCase();

    if (!_apiCardCache.containsKey(cardCode)) {
      _apiCardCache[cardCode] = await _opApi.findCardByCode(cardCode);
    }

    return _mapRowToListing(map);
  }

  Future<void> enablePublicStoreSharingForUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usu\u00E1rio n\u00E3o autenticado.');
    }

    final whatsAppPhone = await _prefs.getCurrentWhatsAppPhone();

    await _client
        .from('collection_items')
        .update({
          'is_public': true,
          'sale_contact_info': whatsAppPhone,
        })
        .eq('user_id', user.id)
        .eq('collection_type', 'forSale');
  }

  Future<void> disablePublicStoreSharingForUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('collection_items')
        .update({'is_public': false})
        .eq('user_id', user.id)
        .eq('collection_type', 'forSale');
  }

  Future<void> updateListingDetails({
    required String id,
    required int? priceInCents,
    required String notes,
    required String saleStatus,
    required String cardCondition,
  }) async {
    final whatsAppPhone = await _prefs.getCurrentWhatsAppPhone();

    final payload = <String, dynamic>{
      'sale_contact_info': whatsAppPhone,
      'sale_notes': notes.trim(),
      'sale_status': saleStatus,
      'card_condition': cardCondition,
      'sale_price_cents': priceInCents,
    };

    await _client.from('collection_items').update(payload).eq('id', id);
  }

  Future<void> updateQuantity({
    required String id,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await deleteListing(id);
      return;
    }

    await _client
        .from('collection_items')
        .update({'quantity': quantity})
        .eq('id', id);
  }

  Future<void> deleteListing(String id) async {
    await _client.from('collection_items').delete().eq('id', id);
  }

  Future<List<MarketplaceListing>> _fetchListings({
    required String userId,
    required bool onlyPublic,
  }) async {
    await _opApi.preload();

    var query = _client
        .from('collection_items')
        .select()
        .eq('user_id', userId)
        .eq('collection_type', 'forSale');

    if (onlyPublic) {
      query = query.eq('is_public', true);
    }

    final response = await query.order('created_at', ascending: false);
    final rows = (response as List)
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();

    final uniqueCodes = <String>{};
    for (final row in rows) {
      final cardCode = (row['card_code'] ?? '').toString().trim().toUpperCase();
      if (cardCode.isNotEmpty) {
        uniqueCodes.add(cardCode);
      }
    }

    await _warmUpApiCards(uniqueCodes);

    return rows.map(_mapRowToListing).toList(growable: false);
  }

  Future<void> _warmUpApiCards(Set<String> cardCodes) async {
    for (final code in cardCodes) {
      if (_apiCardCache.containsKey(code)) continue;
      _apiCardCache[code] = await _opApi.findCardByCode(code);
    }
  }

  MarketplaceListing _mapRowToListing(Map<String, dynamic> map) {
    final cardCode = (map['card_code'] ?? '').toString().trim().toUpperCase();
    final apiCard = _apiCardCache[cardCode];

    final storedImageUrl = (map['image_url'] ?? '').toString();
    final storedName = (map['name'] ?? '').toString();
    final storedSetName = (map['set_name'] ?? '').toString();
    final storedRarity = (map['rarity'] ?? '').toString();
    final storedColor = (map['color'] ?? '').toString();
    final storedType = (map['type'] ?? '').toString();
    final storedText = (map['text'] ?? '').toString();
    final storedAttribute = (map['attribute'] ?? '').toString();

    return MarketplaceListing(
      id: map['id'].toString(),
      cardCode: cardCode,
      name: storedName.isNotEmpty ? storedName : (apiCard?.name ?? cardCode),
      imageUrl: storedImageUrl.isNotEmpty
          ? storedImageUrl
          : (apiCard?.image ?? ''),
      dateAddedUtc:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      setName: storedSetName.isNotEmpty
          ? storedSetName
          : (apiCard?.setName ?? ''),
      rarity: storedRarity.isNotEmpty ? storedRarity : (apiCard?.rarity ?? ''),
      color: storedColor.isNotEmpty ? storedColor : (apiCard?.color ?? ''),
      type: storedType.isNotEmpty ? storedType : (apiCard?.type ?? ''),
      text: storedText.isNotEmpty ? storedText : (apiCard?.text ?? ''),
      attribute: storedAttribute.isNotEmpty
          ? storedAttribute
          : (apiCard?.attribute ?? ''),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      isFavorite: (map['is_favorite'] as bool?) ?? false,
      isPublic: (map['is_public'] as bool?) ?? false,
      shareCode: map['share_code']?.toString(),
      priceInCents: (map['sale_price_cents'] as num?)?.toInt(),
      contactInfo: (map['sale_contact_info'] ?? '').toString(),
      notes: (map['sale_notes'] ?? '').toString(),
      saleStatus: (map['sale_status'] ?? MarketplaceListing.activeStatus)
          .toString(),
      cardCondition:
          (map['card_condition'] ?? MarketplaceListing.mintCondition)
              .toString(),
    );
  }
}
