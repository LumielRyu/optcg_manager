import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/op_card.dart';
import 'package:optcg_manager/data/services/liga_price_admin_service.dart';

void main() {
  final catalog = <Map<String, dynamic>>[
    {
      'edition_id': 81,
      'acronym': 'OP-16',
      'release_date': '2026-06-12 00:00:00',
      'group': 'main',
    },
    {
      'edition_id': 80,
      'acronym': 'OP-15-RE',
      'release_date': '2026-03-27 00:00:00',
      'group': 'aux',
    },
  ];

  test('aggregates every cached row by edition', () {
    final result = LigaPriceAdminService.buildEditionStatuses(
      catalog: catalog,
      priceRows: [
        {
          'edition_code': 'op-16',
          'minimum_price': 4.5,
          'resolved_at': '2026-07-23T10:00:00Z',
        },
        {
          'edition_code': 'OP-16',
          'minimum_price': null,
          'resolved_at': '2026-07-23T11:00:00Z',
        },
      ],
    );

    expect(result, hasLength(2));
    expect(result.first.cardCount, 2);
    expect(result.first.pricedCardCount, 1);
    expect(result.first.oldestUpdate, DateTime.utc(2026, 7, 23, 10));
    expect(result.first.latestUpdate, DateTime.utc(2026, 7, 23, 11));
    expect(result.last.cardCount, 0);
    expect(result.last.latestUpdate, isNull);
  });

  test('classifies current, partial, stale and untouched editions', () {
    final now = DateTime.utc(2026, 7, 23, 12);

    LigaEditionPriceStatus status({DateTime? oldest, DateTime? latest}) =>
        LigaEditionPriceStatus(
          editionId: 1,
          acronym: 'OP-16',
          releaseDate: null,
          group: 'main',
          cardCount: latest == null ? 0 : 1,
          pricedCardCount: latest == null ? 0 : 1,
          oldestUpdate: oldest,
          latestUpdate: latest,
        );

    expect(
      status(
        oldest: DateTime.utc(2026, 7, 23, 8),
        latest: DateTime.utc(2026, 7, 23, 8),
      ).stateAt(now),
      LigaEditionUpdateState.current,
    );
    expect(
      status(
        oldest: DateTime.utc(2026, 7, 21),
        latest: DateTime.utc(2026, 7, 23, 8),
      ).stateAt(now),
      LigaEditionUpdateState.partial,
    );
    expect(
      status(
        oldest: DateTime.utc(2026, 7, 20),
        latest: DateTime.utc(2026, 7, 20),
      ).stateAt(now),
      LigaEditionUpdateState.stale,
    );
    expect(status().stateAt(now), LigaEditionUpdateState.neverUpdated);
  });

  test('audit separates unique, ambiguous and missing variants', () {
    OpCard card(String name, String image) => OpCard(
      code: 'EB01-006',
      name: name,
      image: image,
      setName: 'EB01',
      rarity: 'SR',
      color: 'Red',
      type: 'Character',
      subTypes: '',
      text: '',
      attribute: '',
    );

    final audit = LigaPriceAdminService.buildVariantAudit(
      cards: [
        card('Tony Tony.Chopper', 'https://catalog.example/normal.png'),
        card(
          'Tony Tony.Chopper (Alternate Art) (Manga)',
          'https://catalog.example/manga.png',
        ),
        card(
          'Tony Tony.Chopper (Treasure Cup 2024)',
          'https://catalog.example/treasure.png',
        ),
      ],
      priceRows: [
        {
          'card_code': 'EB01-006',
          'edition_code': 'EB01',
          'image_url': 'https://liga.example/normal.png',
          'minimum_price': 116.89,
        },
        {
          'card_code': 'EB01-006-MA',
          'edition_code': 'EB01',
          'image_url': 'https://liga.example/manga.png',
          'minimum_price': 13000,
        },
        {
          'card_code': 'EB01-006-MA',
          'edition_code': 'PRB01',
          'image_url': 'https://liga.example/manga-prb.png',
          'minimum_price': 5700,
        },
      ],
    );

    expect(audit.catalogCardCount, 3);
    expect(audit.multiPrintingFamilyCount, 1);
    expect(audit.cardsInMultiPrintingFamilies, 3);
    expect(audit.maximumVariantsPerCode, 3);
    expect(audit.uniquelyMatchedCards, 2);
    expect(audit.ambiguousCards, 0);
    expect(audit.missingCards, 1);
    expect(audit.variantCounts['Manga'], 1);
    expect(audit.variantCounts['Treasure Cup'], 1);
  });
}
