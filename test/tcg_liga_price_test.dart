import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optcg_manager/data/models/pokemon_card.dart';
import 'package:optcg_manager/data/models/riftbound_card.dart';
import 'package:optcg_manager/data/services/liga_tcg_price_service.dart';
import 'package:optcg_manager/data/services/pokemon_tcg_service.dart';

void main() {
  test('Pokemon card builds the same Liga key as the edition importer', () {
    final card = PokemonCard.fromJson({
      'id': 'me5-41',
      'name': 'Annihilape',
      'number': '041',
      'images': {'small': 'small.jpg', 'large': 'large.jpg'},
      'set': {'id': 'me5', 'name': 'Pitch Black', 'ptcgoCode': 'PBL'},
      'rarity': 'Uncommon',
      'supertype': 'Pokémon',
    });

    expect(card.setId, 'me5');
    expect(card.setCode, 'PBL');
    expect(card.ligaLookupCode, 'POKEMON:PBL:41');
  });

  test('Pokemon Liga lookup falls back to the catalog set id', () {
    final service = LigaTcgPriceService.normalizeCardNumber;

    expect(service('001'), '1');
    expect(service('#014/100'), '14');
    expect(service('TG01'), 'TG01');
  });

  test('generic Liga snapshot maps public cache fields', () {
    final snapshot = LigaTcgPriceSnapshot.fromRow({
      'lookup_code': 'pokemon:pbl:41',
      'source_url': 'https://www.ligapokemon.com.br/',
      'card_name': 'Annihilape',
      'edition_code': 'PBL',
      'minimum_price': '0.42',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    });

    expect(snapshot.lookupCode, 'POKEMON:PBL:41');
    expect(snapshot.minimumPrice, 0.42);
    expect(snapshot.isStale, isFalse);
  });

  test('Riftbound maps promotional sets and preserves variant suffixes', () {
    final promo = RiftboundCard.fromJson({
      'id': 'promo',
      'name': 'Fury Rune',
      'riftbound_id': 'opp-007b-298',
      'collector_number': 1,
      'set': {
        'set_id': 'OPP',
        'label': 'Riftbound Organized Play Promotional Cards',
      },
    });
    final originsPromo = RiftboundCard.fromJson({
      'id': 'origins-promo',
      'name': 'Vi - Destructive',
      'riftbound_id': 'pr-036a-298',
      'collector_number': 167,
      'set': {'set_id': 'PR', 'label': 'Riftbound Promotional Cards'},
    });

    expect(promo.ligaLookupCode, 'RIFTBOUND:ROPP:7B');
    expect(originsPromo.ligaLookupCode, 'RIFTBOUND:OGN-PR:36A');

    final signature = RiftboundCard.fromJson({
      'id': 'signature',
      'name': 'Master Yi - Wuju Master (Signature)',
      'riftbound_id': 'unl-231*-219',
      'collector_number': 231,
      'set': {'set_id': 'UNL', 'label': 'Unleashed'},
    });
    expect(signature.ligaLookupCode, 'RIFTBOUND:UNL:231S');
  });

  test('Pokemon catalog retries temporary server errors', () async {
    var requests = 0;
    final service = PokemonTcgService(
      MockClient((_) async {
        requests++;
        if (requests < 3) {
          return http.Response('temporarily unavailable', 500);
        }
        return http.Response(
          '{"data":[],"page":1,"pageSize":60,"totalCount":0}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.searchCards(query: '', page: 1);

    expect(requests, 3);
    expect(result.cards, isEmpty);
  });
}
