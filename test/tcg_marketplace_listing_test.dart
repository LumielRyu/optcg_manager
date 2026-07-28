import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/tcg_marketplace_listing.dart';

void main() {
  group('TcgMarketplaceListing', () {
    test('maps multi-TCG identity and public sale state', () {
      final listing = TcgMarketplaceListing.fromRow({
        'id': 'sale-1',
        'user_id': 'seller-1',
        'game_slug': 'pokemon',
        'catalog_card_id': 'sv1-1',
        'variant_id': 'SV1:1',
        'card_code': 'POKEMON:SV1:1',
        'name': 'Sprigatito',
        'quantity': 2,
        'is_public': true,
        'sale_price_cents': 1250,
        'sale_status': 'active',
        'sale_expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 1))
            .toIso8601String(),
      }, sellerName: 'Treinador BH');

      expect(listing.gameSlug, 'pokemon');
      expect(listing.catalogCardId, 'sv1-1');
      expect(listing.variantId, 'SV1:1');
      expect(listing.formattedPrice, r'R$ 12,50');
      expect(listing.isVisible, isTrue);
      expect(listing.sellerName, 'Treinador BH');
    });

    test('expired sale is not visible', () {
      final listing = TcgMarketplaceListing.fromRow({
        'id': 'sale-2',
        'is_public': true,
        'sale_status': 'active',
        'sale_expires_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      });

      expect(listing.isExpired, isTrue);
      expect(listing.isVisible, isFalse);
      expect(listing.statusLabel, 'Expirada');
    });

    test('calculates Liga percentage with supported rounding modes', () {
      expect(
        TcgMarketplaceListing.calculateLigaPercentagePriceInCents(
          basePrice: 10.50,
          percentage: -10,
          rounding: TcgMarketplaceListing.noRounding,
        ),
        945,
      );
      expect(
        TcgMarketplaceListing.calculateLigaPercentagePriceInCents(
          basePrice: 10.50,
          percentage: -10,
          rounding: TcgMarketplaceListing.roundUp,
        ),
        1000,
      );
      expect(
        TcgMarketplaceListing.calculateLigaPercentagePriceInCents(
          basePrice: 10.50,
          percentage: -10,
          rounding: TcgMarketplaceListing.roundDown,
        ),
        900,
      );
    });
  });
}
