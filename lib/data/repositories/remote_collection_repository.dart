import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/collection_types.dart';
import '../models/card_record.dart';
import '../models/remote_collection_item.dart';
import '../services/op_api_service.dart';
import '../services/supabase_client_provider.dart';

final remoteCollectionRepositoryProvider = Provider<RemoteCollectionRepository>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    final opApi = ref.watch(opApiServiceProvider);
    return RemoteCollectionRepository(client, opApi);
  },
);

class RemoteCollectionRepository {
  final SupabaseClient _client;
  final OpApiService _opApiService;
  static const String _remoteCollectionColumns =
      'id, card_code, quantity, collection_type, is_favorite, created_at';

  RemoteCollectionRepository(this._client, this._opApiService);

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Usuario nao autenticado.');
    }
    return user.id;
  }

  Future<List<CardRecord>> getAll() async {
    await _opApiService.preload();

    final response = await _client
        .from('collection_items')
        .select(_remoteCollectionColumns)
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    final rows = (response as List)
        .map((e) => RemoteCollectionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final uniqueCodes = rows
        .map((row) => row.cardCode)
        .toSet()
        .toList(growable: false);
    final apiCards = await Future.wait(
      uniqueCodes.map(
        (code) async =>
            MapEntry(code, await _opApiService.findCardByCode(code)),
      ),
    );
    final apiCardByCode = {
      for (final entry in apiCards) entry.key: entry.value,
    };

    return rows
        .map((row) {
          final apiCard = apiCardByCode[row.cardCode];
          return row.toCardRecord(
            name: apiCard?.name ?? row.cardCode,
            imageUrl: apiCard?.image ?? '',
            setName: apiCard?.setName ?? '',
            rarity: apiCard?.rarity ?? '',
            color: apiCard?.color ?? '',
            type: apiCard?.type ?? '',
            text: apiCard?.text ?? '',
            attribute: apiCard?.attribute ?? '',
          );
        })
        .toList(growable: false);
  }

  Future<void> upsert(CardRecord record) async {
    await _client.from('collection_items').upsert({
      'id': record.id,
      'user_id': _userId,
      'card_code': record.cardCode,
      'quantity': record.quantity,
      'collection_type': record.collectionType == CollectionTypes.forSale
          ? CollectionTypes.forSale
          : CollectionTypes.owned,
      'is_favorite': record.isFavorite,
    });
  }

  Future<void> delete(String id) async {
    await _client.from('collection_items').delete().eq('id', id);
  }

  Future<void> deleteManyByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('collection_items').delete().inFilter('id', ids);
  }

  Future<List<CardRecord>> findByCodeAndCollection({
    required String cardCode,
    required String collectionType,
  }) async {
    await _opApiService.preload();

    final response = await _client
        .from('collection_items')
        .select(_remoteCollectionColumns)
        .eq('user_id', _userId)
        .eq('card_code', cardCode)
        .eq('collection_type', collectionType);

    final rows = (response as List)
        .map((e) => RemoteCollectionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final apiCard = await _opApiService.findCardByCode(cardCode);

    return rows
        .map(
          (row) => row.toCardRecord(
            name: apiCard?.name ?? row.cardCode,
            imageUrl: apiCard?.image ?? '',
            setName: apiCard?.setName ?? '',
            rarity: apiCard?.rarity ?? '',
            color: apiCard?.color ?? '',
            type: apiCard?.type ?? '',
            text: apiCard?.text ?? '',
            attribute: apiCard?.attribute ?? '',
          ),
        )
        .toList();
  }
}
