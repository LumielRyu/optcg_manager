import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/widgets/liga_price_display.dart';

void main() {
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
