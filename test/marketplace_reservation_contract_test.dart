import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'sql/marketplace_inventory_reservations.sql',
    ).readAsStringSync();
  });

  test('reservation is atomic and subtracts only locked available stock', () {
    expect(migration, contains('for update;'));
    expect(migration, contains('listing_record.quantity < requested_quantity'));
    expect(migration, contains('set quantity = quantity - requested_quantity'));
    expect(migration, contains("seller_id <> buyer_id"));
  });

  test('cancel, rejection and expiry restore every reserved quantity', () {
    expect(
      RegExp(
        'set quantity = listing\\.quantity \\+ items\\.quantity',
      ).allMatches(migration).length,
      greaterThanOrEqualTo(2),
    );
    expect(migration, contains("normalized_action = 'reject'"));
    expect(migration, contains("normalized_action = 'cancel'"));
    expect(migration, contains("status = 'expired'"));
  });

  test('expiration is scheduled and also checked opportunistically', () {
    expect(migration, contains("interval '24 hours'"));
    expect(migration, contains("'*/5 * * * *'"));
    expect(
      RegExp(
        'perform public\\.expire_marketplace_orders\\(\\);',
      ).allMatches(migration).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('only order participants can read reservations', () {
    expect(migration, contains('(select auth.uid()) in (seller_id, buyer_id)'));
    expect(
      migration,
      contains('(select auth.uid()) in (orders.seller_id, orders.buyer_id)'),
    );
    expect(migration, contains('quantity > 0'));
  });

  test('reservation abuse is limited and buyer contact is required', () {
    expect(migration, contains(') >= 10 then'));
    expect(
      migration,
      contains('Cadastre seu WhatsApp no perfil antes de reservar cartas.'),
    );
  });

  test('pending listings cannot be deleted but resolved history survives', () {
    expect(migration, contains('on delete set null'));
    expect(migration, contains('prevent_pending_marketplace_listing_delete'));
    expect(migration, contains("orders.status = 'pending'"));
  });
}
