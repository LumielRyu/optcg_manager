import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/collection_types.dart';
import '../local/hive_boxes.dart';
import '../models/card_record.dart';
import '../models/op_card.dart';
import '../services/op_api_service.dart';
import '../services/supabase_client_provider.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final opApi = ref.watch(opApiServiceProvider);
  return CollectionRepository(client, opApi);
});

class DeckShareInfo {
  final bool isPublic;
  final String? shareCode;

  const DeckShareInfo({required this.isPublic, required this.shareCode});
}

class SharedDeckData {
  final String deckName;
  final String shareCode;
  final List<CardRecord> items;

  const SharedDeckData({
    required this.deckName,
    required this.shareCode,
    required this.items,
  });
}

class SaleCardShareInfo {
  final bool isPublic;
  final String? shareCode;

  const SaleCardShareInfo({required this.isPublic, required this.shareCode});
}

class SharedSaleCardData {
  final String shareCode;
  final CardRecord item;

  const SharedSaleCardData({required this.shareCode, required this.item});
}

class CollectionRepository {
  final SupabaseClient _client;
  final OpApiService _opApi;
  static const String _collectionItemColumns =
      'id, card_code, quantity, is_favorite, collection_type, created_at, '
      'image_url, name, set_name, rarity, color, type, text, attribute, '
      'is_public, share_code, sale_price_cents, sale_contact_info, sale_notes, '
      'sale_status, card_condition';
  static const String _deckItemColumns =
      'id, card_code, quantity, is_favorite, created_at, image_url, name, '
      'set_name, rarity, color, type, text, attribute';

  CollectionRepository(this._client, this._opApi);

  Box<CardRecord> get _box => Hive.box<CardRecord>(HiveBoxes.collection);

  List<CardRecord> _cache = const [];
  final Map<String, OpCard?> _apiCardCache = {};

  List<CardRecord> getAll() {
    final list = [..._cache];
    list.sort((a, b) => b.dateAddedUtc.compareTo(a.dateAddedUtc));
    return list;
  }

  Future<void> refreshAll() async {
    await _migrateLegacyLocalCollectionIfNeeded();
    await _migrateLegacyLocalDecksIfNeeded();
    await _opApi.preload();

    final user = _client.auth.currentUser;
    if (user == null) {
      _cache = [];
      return;
    }

    final collectionFuture = _client
        .from('collection_items')
        .select(_collectionItemColumns)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final decksFuture = _client
        .from('decks')
        .select(
          'id, name, created_at, is_public, share_code, deck_items($_deckItemColumns)',
        )
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final results = await Future.wait([collectionFuture, decksFuture]);

    final collectionResponse = results[0] as List;
    final decksResponse = results[1] as List;

    final uniqueCodes = <String>{};

    for (final raw in collectionResponse) {
      final map = Map<String, dynamic>.from(raw);
      final cardCode = (map['card_code'] ?? '').toString().trim().toUpperCase();
      if (cardCode.isNotEmpty) {
        uniqueCodes.add(cardCode);
      }
    }

    for (final rawDeck in decksResponse) {
      final deckMap = Map<String, dynamic>.from(rawDeck);
      final deckItemsRaw = (deckMap['deck_items'] as List?) ?? const [];

      for (final rawItem in deckItemsRaw) {
        final itemMap = Map<String, dynamic>.from(rawItem);
        final cardCode = (itemMap['card_code'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        if (cardCode.isNotEmpty) {
          uniqueCodes.add(cardCode);
        }
      }
    }

    await _warmUpApiCards(uniqueCodes);

    final all = <CardRecord>[];

    for (final raw in collectionResponse) {
      final map = Map<String, dynamic>.from(raw);
      final cardCode = (map['card_code'] ?? '').toString().trim().toUpperCase();
      final storedImageUrl = (map['image_url'] ?? '').toString();
      final storedName = (map['name'] ?? '').toString();
      final storedSetName = (map['set_name'] ?? '').toString();
      final storedRarity = (map['rarity'] ?? '').toString();
      final storedColor = (map['color'] ?? '').toString();
      final storedType = (map['type'] ?? '').toString();
      final storedText = (map['text'] ?? '').toString();
      final storedAttribute = (map['attribute'] ?? '').toString();
      final apiCard = _apiCardCache[cardCode];

      all.add(
        CardRecord(
          id: map['id'].toString(),
          cardCode: cardCode,
          name: storedName.isNotEmpty
              ? storedName
              : (apiCard?.name ?? cardCode),
          imageUrl: storedImageUrl.isNotEmpty
              ? storedImageUrl
              : (apiCard?.image ?? ''),
          dateAddedUtc:
              DateTime.tryParse((map['created_at'] ?? '').toString()) ??
              DateTime.now(),
          setName: storedSetName.isNotEmpty
              ? storedSetName
              : (apiCard?.setName ?? ''),
          rarity: storedRarity.isNotEmpty
              ? storedRarity
              : (apiCard?.rarity ?? ''),
          color: storedColor.isNotEmpty ? storedColor : (apiCard?.color ?? ''),
          type: storedType.isNotEmpty ? storedType : (apiCard?.type ?? ''),
          text: storedText.isNotEmpty ? storedText : (apiCard?.text ?? ''),
          attribute: storedAttribute.isNotEmpty
              ? storedAttribute
              : (apiCard?.attribute ?? ''),
          quantity: (map['quantity'] as num?)?.toInt() ?? 1,
          collectionType: (map['collection_type'] ?? CollectionTypes.owned)
              .toString(),
          deckName: null,
          isFavorite: (map['is_favorite'] as bool?) ?? false,
        ),
      );
    }

    for (final rawDeck in decksResponse) {
      final deckMap = Map<String, dynamic>.from(rawDeck);
      final deckName = (deckMap['name'] ?? '').toString();
      final deckItemsRaw = (deckMap['deck_items'] as List?) ?? const [];

      for (final rawItem in deckItemsRaw) {
        final itemMap = Map<String, dynamic>.from(rawItem);
        final cardCode = (itemMap['card_code'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        final storedImageUrl = (itemMap['image_url'] ?? '').toString();
        final storedName = (itemMap['name'] ?? '').toString();
        final storedSetName = (itemMap['set_name'] ?? '').toString();
        final storedRarity = (itemMap['rarity'] ?? '').toString();
        final storedColor = (itemMap['color'] ?? '').toString();
        final storedType = (itemMap['type'] ?? '').toString();
        final storedText = (itemMap['text'] ?? '').toString();
        final storedAttribute = (itemMap['attribute'] ?? '').toString();
        final apiCard = _apiCardCache[cardCode];

        all.add(
          CardRecord(
            id: itemMap['id'].toString(),
            cardCode: cardCode,
            name: storedName.isNotEmpty
                ? storedName
                : (apiCard?.name ?? cardCode),
            imageUrl: storedImageUrl.isNotEmpty
                ? storedImageUrl
                : (apiCard?.image ?? ''),
            dateAddedUtc:
                DateTime.tryParse((itemMap['created_at'] ?? '').toString()) ??
                DateTime.now(),
            setName: storedSetName.isNotEmpty
                ? storedSetName
                : (apiCard?.setName ?? ''),
            rarity: storedRarity.isNotEmpty
                ? storedRarity
                : (apiCard?.rarity ?? ''),
            color: storedColor.isNotEmpty
                ? storedColor
                : (apiCard?.color ?? ''),
            type: storedType.isNotEmpty ? storedType : (apiCard?.type ?? ''),
            text: storedText.isNotEmpty ? storedText : (apiCard?.text ?? ''),
            attribute: storedAttribute.isNotEmpty
                ? storedAttribute
                : (apiCard?.attribute ?? ''),
            quantity: (itemMap['quantity'] as num?)?.toInt() ?? 1,
            collectionType: CollectionTypes.deck,
            deckName: deckName,
            isFavorite: (itemMap['is_favorite'] as bool?) ?? false,
          ),
        );
      }
    }

    _cache = all;
  }

  Future<void> upsert(CardRecord record) async {
    await _upsertInternal(record);
    await refreshAll();
  }

  Future<void> upsertMany(List<CardRecord> records) async {
    if (records.isEmpty) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final enrichedRecords = await _enrichRecords(records);
    final deckIdsByName = <String, String>{};

    final collectionUpserts = <Map<String, dynamic>>[];
    final collectionInserts = <Map<String, dynamic>>[];
    final deckUpserts = <Map<String, dynamic>>[];
    final deckInserts = <Map<String, dynamic>>[];

    for (final record in enrichedRecords) {
      if (record.collectionType == CollectionTypes.deck) {
        final normalizedDeckName = (record.deckName ?? '').trim();
        if (normalizedDeckName.isEmpty) {
          throw Exception('Deck sem nome.');
        }

        final deckId =
            deckIdsByName[normalizedDeckName] ??
            await _ensureDeck(userId: user.id, deckName: normalizedDeckName);
        deckIdsByName[normalizedDeckName] = deckId;

        final payload = _buildDeckItemPayload(record, deckId);
        if (_isValidUuid(record.id)) {
          deckUpserts.add({'id': record.id, ...payload});
        } else {
          deckInserts.add(payload);
        }
        continue;
      }

      final payload = _buildCollectionItemPayload(record, user.id);
      if (_isValidUuid(record.id)) {
        collectionUpserts.add({'id': record.id, ...payload});
      } else {
        collectionInserts.add(payload);
      }
    }

    if (collectionUpserts.isNotEmpty) {
      await _client.from('collection_items').upsert(collectionUpserts);
    }

    if (collectionInserts.isNotEmpty) {
      await _client.from('collection_items').insert(collectionInserts);
    }

    if (deckUpserts.isNotEmpty) {
      await _client.from('deck_items').upsert(deckUpserts);
    }

    if (deckInserts.isNotEmpty) {
      await _client.from('deck_items').insert(deckInserts);
    }

    await refreshAll();
  }

  Future<void> _upsertInternal(CardRecord record) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final enrichedRecord = await _enrichRecord(record);

    if (enrichedRecord.collectionType == CollectionTypes.deck) {
      final normalizedDeckName = (enrichedRecord.deckName ?? '').trim();
      if (normalizedDeckName.isEmpty) {
        throw Exception('Deck sem nome.');
      }

      final deckId = await _ensureDeck(
        userId: user.id,
        deckName: normalizedDeckName,
      );

      final payload = _buildDeckItemPayload(enrichedRecord, deckId);

      if (_isValidUuid(enrichedRecord.id)) {
        await _client.from('deck_items').upsert({
          'id': enrichedRecord.id,
          ...payload,
        });
      } else {
        await _client.from('deck_items').insert(payload);
      }

      return;
    }

    final payload = _buildCollectionItemPayload(enrichedRecord, user.id);

    if (_isValidUuid(enrichedRecord.id)) {
      await _client.from('collection_items').upsert({
        'id': enrichedRecord.id,
        ...payload,
      });
    } else {
      await _client.from('collection_items').insert(payload);
    }
  }

  Future<void> delete(String id) async {
    final existing = _cache.cast<CardRecord?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );

    if (existing == null) return;

    if (existing.collectionType == CollectionTypes.deck) {
      if (_isValidUuid(id)) {
        await _client.from('deck_items').delete().eq('id', id);
        await _cleanupEmptyDeck(existing.deckName);
      }
      await refreshAll();
      return;
    }

    if (_isValidUuid(id)) {
      await _client.from('collection_items').delete().eq('id', id);
    }

    await refreshAll();
  }

  Future<void> deleteManyByIds(List<String> ids) async {
    if (ids.isEmpty) return;

    final collectionIds = <String>[];
    final deckItemIds = <String>[];
    final affectedDeckNames = <String>{};

    for (final id in ids) {
      final item = _cache.cast<CardRecord?>().firstWhere(
        (e) => e?.id == id,
        orElse: () => null,
      );

      if (item == null) continue;

      if (item.collectionType == CollectionTypes.deck) {
        if (_isValidUuid(id)) {
          deckItemIds.add(id);
          if ((item.deckName ?? '').trim().isNotEmpty) {
            affectedDeckNames.add(item.deckName!.trim());
          }
        }
      } else if (_isValidUuid(id)) {
        collectionIds.add(id);
      }
    }

    if (collectionIds.isNotEmpty) {
      await _client
          .from('collection_items')
          .delete()
          .inFilter('id', collectionIds);
    }

    if (deckItemIds.isNotEmpty) {
      await _client.from('deck_items').delete().inFilter('id', deckItemIds);
    }

    for (final deckName in affectedDeckNames) {
      await _cleanupEmptyDeck(deckName);
    }

    await refreshAll();
  }

  Future<DeckShareInfo?> getDeckShareInfo(String deckName) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('decks')
        .select('is_public, share_code')
        .eq('user_id', user.id)
        .eq('name', deckName.trim())
        .maybeSingle();

    if (row == null) return null;

    return DeckShareInfo(
      isPublic: (row['is_public'] as bool?) ?? false,
      shareCode: row['share_code']?.toString(),
    );
  }

  Future<String> enableDeckSharing(String deckName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final row = await _client
        .from('decks')
        .select('id, share_code')
        .eq('user_id', user.id)
        .eq('name', deckName.trim())
        .maybeSingle();

    if (row == null) {
      throw Exception('Deck não encontrado.');
    }

    final deckId = row['id'].toString();
    final shareCode = (row['share_code']?.toString().trim().isNotEmpty ?? false)
        ? row['share_code'].toString()
        : _generateShareCode();

    await _client
        .from('decks')
        .update({'is_public': true, 'share_code': shareCode})
        .eq('id', deckId);

    return shareCode;
  }

  Future<void> disableDeckSharing(String deckName) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('decks')
        .update({'is_public': false})
        .eq('user_id', user.id)
        .eq('name', deckName.trim());
  }

  Future<SharedDeckData?> getSharedDeck(String shareCode) async {
    await _opApi.preload();

    final row = await _client
        .from('decks')
        .select(
          'name, share_code, deck_items(id, card_code, quantity, is_favorite, created_at, image_url, name, set_name, rarity, color, type, text, attribute)',
        )
        .eq('share_code', shareCode)
        .eq('is_public', true)
        .maybeSingle();

    if (row == null) return null;

    final deckName = (row['name'] ?? '').toString();
    final itemsRaw = (row['deck_items'] as List?) ?? const [];
    final items = <CardRecord>[];

    final uniqueCodes = <String>{};
    for (final rawItem in itemsRaw) {
      final itemMap = Map<String, dynamic>.from(rawItem);
      final cardCode = (itemMap['card_code'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (cardCode.isNotEmpty) {
        uniqueCodes.add(cardCode);
      }
    }

    await _warmUpApiCards(uniqueCodes);

    for (final rawItem in itemsRaw) {
      final itemMap = Map<String, dynamic>.from(rawItem);
      final cardCode = (itemMap['card_code'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final storedImageUrl = (itemMap['image_url'] ?? '').toString();
      final storedName = (itemMap['name'] ?? '').toString();
      final storedSetName = (itemMap['set_name'] ?? '').toString();
      final storedRarity = (itemMap['rarity'] ?? '').toString();
      final storedColor = (itemMap['color'] ?? '').toString();
      final storedType = (itemMap['type'] ?? '').toString();
      final storedText = (itemMap['text'] ?? '').toString();
      final storedAttribute = (itemMap['attribute'] ?? '').toString();
      final apiCard = _apiCardCache[cardCode];

      items.add(
        CardRecord(
          id: itemMap['id'].toString(),
          cardCode: cardCode,
          name: storedName.isNotEmpty
              ? storedName
              : (apiCard?.name ?? cardCode),
          imageUrl: storedImageUrl.isNotEmpty
              ? storedImageUrl
              : (apiCard?.image ?? ''),
          dateAddedUtc:
              DateTime.tryParse((itemMap['created_at'] ?? '').toString()) ??
              DateTime.now(),
          setName: storedSetName.isNotEmpty
              ? storedSetName
              : (apiCard?.setName ?? ''),
          rarity: storedRarity.isNotEmpty
              ? storedRarity
              : (apiCard?.rarity ?? ''),
          color: storedColor.isNotEmpty ? storedColor : (apiCard?.color ?? ''),
          type: storedType.isNotEmpty ? storedType : (apiCard?.type ?? ''),
          text: storedText.isNotEmpty ? storedText : (apiCard?.text ?? ''),
          attribute: storedAttribute.isNotEmpty
              ? storedAttribute
              : (apiCard?.attribute ?? ''),
          quantity: (itemMap['quantity'] as num?)?.toInt() ?? 1,
          collectionType: CollectionTypes.deck,
          deckName: deckName,
          isFavorite: (itemMap['is_favorite'] as bool?) ?? false,
        ),
      );
    }

    return SharedDeckData(
      deckName: deckName,
      shareCode: (row['share_code'] ?? shareCode).toString(),
      items: items,
    );
  }

  Future<SaleCardShareInfo?> getSaleCardShareInfo(String itemId) async {
    final user = _client.auth.currentUser;
    if (user == null || !_isValidUuid(itemId)) return null;

    final row = await _client
        .from('collection_items')
        .select('is_public, share_code')
        .eq('user_id', user.id)
        .eq('id', itemId)
        .eq('collection_type', CollectionTypes.forSale)
        .maybeSingle();

    if (row == null) return null;

    return SaleCardShareInfo(
      isPublic: (row['is_public'] as bool?) ?? false,
      shareCode: row['share_code']?.toString(),
    );
  }

  Future<String> enableSaleCardSharing(String itemId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    if (!_isValidUuid(itemId)) {
      throw Exception('Item inválido para compartilhamento.');
    }

    final row = await _client
        .from('collection_items')
        .select('id, share_code')
        .eq('user_id', user.id)
        .eq('id', itemId)
        .eq('collection_type', CollectionTypes.forSale)
        .maybeSingle();

    if (row == null) {
      throw Exception('Carta à venda não encontrada.');
    }

    final shareCode = (row['share_code']?.toString().trim().isNotEmpty ?? false)
        ? row['share_code'].toString()
        : _generateShareCode();

    await _client
        .from('collection_items')
        .update({'is_public': true, 'share_code': shareCode})
        .eq('id', itemId);

    await refreshAll();
    return shareCode;
  }

  Future<void> enablePublicStoreSharingForUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    await _client
        .from('collection_items')
        .update({'is_public': true})
        .eq('user_id', user.id)
        .eq('collection_type', CollectionTypes.forSale);

    await refreshAll();
  }

  Future<void> disableSaleSharingForUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('collection_items')
        .update({'is_public': false})
        .eq('user_id', user.id)
        .eq('collection_type', CollectionTypes.forSale);

    await refreshAll();
  }

  Future<List<CardRecord>> getPublicSaleCardsByUser(String userId) async {
    await _opApi.preload();

    final response = await _client
        .from('collection_items')
        .select(_collectionItemColumns)
        .eq('user_id', userId)
        .eq('is_public', true)
        .eq('collection_type', CollectionTypes.forSale)
        .order('created_at', ascending: false);

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

    final items = <CardRecord>[];

    for (final map in rows) {
      final cardCode = (map['card_code'] ?? '').toString().trim().toUpperCase();
      final storedImageUrl = (map['image_url'] ?? '').toString();
      final storedName = (map['name'] ?? '').toString();
      final storedSetName = (map['set_name'] ?? '').toString();
      final storedRarity = (map['rarity'] ?? '').toString();
      final storedColor = (map['color'] ?? '').toString();
      final storedType = (map['type'] ?? '').toString();
      final storedText = (map['text'] ?? '').toString();
      final storedAttribute = (map['attribute'] ?? '').toString();
      final apiCard = _apiCardCache[cardCode];

      items.add(
        CardRecord(
          id: map['id'].toString(),
          cardCode: cardCode,
          name: storedName.isNotEmpty
              ? storedName
              : (apiCard?.name ?? cardCode),
          imageUrl: storedImageUrl.isNotEmpty
              ? storedImageUrl
              : (apiCard?.image ?? ''),
          dateAddedUtc:
              DateTime.tryParse((map['created_at'] ?? '').toString()) ??
              DateTime.now(),
          setName: storedSetName.isNotEmpty
              ? storedSetName
              : (apiCard?.setName ?? ''),
          rarity: storedRarity.isNotEmpty
              ? storedRarity
              : (apiCard?.rarity ?? ''),
          color: storedColor.isNotEmpty ? storedColor : (apiCard?.color ?? ''),
          type: storedType.isNotEmpty ? storedType : (apiCard?.type ?? ''),
          text: storedText.isNotEmpty ? storedText : (apiCard?.text ?? ''),
          attribute: storedAttribute.isNotEmpty
              ? storedAttribute
              : (apiCard?.attribute ?? ''),
          quantity: (map['quantity'] as num?)?.toInt() ?? 1,
          collectionType: CollectionTypes.forSale,
          deckName: null,
          isFavorite: (map['is_favorite'] as bool?) ?? false,
        ),
      );
    }

    return items;
  }

  Future<void> disableSaleCardSharing(String itemId) async {
    final user = _client.auth.currentUser;
    if (user == null || !_isValidUuid(itemId)) return;

    await _client
        .from('collection_items')
        .update({'is_public': false})
        .eq('user_id', user.id)
        .eq('id', itemId);

    await refreshAll();
  }

  Future<SharedSaleCardData?> getSharedSaleCard(String shareCode) async {
    await _opApi.preload();

    final row = await _client
        .from('collection_items')
        .select(_collectionItemColumns)
        .eq('share_code', shareCode)
        .eq('is_public', true)
        .eq('collection_type', CollectionTypes.forSale)
        .maybeSingle();

    if (row == null) return null;

    final cardCode = (row['card_code'] ?? '').toString().trim().toUpperCase();
    await _warmUpApiCards({cardCode});

    final storedImageUrl = (row['image_url'] ?? '').toString();
    final storedName = (row['name'] ?? '').toString();
    final storedSetName = (row['set_name'] ?? '').toString();
    final storedRarity = (row['rarity'] ?? '').toString();
    final storedColor = (row['color'] ?? '').toString();
    final storedType = (row['type'] ?? '').toString();
    final storedText = (row['text'] ?? '').toString();
    final storedAttribute = (row['attribute'] ?? '').toString();
    final apiCard = _apiCardCache[cardCode];

    final item = CardRecord(
      id: row['id'].toString(),
      cardCode: cardCode,
      name: storedName.isNotEmpty ? storedName : (apiCard?.name ?? cardCode),
      imageUrl: storedImageUrl.isNotEmpty
          ? storedImageUrl
          : (apiCard?.image ?? ''),
      dateAddedUtc:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ??
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
      quantity: (row['quantity'] as num?)?.toInt() ?? 1,
      collectionType: CollectionTypes.forSale,
      deckName: null,
      isFavorite: (row['is_favorite'] as bool?) ?? false,
    );

    return SharedSaleCardData(
      shareCode: (row['share_code'] ?? shareCode).toString(),
      item: item,
    );
  }

  CardRecord? findById(String id) {
    try {
      return _cache.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  CardRecord? findByCode(String cardCode) {
    try {
      return _cache.firstWhere(
        (item) => item.cardCode.toUpperCase() == cardCode.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  CardRecord? findByCodeAndCollection({
    required String cardCode,
    required String collectionType,
    String? deckName,
    String? imageUrl,
  }) {
    try {
      return _cache.firstWhere(
        (item) =>
            item.cardCode.toUpperCase() == cardCode.toUpperCase() &&
            item.collectionType == collectionType &&
            (item.deckName ?? '') == (deckName ?? '') &&
            ((imageUrl == null || imageUrl.trim().isEmpty)
                ? true
                : item.imageUrl.trim() == imageUrl.trim()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> seedIfEmpty() async {}

  Future<void> _migrateLegacyLocalCollectionIfNeeded() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final legacyItems = _box.values
        .where((item) => item.collectionType != CollectionTypes.deck)
        .toList();

    if (legacyItems.isEmpty) return;

    for (final item in legacyItems) {
      final payload = {
        'user_id': user.id,
        'card_code': item.cardCode,
        'quantity': item.quantity,
        'collection_type': item.collectionType,
        'is_favorite': item.isFavorite,
        'image_url': item.imageUrl,
        'name': item.name,
        'set_name': item.setName,
        'rarity': item.rarity,
        'color': item.color,
        'type': item.type,
        'text': item.text,
        'attribute': item.attribute,
      };

      if (_isValidUuid(item.id)) {
        await _client.from('collection_items').upsert({
          'id': item.id,
          ...payload,
        });
      } else {
        await _client.from('collection_items').insert(payload);
      }

      await _box.delete(item.id);
    }
  }

  Future<void> _migrateLegacyLocalDecksIfNeeded() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final legacyDeckItems = _box.values
        .where((item) => item.collectionType == CollectionTypes.deck)
        .toList();

    if (legacyDeckItems.isEmpty) return;

    for (final item in legacyDeckItems) {
      final normalizedDeckName = (item.deckName ?? '').trim();
      if (normalizedDeckName.isEmpty) {
        await _box.delete(item.id);
        continue;
      }

      final deckId = await _ensureDeck(
        userId: user.id,
        deckName: normalizedDeckName,
      );

      final payload = {
        'deck_id': deckId,
        'card_code': item.cardCode,
        'quantity': item.quantity,
        'is_favorite': item.isFavorite,
        'image_url': item.imageUrl,
        'name': item.name,
        'set_name': item.setName,
        'rarity': item.rarity,
        'color': item.color,
        'type': item.type,
        'text': item.text,
        'attribute': item.attribute,
      };

      if (_isValidUuid(item.id)) {
        await _client.from('deck_items').upsert({'id': item.id, ...payload});
      } else {
        await _client.from('deck_items').insert(payload);
      }

      await _box.delete(item.id);
    }
  }

  Future<String> _ensureDeck({
    required String userId,
    required String deckName,
  }) async {
    final existing = await _client
        .from('decks')
        .select('id')
        .eq('user_id', userId)
        .eq('name', deckName)
        .maybeSingle();

    if (existing != null) {
      return existing['id'].toString();
    }

    final inserted = await _client
        .from('decks')
        .insert({'user_id': userId, 'name': deckName})
        .select('id')
        .single();

    return inserted['id'].toString();
  }

  Future<void> _cleanupEmptyDeck(String? deckName) async {
    final user = _client.auth.currentUser;
    final normalizedDeckName = (deckName ?? '').trim();

    if (user == null || normalizedDeckName.isEmpty) return;

    final deck = await _client
        .from('decks')
        .select('id')
        .eq('user_id', user.id)
        .eq('name', normalizedDeckName)
        .maybeSingle();

    if (deck == null) return;

    final deckId = deck['id'].toString();

    final items = await _client
        .from('deck_items')
        .select('id')
        .eq('deck_id', deckId);

    if ((items as List).isEmpty) {
      await _client.from('decks').delete().eq('id', deckId);
    }
  }

  Future<void> _warmUpApiCards(Set<String> codes) async {
    final missingCodes = codes
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty && !_apiCardCache.containsKey(e))
        .toList();

    if (missingCodes.isEmpty) return;

    await Future.wait(
      missingCodes.map((code) async {
        try {
          final apiCard = await _opApi.findCardByCode(code);
          _apiCardCache[code] = apiCard;
        } catch (_) {
          _apiCardCache[code] = null;
        }
      }),
    );
  }

  Future<List<CardRecord>> _enrichRecords(List<CardRecord> records) async {
    final missingCodes = records
        .where((record) => record.imageUrl.trim().isEmpty)
        .map((record) => record.cardCode.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();

    if (missingCodes.isNotEmpty) {
      await _opApi.preload();
      await _warmUpApiCards(missingCodes);
    }

    return records.map(_enrichRecordFromCache).toList(growable: false);
  }

  Future<CardRecord> _enrichRecord(CardRecord record) async {
    if (record.imageUrl.trim().isNotEmpty) {
      return record;
    }

    await _opApi.preload();

    OpCard? matchedCard;
    if (record.cardCode.trim().isNotEmpty) {
      matchedCard = await _opApi.findCardByCode(record.cardCode);
    }

    if (matchedCard == null) {
      return record;
    }

    return _mergeRecordWithApiCard(record, matchedCard);
  }

  CardRecord _enrichRecordFromCache(CardRecord record) {
    if (record.imageUrl.trim().isNotEmpty) {
      return record;
    }

    final matchedCard = _apiCardCache[record.cardCode.trim().toUpperCase()];
    if (matchedCard == null) {
      return record;
    }

    return _mergeRecordWithApiCard(record, matchedCard);
  }

  CardRecord _mergeRecordWithApiCard(CardRecord record, OpCard matchedCard) {
    return record.copyWith(
      name: record.name.trim().isNotEmpty ? record.name : matchedCard.name,
      imageUrl: matchedCard.image.trim().isNotEmpty
          ? matchedCard.image
          : record.imageUrl,
      setName: record.setName.trim().isNotEmpty
          ? record.setName
          : matchedCard.setName,
      rarity: record.rarity.trim().isNotEmpty
          ? record.rarity
          : matchedCard.rarity,
      color: record.color.trim().isNotEmpty ? record.color : matchedCard.color,
      type: record.type.trim().isNotEmpty ? record.type : matchedCard.type,
      text: record.text.trim().isNotEmpty ? record.text : matchedCard.text,
      attribute: record.attribute.trim().isNotEmpty
          ? record.attribute
          : matchedCard.attribute,
    );
  }

  Map<String, dynamic> _buildDeckItemPayload(CardRecord record, String deckId) {
    return {
      'deck_id': deckId,
      'card_code': record.cardCode,
      'quantity': record.quantity,
      'is_favorite': record.isFavorite,
      'image_url': record.imageUrl,
      'name': record.name,
      'set_name': record.setName,
      'rarity': record.rarity,
      'color': record.color,
      'type': record.type,
      'text': record.text,
      'attribute': record.attribute,
    };
  }

  Map<String, dynamic> _buildCollectionItemPayload(
    CardRecord record,
    String userId,
  ) {
    return {
      'user_id': userId,
      'card_code': record.cardCode,
      'quantity': record.quantity,
      'collection_type': record.collectionType,
      'is_favorite': record.isFavorite,
      'image_url': record.imageUrl,
      'name': record.name,
      'set_name': record.setName,
      'rarity': record.rarity,
      'color': record.color,
      'type': record.type,
      'text': record.text,
      'attribute': record.attribute,
    };
  }

  bool _isValidUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    );

    return uuidRegex.hasMatch(value);
  }

  String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
