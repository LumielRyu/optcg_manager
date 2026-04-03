import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/collection_types.dart';
import '../local/hive_boxes.dart';
import '../models/card_record.dart';
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

  const DeckShareInfo({
    required this.isPublic,
    required this.shareCode,
  });
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

  const SaleCardShareInfo({
    required this.isPublic,
    required this.shareCode,
  });
}

class SharedSaleCardData {
  final String shareCode;
  final CardRecord item;

  const SharedSaleCardData({
    required this.shareCode,
    required this.item,
  });
}

class CollectionRepository {
  final SupabaseClient _client;
  final OpApiService _opApi;

  CollectionRepository(this._client, this._opApi);

  Box<CardRecord> get _box => Hive.box<CardRecord>(HiveBoxes.collection);

  List<CardRecord> _cache = const [];

  List<CardRecord> getAll() {
    final list = [..._cache];
    list.sort((a, b) => b.dateAddedUtc.compareTo(a.dateAddedUtc));
    return list;
  }

  Future<void> refreshAll() async {
    await _migrateLegacyLocalCollectionIfNeeded();
    await _migrateLegacyLocalDecksIfNeeded();
    await _opApi.preload();

    final all = <CardRecord>[];
    final user = _client.auth.currentUser;

    if (user != null) {
      final collectionResponse = await _client
          .from('collection_items')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      for (final raw in (collectionResponse as List)) {
        final map = Map<String, dynamic>.from(raw);
        final cardCode =
            (map['card_code'] ?? '').toString().trim().toUpperCase();
        final apiCard = await _opApi.findCardByCode(cardCode);

        all.add(
          CardRecord(
            id: map['id'].toString(),
            cardCode: cardCode,
            name: apiCard?.name ?? cardCode,
            imageUrl: apiCard?.image ?? '',
            dateAddedUtc: DateTime.tryParse(
                  (map['created_at'] ?? '').toString(),
                ) ??
                DateTime.now(),
            setName: apiCard?.setName ?? '',
            rarity: apiCard?.rarity ?? '',
            color: apiCard?.color ?? '',
            type: apiCard?.type ?? '',
            text: apiCard?.text ?? '',
            attribute: apiCard?.attribute ?? '',
            quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            collectionType:
                (map['collection_type'] ?? CollectionTypes.owned).toString(),
            deckName: null,
            isFavorite: (map['is_favorite'] as bool?) ?? false,
          ),
        );
      }

      final decksResponse = await _client
          .from('decks')
          .select(
            'id, name, created_at, is_public, share_code, deck_items(id, card_code, quantity, is_favorite, created_at)',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      for (final rawDeck in (decksResponse as List)) {
        final deckMap = Map<String, dynamic>.from(rawDeck);
        final deckName = (deckMap['name'] ?? '').toString();
        final deckItemsRaw = (deckMap['deck_items'] as List?) ?? const [];

        for (final rawItem in deckItemsRaw) {
          final itemMap = Map<String, dynamic>.from(rawItem);
          final cardCode =
              (itemMap['card_code'] ?? '').toString().trim().toUpperCase();
          final apiCard = await _opApi.findCardByCode(cardCode);

          all.add(
            CardRecord(
              id: itemMap['id'].toString(),
              cardCode: cardCode,
              name: apiCard?.name ?? cardCode,
              imageUrl: apiCard?.image ?? '',
              dateAddedUtc: DateTime.tryParse(
                    (itemMap['created_at'] ?? '').toString(),
                  ) ??
                  DateTime.now(),
              setName: apiCard?.setName ?? '',
              rarity: apiCard?.rarity ?? '',
              color: apiCard?.color ?? '',
              type: apiCard?.type ?? '',
              text: apiCard?.text ?? '',
              attribute: apiCard?.attribute ?? '',
              quantity: (itemMap['quantity'] as num?)?.toInt() ?? 1,
              collectionType: CollectionTypes.deck,
              deckName: deckName,
              isFavorite: (itemMap['is_favorite'] as bool?) ?? false,
            ),
          );
        }
      }
    }

    _cache = all;
  }

  Future<void> upsert(CardRecord record) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    if (record.collectionType == CollectionTypes.deck) {
      final normalizedDeckName = (record.deckName ?? '').trim();
      if (normalizedDeckName.isEmpty) {
        throw Exception('Deck sem nome.');
      }

      final deckId = await _ensureDeck(
        userId: user.id,
        deckName: normalizedDeckName,
      );

      final payload = {
        'deck_id': deckId,
        'card_code': record.cardCode,
        'quantity': record.quantity,
        'is_favorite': record.isFavorite,
      };

      if (_isValidUuid(record.id)) {
        await _client.from('deck_items').upsert({
          'id': record.id,
          ...payload,
        });
      } else {
        await _client.from('deck_items').insert(payload);
      }

      await refreshAll();
      return;
    }

    final payload = {
      'user_id': user.id,
      'card_code': record.cardCode,
      'quantity': record.quantity,
      'collection_type': record.collectionType,
      'is_favorite': record.isFavorite,
    };

    if (_isValidUuid(record.id)) {
      await _client.from('collection_items').upsert({
        'id': record.id,
        ...payload,
      });
    } else {
      await _client.from('collection_items').insert(payload);
    }

    await refreshAll();
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
    final shareCode =
        (row['share_code']?.toString().trim().isNotEmpty ?? false)
            ? row['share_code'].toString()
            : _generateShareCode();

    await _client.from('decks').update({
      'is_public': true,
      'share_code': shareCode,
    }).eq('id', deckId);

    return shareCode;
  }

  Future<void> disableDeckSharing(String deckName) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('decks').update({
      'is_public': false,
    }).eq('user_id', user.id).eq('name', deckName.trim());
  }

  Future<SharedDeckData?> getSharedDeck(String shareCode) async {
    await _opApi.preload();

    final row = await _client
        .from('decks')
        .select(
          'name, share_code, deck_items(id, card_code, quantity, is_favorite, created_at)',
        )
        .eq('share_code', shareCode)
        .eq('is_public', true)
        .maybeSingle();

    if (row == null) return null;

    final deckName = (row['name'] ?? '').toString();
    final itemsRaw = (row['deck_items'] as List?) ?? const [];
    final items = <CardRecord>[];

    for (final rawItem in itemsRaw) {
      final itemMap = Map<String, dynamic>.from(rawItem);
      final cardCode =
          (itemMap['card_code'] ?? '').toString().trim().toUpperCase();
      final apiCard = await _opApi.findCardByCode(cardCode);

      items.add(
        CardRecord(
          id: itemMap['id'].toString(),
          cardCode: cardCode,
          name: apiCard?.name ?? cardCode,
          imageUrl: apiCard?.image ?? '',
          dateAddedUtc: DateTime.tryParse(
                (itemMap['created_at'] ?? '').toString(),
              ) ??
              DateTime.now(),
          setName: apiCard?.setName ?? '',
          rarity: apiCard?.rarity ?? '',
          color: apiCard?.color ?? '',
          type: apiCard?.type ?? '',
          text: apiCard?.text ?? '',
          attribute: apiCard?.attribute ?? '',
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

    final shareCode =
        (row['share_code']?.toString().trim().isNotEmpty ?? false)
            ? row['share_code'].toString()
            : _generateShareCode();

    await _client.from('collection_items').update({
      'is_public': true,
      'share_code': shareCode,
    }).eq('id', itemId);

    return shareCode;
  }

  Future<void> disableSaleCardSharing(String itemId) async {
    final user = _client.auth.currentUser;
    if (user == null || !_isValidUuid(itemId)) return;

    await _client.from('collection_items').update({
      'is_public': false,
    }).eq('user_id', user.id).eq('id', itemId);
  }

  Future<SharedSaleCardData?> getSharedSaleCard(String shareCode) async {
    await _opApi.preload();

    final row = await _client
        .from('collection_items')
        .select('id, card_code, quantity, is_favorite, created_at, share_code')
        .eq('share_code', shareCode)
        .eq('is_public', true)
        .eq('collection_type', CollectionTypes.forSale)
        .maybeSingle();

    if (row == null) return null;

    final cardCode = (row['card_code'] ?? '').toString().trim().toUpperCase();
    final apiCard = await _opApi.findCardByCode(cardCode);

    final item = CardRecord(
      id: row['id'].toString(),
      cardCode: cardCode,
      name: apiCard?.name ?? cardCode,
      imageUrl: apiCard?.image ?? '',
      dateAddedUtc: DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      setName: apiCard?.setName ?? '',
      rarity: apiCard?.rarity ?? '',
      color: apiCard?.color ?? '',
      type: apiCard?.type ?? '',
      text: apiCard?.text ?? '',
      attribute: apiCard?.attribute ?? '',
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
  }) {
    try {
      return _cache.firstWhere(
        (item) =>
            item.cardCode.toUpperCase() == cardCode.toUpperCase() &&
            item.collectionType == collectionType &&
            (item.deckName ?? '') == (deckName ?? ''),
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
      };

      if (_isValidUuid(item.id)) {
        await _client.from('deck_items').upsert({
          'id': item.id,
          ...payload,
        });
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
        .insert({
          'user_id': userId,
          'name': deckName,
        })
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