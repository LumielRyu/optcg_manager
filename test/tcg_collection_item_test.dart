import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/tcg/tcg_collection_drafts.dart';
import 'package:optcg_manager/data/models/digimon_card.dart';
import 'package:optcg_manager/data/models/magic_card.dart';
import 'package:optcg_manager/data/models/riftbound_card.dart';
import 'package:optcg_manager/data/models/tcg_collection_item.dart';
import 'package:optcg_manager/data/models/yugioh_card.dart';

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

  test('Digimon collection keeps the printed card code', () {
    final card = DigimonCard(
      id: '/cards/en/BT14-001',
      name: 'Koromon',
      number: 'BT14-001',
      imageUrl: 'https://example.test/koromon.webp',
      category: 'digi-egg',
      rarity: 'U',
      attribute: '',
      type: 'Lesser',
      form: 'In-Training',
      effect: '',
      inheritedEffect: 'Draw 1',
      securityEffect: '',
      setName: 'Booster BLAST ACE',
      colors: const ['red'],
      level: 2,
      playCost: 0,
      dp: 0,
    );

    expect(card.ligaLookupCode, 'DIGIMON:BT14-001');
    expect(card.collectionDraft.gameSlug, 'digimon');
    expect(card.collectionDraft.variantId, 'BT14-001');
  });

  test('Magic and Riftbound use set plus collector number', () {
    final magic = MagicCard.fromJson({
      'id': 'magic-1',
      'name': 'Test Card',
      'collector_number': '007',
      'set': 'fin',
      'set_name': 'Final Fantasy',
      'image_uris': {'normal': 'https://example.test/magic.png'},
    });
    final riftbound = RiftboundCard.fromJson({
      'id': 'rift-1',
      'name': 'Fury Rune',
      'riftbound_id': 'ven-r01',
      'collector_number': 1,
      'set': {'set_id': 'VEN', 'label': 'Vendetta'},
      'classification': {
        'type': 'Rune',
        'supertype': 'Basic',
        'rarity': 'Common',
        'domain': ['Fury'],
      },
      'media': {'image_url': 'https://example.test/riftbound.png'},
    });

    expect(magic.ligaLookupCode, 'MAGIC:FIN:7');
    expect(magic.collectionDraft.variantId, 'fin:007');
    expect(riftbound.ligaLookupCode, 'RIFTBOUND:VEN:1');
    expect(riftbound.collectionDraft.variantId, 'ven-r01');
  });

  test('Yu-Gi-Oh requires a printing and stores it as the variant', () {
    final card = YugiohCard.fromJson({
      'id': 46986414,
      'name': 'Dark Magician',
      'type': 'Normal Monster',
      'card_images': [
        {'image_url': 'https://example.test/dark-magician.jpg'},
      ],
      'card_sets': [
        {
          'set_name': 'Legend of Blue Eyes White Dragon',
          'set_code': 'LOB-EN005',
          'set_rarity': 'Ultra Rare',
        },
      ],
    });
    final printing = card.printings.single;
    final draft = card.collectionDraftFor(printing);

    expect(printing.ligaLookupCode, 'YUGIOH:LOB-EN005');
    expect(draft.gameSlug, 'yugioh');
    expect(draft.variantId, 'LOB-EN005');
    expect(draft.setName, 'Legend of Blue Eyes White Dragon');
  });
}
