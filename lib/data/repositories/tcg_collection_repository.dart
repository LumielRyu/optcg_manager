import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/collection_types.dart';
import '../models/tcg_collection_item.dart';
import '../services/supabase_client_provider.dart';

final tcgCollectionRepositoryProvider = Provider<TcgCollectionRepository>((
  ref,
) {
  return TcgCollectionRepository(ref.watch(supabaseClientProvider));
});

class TcgCollectionRepository {
  static const _columns =
      'id, user_id, game_slug, catalog_card_id, variant_id, card_code, '
      'quantity, is_favorite, created_at, image_url, name, set_name, rarity, '
      'color, type, text, attribute';

  final SupabaseClient _client;

  const TcgCollectionRepository(this._client);

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('É necessário entrar para acessar sua coleção.');
    }
    return user;
  }

  Future<List<TcgCollectionItem>> listOwned(String gameSlug) async {
    final user = _requireUser();
    final rows = await _client
        .from('collection_items')
        .select(_columns)
        .eq('user_id', user.id)
        .eq('game_slug', gameSlug)
        .eq('collection_type', CollectionTypes.owned)
        .order('created_at', ascending: false);

    return rows
        .map(
          (row) => TcgCollectionItem.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> addOrIncrement(TcgCollectionDraft draft) async {
    final user = _requireUser();
    final rows = await _client
        .from('collection_items')
        .select('id, quantity')
        .eq('user_id', user.id)
        .eq('game_slug', draft.gameSlug)
        .eq('collection_type', CollectionTypes.owned)
        .eq('catalog_card_id', draft.catalogCardId)
        .eq('variant_id', draft.variantId)
        .limit(1);

    if (rows.isNotEmpty) {
      final row = Map<String, dynamic>.from(rows.first);
      final quantity = int.tryParse((row['quantity'] ?? 0).toString()) ?? 0;
      await _client
          .from('collection_items')
          .update({'quantity': quantity + 1})
          .eq('id', row['id']);
      return;
    }

    await _client.from('collection_items').insert(draft.toInsertJson(user.id));
  }

  Future<void> setQuantity(TcgCollectionItem item, int quantity) async {
    final user = _requireUser();
    if (quantity <= 0) {
      await _client
          .from('collection_items')
          .delete()
          .eq('id', item.id)
          .eq('user_id', user.id)
          .eq('game_slug', item.gameSlug);
      return;
    }

    await _client
        .from('collection_items')
        .update({'quantity': quantity})
        .eq('id', item.id)
        .eq('user_id', user.id)
        .eq('game_slug', item.gameSlug);
  }
}
