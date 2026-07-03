import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_listing.dart';
import '../models/op_card.dart';
import '../services/liga_one_piece_service.dart';
import '../services/op_api_service.dart';
import '../services/supabase_client_provider.dart';
import 'user_preferences_repository.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final opApi = ref.watch(opApiServiceProvider);
  final prefs = ref.watch(userPreferencesRepositoryProvider);
  final liga = ref.watch(ligaOnePieceServiceProvider);
  return MarketplaceRepository(client, opApi, prefs, liga);
});

class MarketplaceRepository {
  final SupabaseClient _client;
  final OpApiService _opApi;
  final UserPreferencesRepository _prefs;
  final LigaOnePieceService _liga;
  static const String _listingColumns =
      'id, user_id, card_code, quantity, is_favorite, is_public, share_code, '
      'created_at, image_url, name, set_name, rarity, color, type, text, '
      'attribute, sale_price_cents, sale_contact_info, sale_notes, '
      'sale_status, card_condition';
  static const String _dynamicPricingColumns =
      'sale_pricing_mode, sale_liga_percentage, sale_liga_rounding, '
      'sale_liga_base_price_cents, sale_liga_price_updated_at, '
      'sale_liga_price_source';
  static const String _publicListingColumns =
      'id, user_id, card_code, quantity, is_favorite, is_public, share_code, '
      'created_at, image_url, name, set_name, rarity, color, type, text, '
      'attribute, sale_price_cents, sale_notes, sale_status, card_condition';
  static const Duration _dynamicPriceMaxAge = Duration(hours: 24);
  final Map<String, OpCard?> _apiCardCache = {};
  final Map<String, String> _sellerNameCache = {};

  MarketplaceRepository(this._client, this._opApi, this._prefs, this._liga);

  Future<List<MarketplaceListing>> getMyListings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    return _fetchListings(userId: user.id, onlyPublic: false);
  }

  Future<List<MarketplaceListing>> getPublicListingsByUser(String userId) {
    return _fetchListings(
      userId: userId,
      onlyPublic: true,
      includeContactInfo: true,
    );
  }

  Future<List<MarketplaceListing>> getGlobalPublicListings() {
    return _fetchListings(onlyPublic: true, includeContactInfo: false);
  }

  Future<String> getPublicListingContact(String listingId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final response = await _client.rpc(
      'get_public_marketplace_listing_contact',
      params: {'listing_id': listingId},
    );

    return (response ?? '').toString();
  }

  Future<MarketplaceListing?> getPublicListingByShareCode(
    String shareCode,
  ) async {
    await _opApi.preload();

    final row = await _client
        .from('collection_items')
        .select(_listingColumns)
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
        .update({'is_public': true, 'sale_contact_info': whatsAppPhone})
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
    required String pricingMode,
    required double? ligaPercentage,
    required String ligaRounding,
    int? ligaBasePriceCents,
    String? ligaPriceSource,
  }) async {
    final whatsAppPhone = await _prefs.getCurrentWhatsAppPhone();

    final payload = <String, dynamic>{
      'sale_contact_info': whatsAppPhone,
      'sale_notes': notes.trim(),
      'sale_status': saleStatus,
      'card_condition': cardCondition,
      'sale_price_cents': priceInCents,
      'sale_pricing_mode': pricingMode,
      'sale_liga_percentage': ligaPercentage,
      'sale_liga_rounding': ligaRounding,
      'sale_liga_base_price_cents': ligaBasePriceCents,
      'sale_liga_price_updated_at':
          pricingMode == MarketplaceListing.ligaPercentagePricingMode
          ? DateTime.now().toUtc().toIso8601String()
          : null,
      'sale_liga_price_source': ligaPriceSource,
    };

    try {
      await _client.from('collection_items').update(payload).eq('id', id);
    } on PostgrestException catch (error) {
      if (!_looksLikeMissingDynamicPricingSchema(error)) rethrow;
      payload
        ..remove('sale_pricing_mode')
        ..remove('sale_liga_percentage')
        ..remove('sale_liga_rounding')
        ..remove('sale_liga_base_price_cents')
        ..remove('sale_liga_price_updated_at')
        ..remove('sale_liga_price_source');
      await _client.from('collection_items').update(payload).eq('id', id);
    }
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
    String? userId,
    required bool onlyPublic,
    bool includeContactInfo = true,
  }) async {
    await _opApi.preload();

    final selectColumns = includeContactInfo
        ? '$_listingColumns, $_dynamicPricingColumns'
        : '$_publicListingColumns, $_dynamicPricingColumns';

    var rows = await _selectListingRows(
      selectColumns: selectColumns,
      userId: userId,
      onlyPublic: onlyPublic,
    );

    rows = await _refreshDynamicPricesIfNeeded(rows);

    final uniqueCodes = <String>{};
    final uniqueUserIds = <String>{};
    for (final row in rows) {
      final cardCode = (row['card_code'] ?? '').toString().trim().toUpperCase();
      if (cardCode.isNotEmpty) {
        uniqueCodes.add(cardCode);
      }
      final userIdValue = (row['user_id'] ?? '').toString().trim();
      if (userIdValue.isNotEmpty) {
        uniqueUserIds.add(userIdValue);
      }
    }

    await Future.wait([
      _warmUpApiCards(uniqueCodes),
      _warmUpSellerNames(uniqueUserIds),
    ]);

    return rows.map(_mapRowToListing).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _selectListingRows({
    required String selectColumns,
    required String? userId,
    required bool onlyPublic,
  }) async {
    Future<List<Map<String, dynamic>>> run(String columns) async {
      var query = _client
          .from('collection_items')
          .select(columns)
          .eq('collection_type', 'forSale');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (onlyPublic) {
        query = query.eq('is_public', true);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
    }

    try {
      return await run(selectColumns);
    } on PostgrestException catch (error) {
      if (!_looksLikeMissingDynamicPricingSchema(error)) rethrow;
      return run(selectColumns.replaceAll(', $_dynamicPricingColumns', ''));
    }
  }

  Future<List<Map<String, dynamic>>> _refreshDynamicPricesIfNeeded(
    List<Map<String, dynamic>> rows,
  ) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return rows;

    var changed = false;
    final refreshedRows = <Map<String, dynamic>>[];

    for (final row in rows) {
      final nextRow = Map<String, dynamic>.from(row);
      final ownerUserId = (row['user_id'] ?? '').toString();
      final pricingMode = (row['sale_pricing_mode'] ?? '').toString();
      final updatedAt = DateTime.tryParse(
        (row['sale_liga_price_updated_at'] ?? '').toString(),
      );
      final isStale =
          updatedAt == null ||
          DateTime.now().toUtc().difference(updatedAt.toUtc()) >
              _dynamicPriceMaxAge;

      if (ownerUserId == currentUserId &&
          pricingMode == MarketplaceListing.ligaPercentagePricingMode &&
          isStale) {
        final refreshed = await _refreshDynamicPriceForRow(nextRow);
        if (refreshed) changed = true;
      }

      refreshedRows.add(nextRow);
    }

    return changed ? refreshedRows : rows;
  }

  Future<bool> _refreshDynamicPriceForRow(Map<String, dynamic> row) async {
    final percentage = (row['sale_liga_percentage'] as num?)?.toDouble();
    if (percentage == null) return false;

    final cardCode = (row['card_code'] ?? '').toString().trim().toUpperCase();
    final cardName = (row['name'] ?? '').toString().trim();
    if (cardCode.isEmpty) return false;

    final snapshot =
        await _liga.fetchCachedPublicCardSnapshotForCardCode(cardCode) ??
        await _liga.fetchPublicCardSnapshotForCard(
          cardName: cardName.isEmpty ? cardCode : cardName,
          cardCode: cardCode,
        );
    final basePrice = snapshot.minimumPrice ?? snapshot.lowestListing?.price;
    if (basePrice == null || basePrice <= 0) return false;

    final rounding =
        (row['sale_liga_rounding'] ?? MarketplaceListing.noRounding).toString();
    final priceInCents = calculateLigaPercentagePriceInCents(
      basePrice: basePrice,
      percentage: percentage,
      rounding: rounding,
    );
    final basePriceInCents = (basePrice * 100).round();
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    final source = snapshot.sourceUrl;

    final payload = <String, dynamic>{
      'sale_price_cents': priceInCents,
      'sale_liga_base_price_cents': basePriceInCents,
      'sale_liga_price_updated_at': updatedAt,
      'sale_liga_price_source': source,
    };

    try {
      await _client
          .from('collection_items')
          .update(payload)
          .eq('id', row['id']);
    } on PostgrestException catch (error) {
      if (!_looksLikeMissingDynamicPricingSchema(error)) rethrow;
      return false;
    }

    row
      ..['sale_price_cents'] = priceInCents
      ..['sale_liga_base_price_cents'] = basePriceInCents
      ..['sale_liga_price_updated_at'] = updatedAt
      ..['sale_liga_price_source'] = source;
    return true;
  }

  Future<void> _warmUpApiCards(Set<String> cardCodes) async {
    final missingCodes = cardCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty && !_apiCardCache.containsKey(code))
        .toList(growable: false);

    if (missingCodes.isEmpty) return;

    await Future.wait(
      missingCodes.map((code) async {
        _apiCardCache[code] = await _opApi.findCardByCode(code);
      }),
    );
  }

  Future<void> _warmUpSellerNames(Set<String> userIds) async {
    final missingUserIds = userIds
        .where((id) => !_sellerNameCache.containsKey(id))
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
      _sellerNameCache[id] = (row['name'] ?? '').toString().trim();
    }

    for (final id in missingUserIds) {
      _sellerNameCache.putIfAbsent(id, () => '');
    }
  }

  MarketplaceListing _mapRowToListing(Map<String, dynamic> map) {
    final cardCode = (map['card_code'] ?? '').toString().trim().toUpperCase();
    final ownerUserId = (map['user_id'] ?? '').toString().trim();
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
      ownerUserId: ownerUserId,
      sellerName: _sellerNameCache[ownerUserId] ?? '',
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
      cardCondition: (map['card_condition'] ?? MarketplaceListing.mintCondition)
          .toString(),
      pricingMode:
          (map['sale_pricing_mode'] ?? MarketplaceListing.manualPricingMode)
              .toString(),
      ligaPercentage: (map['sale_liga_percentage'] as num?)?.toDouble(),
      ligaRounding: (map['sale_liga_rounding'] ?? MarketplaceListing.noRounding)
          .toString(),
      ligaBasePriceCents: (map['sale_liga_base_price_cents'] as num?)?.toInt(),
      ligaPriceUpdatedAt: DateTime.tryParse(
        (map['sale_liga_price_updated_at'] ?? '').toString(),
      ),
      ligaPriceSource: (map['sale_liga_price_source'] ?? '').toString(),
    );
  }

  bool _looksLikeMissingDynamicPricingSchema(PostgrestException error) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains('sale_pricing_mode') ||
        message.contains('sale_liga_percentage') ||
        message.contains('sale_liga_rounding') ||
        message.contains('sale_liga_base_price_cents') ||
        message.contains('sale_liga_price_updated_at') ||
        message.contains('sale_liga_price_source');
  }

  static int calculateLigaPercentagePriceInCents({
    required double basePrice,
    required double percentage,
    required String rounding,
  }) {
    final rawCents = (basePrice * (1 + (percentage / 100)) * 100).round();
    if (rawCents <= 0) return 0;

    return switch (rounding) {
      MarketplaceListing.roundUp =>
        rawCents % 100 == 0 ? rawCents : ((rawCents ~/ 100) + 1) * 100,
      MarketplaceListing.roundDown => (rawCents ~/ 100) * 100,
      _ => rawCents,
    };
  }
}
