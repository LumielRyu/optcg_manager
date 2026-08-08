import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/marketplace_order.dart';

void main() {
  test('parses a reservation and calculates quantities and prices', () {
    final order = MarketplaceOrder.fromMap({
      'id': 'order-1',
      'seller_id': 'seller-1',
      'buyer_id': 'buyer-1',
      'status': 'pending',
      'buyer_name': 'Comprador',
      'buyer_contact': '31999999999',
      'seller_name': 'Vendedor',
      'seller_contact': '31888888888',
      'created_at': '2026-08-08T12:00:00Z',
      'expires_at': '2035-08-09T12:00:00Z',
      'marketplace_order_items': [
        {
          'id': 'item-1',
          'listing_id': 'listing-1',
          'quantity': 4,
          'unit_price_cents': 250,
          'game_slug': 'one-piece',
          'card_code': 'OP01-001',
          'card_name': 'Carta X',
          'image_url': 'card.jpg',
          'card_condition': 'mint',
        },
        {
          'id': 'item-2',
          'listing_id': 'listing-2',
          'quantity': 2,
          'unit_price_cents': 500,
          'game_slug': 'one-piece',
          'card_code': 'OP01-002',
          'card_name': 'Carta Y',
          'image_url': 'card-2.jpg',
          'card_condition': 'near_mint',
        },
      ],
    });

    expect(order.isPending, isTrue);
    expect(order.totalCards, 6);
    expect(order.hasCompletePrice, isTrue);
    expect(order.knownTotalInCents, 2000);
    expect(order.items.first.subtotalInCents, 1000);
    expect(order.statusLabel, 'Aguardando vendedor');
  });

  test('treats a pending reservation past its deadline as expired', () {
    final order = MarketplaceOrder.fromMap({
      'id': 'order-2',
      'seller_id': 'seller-1',
      'buyer_id': 'buyer-1',
      'status': 'pending',
      'created_at': '2020-01-01T00:00:00Z',
      'expires_at': '2020-01-02T00:00:00Z',
      'marketplace_order_items': const [],
    });

    expect(order.isPending, isFalse);
    expect(order.isExpired, isTrue);
    expect(order.statusLabel, 'Expirada');
  });

  test('marks a total as incomplete when an item has no price', () {
    final item = MarketplaceOrderItem.fromMap({
      'id': 'item-1',
      'listing_id': null,
      'quantity': 3,
      'unit_price_cents': null,
    });

    expect(item.listingId, isEmpty);
    expect(item.subtotalInCents, isNull);
  });
}
