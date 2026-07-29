import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/widgets/tcg_liga_price.dart';
import 'package:optcg_manager/data/services/liga_tcg_price_service.dart';

LigaTcgPriceSnapshot _snapshot(String code, double? price) {
  return LigaTcgPriceSnapshot(
    lookupCode: code,
    sourceUrl: 'https://www.ligart.com.br/',
    cardName: code,
    editionCode: 'OGN',
    minimumPrice: price,
    resolvedAt: DateTime.now().toUtc(),
  );
}

void main() {
  test('soma o preço das variantes e respectivas quantidades do deck', () {
    final valuation = calculateTcgLigaDeckValuation(
      items: const [
        TcgLigaCollectionItemReference(
          lookupCode: 'riftbound:ogn:1',
          quantity: 3,
        ),
        TcgLigaCollectionItemReference(
          lookupCode: 'RIFTBOUND:OGN:1-ALT',
          quantity: 1,
        ),
      ],
      snapshots: {
        'RIFTBOUND:OGN:1': _snapshot('RIFTBOUND:OGN:1', 2.50),
        'RIFTBOUND:OGN:1-ALT': _snapshot('RIFTBOUND:OGN:1-ALT', 10),
      },
    );

    expect(valuation.totalValue, 17.50);
    expect(valuation.totalCards, 4);
    expect(valuation.pricedCards, 4);
    expect(valuation.isComplete, isTrue);
  });

  test('informa valor parcial quando uma carta ainda não possui preço', () {
    final valuation = calculateTcgLigaDeckValuation(
      items: const [
        TcgLigaCollectionItemReference(
          lookupCode: 'RIFTBOUND:SFD:8',
          quantity: 2,
        ),
        TcgLigaCollectionItemReference(
          lookupCode: 'RIFTBOUND:SFD:9',
          quantity: 2,
        ),
      ],
      snapshots: {
        'RIFTBOUND:SFD:8': _snapshot('RIFTBOUND:SFD:8', 4),
        'RIFTBOUND:SFD:9': _snapshot('RIFTBOUND:SFD:9', null),
      },
    );

    expect(valuation.totalValue, 8);
    expect(valuation.totalCards, 4);
    expect(valuation.pricedCards, 2);
    expect(valuation.isComplete, isFalse);
  });
}
