import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/constants/collection_types.dart';
import 'package:optcg_manager/data/models/card_record.dart';
import 'package:optcg_manager/features/collection/collection_bulk_sale_import.dart';

void main() {
  CardRecord card({
    required String id,
    required String code,
    required String image,
    required int quantity,
    String collectionType = CollectionTypes.owned,
  }) {
    return CardRecord(
      id: id,
      cardCode: code,
      name: code,
      imageUrl: image,
      dateAddedUtc: DateTime.utc(2026, 8, 8),
      setName: 'Set',
      rarity: 'R',
      color: 'Red',
      type: 'Character',
      text: '',
      attribute: '',
      quantity: quantity,
      collectionType: collectionType,
    );
  }

  test('imports every available copy and preserves an existing listing', () {
    final plan = buildBulkSaleImportPlan(
      sources: [
        card(id: 'owned-1', code: 'OP01-001', image: 'normal.jpg', quantity: 4),
        card(id: 'owned-2', code: 'OP01-002', image: 'second.jpg', quantity: 2),
      ],
      existingSales: [
        card(
          id: 'sale-1',
          code: 'OP01-001',
          image: 'normal.jpg',
          quantity: 1,
          collectionType: CollectionTypes.forSale,
        ),
      ],
      quantityMode: BulkSaleQuantityMode.allAvailable,
      now: DateTime.utc(2026, 8, 8),
      generatedId: (index) => 'generated-$index',
    );

    expect(plan.addedVariantCount, 2);
    expect(plan.totalQuantity, 5);
    expect(plan.records.first.id, 'sale-1');
    expect(plan.records.first.quantity, 4);
    expect(plan.records.last.quantity, 2);
  });

  test('one-per-variant keeps alternate art with the same code separate', () {
    final plan = buildBulkSaleImportPlan(
      sources: [
        card(id: 'owned-1', code: 'OP01-001', image: 'normal.jpg', quantity: 4),
        card(
          id: 'owned-2',
          code: 'OP01-001',
          image: 'parallel.jpg',
          quantity: 3,
        ),
      ],
      existingSales: const [],
      quantityMode: BulkSaleQuantityMode.onePerVariant,
      now: DateTime.utc(2026, 8, 8),
      generatedId: (index) => 'generated-$index',
    );

    expect(plan.addedVariantCount, 2);
    expect(plan.totalQuantity, 2);
    expect(plan.records.map((record) => record.imageUrl), {
      'normal.jpg',
      'parallel.jpg',
    });
  });

  test('skips variants whose complete quantity is already for sale', () {
    final source = card(
      id: 'owned-1',
      code: 'OP01-001',
      image: 'normal.jpg',
      quantity: 2,
    );
    final plan = buildBulkSaleImportPlan(
      sources: [source],
      existingSales: [
        card(
          id: 'sale-1',
          code: source.cardCode,
          image: source.imageUrl,
          quantity: 2,
          collectionType: CollectionTypes.forSale,
        ),
      ],
      quantityMode: BulkSaleQuantityMode.allAvailable,
      now: DateTime.utc(2026, 8, 8),
      generatedId: (index) => 'generated-$index',
    );

    expect(plan.records, isEmpty);
    expect(plan.skippedVariantCount, 1);
    expect(plan.totalQuantity, 0);
  });

  test('collection exposes folder bulk sale review and publication', () {
    final screen = File(
      'lib/features/collection/collection_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/marketplace_repository.dart',
    ).readAsStringSync();

    expect(screen, contains('Vender toda a coleção'));
    expect(screen, contains('Vender esta pasta'));
    expect(screen, contains('Publicar agora no marketplace'));
    expect(screen, contains('Uma cópia de cada carta'));
    expect(repository, contains('enablePublicListingsByIds'));
  });
}
