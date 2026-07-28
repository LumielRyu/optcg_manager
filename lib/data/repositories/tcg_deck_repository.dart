import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/tcg/tcg_deck_rules.dart';
import '../../core/tcg/tcg_game.dart';
import '../models/tcg_collection_item.dart';
import '../models/tcg_deck.dart';
import '../services/supabase_client_provider.dart';

final tcgDeckRepositoryProvider = Provider<TcgDeckRepository>((ref) {
  return TcgDeckRepository(ref.watch(supabaseClientProvider));
});

class TcgDeckRepository {
  static const _itemColumns =
      'id, deck_id, game_slug, catalog_card_id, variant_id, deck_zone, '
      'card_code, quantity, image_url, name, set_name, rarity, color, type, '
      'text, attribute';

  final SupabaseClient _client;

  const TcgDeckRepository(this._client);

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('É necessário entrar para acessar seus decks.');
    }
    return user;
  }

  Future<List<TcgDeck>> listDecks(TcgGame game) async {
    final user = _requireUser();
    final rows = await _client
        .from('decks')
        .select(
          'id, name, game_slug, format_slug, created_at, '
          'deck_items($_itemColumns)',
        )
        .eq('user_id', user.id)
        .eq('game_slug', game.slug)
        .order('created_at', ascending: false);

    return rows
        .map((row) => TcgDeck.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<TcgDeck> getDeck(String deckId) async {
    final user = _requireUser();
    final row = await _client
        .from('decks')
        .select(
          'id, name, game_slug, format_slug, created_at, '
          'deck_items($_itemColumns)',
        )
        .eq('id', deckId)
        .eq('user_id', user.id)
        .single();
    return TcgDeck.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> createDeck({
    required TcgGame game,
    required String name,
    required TcgDeckFormatRules format,
  }) async {
    final user = _requireUser();
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Informe o nome do deck.');
    }
    final inserted = await _client
        .from('decks')
        .insert({
          'user_id': user.id,
          'name': normalizedName,
          'game_slug': game.slug,
          'format_slug': format.slug,
        })
        .select('id')
        .single();
    return inserted['id'].toString();
  }

  Future<void> deleteDeck(String deckId) async {
    final user = _requireUser();
    await _client.from('deck_items').delete().eq('deck_id', deckId);
    await _client
        .from('decks')
        .delete()
        .eq('id', deckId)
        .eq('user_id', user.id);
  }

  Future<void> addOrIncrement({
    required TcgDeck deck,
    required TcgCollectionItem card,
    required TcgDeckZone zone,
  }) async {
    _requireUser();
    final rows = await _client
        .from('deck_items')
        .select('id, quantity')
        .eq('deck_id', deck.id)
        .eq('game_slug', deck.gameSlug)
        .eq('catalog_card_id', card.catalogCardId)
        .eq('variant_id', card.variantId)
        .eq('deck_zone', zone.name)
        .limit(1);

    if (rows.isNotEmpty) {
      final row = Map<String, dynamic>.from(rows.first);
      final quantity = int.tryParse((row['quantity'] ?? 0).toString()) ?? 0;
      await _client
          .from('deck_items')
          .update({'quantity': quantity + 1})
          .eq('id', row['id']);
      return;
    }

    await _client.from('deck_items').insert({
      'deck_id': deck.id,
      'game_slug': deck.gameSlug,
      'catalog_card_id': card.catalogCardId,
      'variant_id': card.variantId,
      'deck_zone': zone.name,
      'card_code': card.cardCode,
      'quantity': 1,
      'is_favorite': false,
      'image_url': card.imageUrl,
      'name': card.name,
      'set_name': card.setName,
      'rarity': card.rarity,
      'color': card.color,
      'type': card.type,
      'text': card.text,
      'attribute': card.attribute,
    });
  }

  Future<void> setItemQuantity(TcgDeckItem item, int quantity) async {
    _requireUser();
    if (quantity <= 0) {
      await _client.from('deck_items').delete().eq('id', item.id);
      return;
    }
    await _client
        .from('deck_items')
        .update({'quantity': quantity})
        .eq('id', item.id);
  }

  Future<void> moveItem(TcgDeckItem item, TcgDeckZone zone) async {
    _requireUser();
    if (item.zone == zone) return;
    final duplicates = await _client
        .from('deck_items')
        .select('id, quantity')
        .eq('deck_id', item.deckId)
        .eq('game_slug', item.gameSlug)
        .eq('catalog_card_id', item.catalogCardId)
        .eq('variant_id', item.variantId)
        .eq('deck_zone', zone.name)
        .limit(1);
    if (duplicates.isNotEmpty) {
      final target = Map<String, dynamic>.from(duplicates.first);
      final targetQuantity =
          int.tryParse((target['quantity'] ?? 0).toString()) ?? 0;
      await _client
          .from('deck_items')
          .update({'quantity': targetQuantity + item.quantity})
          .eq('id', target['id']);
      await _client.from('deck_items').delete().eq('id', item.id);
      return;
    }
    await _client
        .from('deck_items')
        .update({'deck_zone': zone.name})
        .eq('id', item.id);
  }
}
