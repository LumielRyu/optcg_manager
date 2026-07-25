import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/widgets/liga_price_display.dart';
import 'package:optcg_manager/data/services/liga_one_piece_service.dart';

void main() {
  const normalSnapshot = LigaOnePieceCardSnapshot(
    sourceUrl: 'https://liga.example/card',
    cardName: 'Kouzuki Oden',
    cardCode: 'EB01-001',
    editionCode: 'EB01',
    imageUrl: 'https://liga.example/oden.jpg',
    minimumPrice: 28,
    averagePrice: null,
    maximumPrice: null,
    listingCount: 1,
    lowestListing: null,
    lowestStore: null,
    historyEndpointRequiresLogin: true,
    usedVerifiedFallback: false,
    note: null,
  );
  const alternateSnapshot = LigaOnePieceCardSnapshot(
    sourceUrl: 'https://liga.example/card-alt',
    cardName: 'Kouzuki Oden (Alternate Art)',
    cardCode: 'EB01-001-AA',
    editionCode: 'EB01',
    imageUrl: 'https://liga.example/oden-alt.jpg',
    minimumPrice: 229.99,
    averagePrice: null,
    maximumPrice: null,
    listingCount: 1,
    lowestListing: null,
    lowestStore: null,
    historyEndpointRequiresLogin: true,
    usedVerifiedFallback: false,
    note: null,
  );

  test('price label prefers the exact image-specific snapshot', () {
    final selected = selectLigaPriceSnapshot(
      snapshots: const {
        'EB01-001': normalSnapshot,
        'EB01-001-AA': alternateSnapshot,
        'EB01-001-AA::IMG::alternatejpg': alternateSnapshot,
      },
      referenceKey: 'EB01-001-AA::IMG::alternatejpg',
      lookupCode: 'EB01-001-AA',
      cardCode: 'EB01-001',
    );

    expect(selected?.minimumPrice, 229.99);
  });

  test('price label falls back to lookup code when image URL changes', () {
    final selected = selectLigaPriceSnapshot(
      snapshots: const {'EB01-001-AA': alternateSnapshot},
      referenceKey: 'EB01-001-AA::IMG::newcdnimagejpg',
      lookupCode: 'EB01-001-AA',
      cardCode: 'EB01-001',
    );

    expect(selected?.minimumPrice, 229.99);
  });

  test('price label falls back to normalized card code', () {
    final selected = selectLigaPriceSnapshot(
      snapshots: const {'EB01-001': normalSnapshot},
      referenceKey: 'EB01-001::IMG::newcdnimagejpg',
      lookupCode: 'EB01-001',
      cardCode: 'eb01-001',
    );

    expect(selected?.minimumPrice, 28);
  });

  test('collection value multiplies Liga price by owned quantity', () {
    final valuation = calculateLigaCollectionValuation(
      items: const [
        LigaPriceCollectionItemReference(
          cardName: 'Monkey D. Luffy',
          cardCode: 'OP01-001',
          quantity: 3,
        ),
        LigaPriceCollectionItemReference(
          cardName: 'Nami',
          cardCode: 'OP01-016',
          quantity: 2,
        ),
        LigaPriceCollectionItemReference(
          cardName: 'Sem preço',
          cardCode: 'OP99-999',
          quantity: 4,
        ),
      ],
      prices: const {'OP01-001': 10.50, 'OP01-016': 4.25},
      priceReferenceKeyForCard: (_, cardCode, _) => cardCode,
    );

    expect(valuation.totalValue, 40);
    expect(valuation.totalUnits, 9);
    expect(valuation.pricedUnits, 5);
    expect(valuation.totalUniqueCards, 3);
    expect(valuation.pricedUniqueCards, 2);
    expect(valuation.unpricedUniqueCards, 1);
  });

  test('collection value ignores negative quantities and missing prices', () {
    final valuation = calculateLigaCollectionValuation(
      items: const [
        LigaPriceCollectionItemReference(
          cardName: 'Carta',
          cardCode: 'OP01-001',
          quantity: -2,
        ),
        LigaPriceCollectionItemReference(
          cardName: 'Sem oferta',
          cardCode: 'OP01-002',
          quantity: 1,
        ),
      ],
      prices: const {'OP01-001': 10, 'OP01-002': null},
      priceReferenceKeyForCard: (_, cardCode, _) => cardCode,
    );

    expect(valuation.totalValue, 0);
    expect(valuation.totalUnits, 1);
    expect(valuation.pricedUnits, 0);
    expect(valuation.pricedUniqueCards, 1);
    expect(valuation.unpricedUniqueCards, 1);
  });
}
