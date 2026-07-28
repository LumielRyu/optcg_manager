import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/tcg_collection_item.dart';

void main() {
  test('multi-TCG collection draft keeps game and catalog identity', () {
    const draft = TcgCollectionDraft(
      gameSlug: 'pokemon',
      catalogCardId: 'sv4-25',
      variantId: 'sv4-25',
      cardCode: 'POKEMON:PAR:25',
      name: 'Pikachu',
      imageUrl: 'https://example.test/pikachu.png',
      setName: 'Paradox Rift',
      rarity: 'Rare',
      color: 'Lightning',
      type: 'Pokémon',
      text: 'Carta de teste',
      attribute: 'Basic',
    );

    final payload = draft.toInsertJson('user-123');

    expect(payload['user_id'], 'user-123');
    expect(payload['game_slug'], 'pokemon');
    expect(payload['catalog_card_id'], 'sv4-25');
    expect(payload['variant_id'], 'sv4-25');
    expect(payload['card_code'], 'POKEMON:PAR:25');
    expect(payload['collection_type'], 'owned');
    expect(payload['quantity'], 1);
  });

  test('collection item reads the migrated identity columns', () {
    final item = TcgCollectionItem.fromJson({
      'id': 'item-1',
      'user_id': 'user-123',
      'game_slug': 'pokemon',
      'catalog_card_id': 'sv4-25',
      'variant_id': 'sv4-25',
      'card_code': 'POKEMON:PAR:25',
      'name': 'Pikachu',
      'quantity': 3,
      'created_at': '2026-07-28T12:00:00Z',
    });

    expect(item.gameSlug, 'pokemon');
    expect(item.catalogCardId, 'sv4-25');
    expect(item.quantity, 3);
    expect(item.createdAt.toUtc().year, 2026);
  });
}
