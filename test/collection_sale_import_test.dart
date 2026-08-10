import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/constants/collection_types.dart';
import 'package:optcg_manager/data/models/card_record.dart';
import 'package:optcg_manager/features/collection/collection_sale_import.dart';

void main() {
  group('importação da coleção para vendas', () {
    test('cria um novo registro de venda copiando os dados da carta', () {
      final source = _card(quantity: 3);
      final now = DateTime.utc(2026, 7, 24, 12);

      final result = buildSaleImportRecord(
        source: source,
        existingSale: null,
        quantity: 2,
        now: now,
        generatedId: 'new-sale',
      );

      expect(result.id, 'new-sale');
      expect(result.collectionType, CollectionTypes.forSale);
      expect(result.quantity, 2);
      expect(result.cardCode, source.cardCode);
      expect(result.imageUrl, source.imageUrl);
      expect(result.name, source.name);
      expect(result.dateAddedUtc, now);
      expect(source.quantity, 3);
    });

    test('incrementa a venda existente sem criar uma duplicata', () {
      final source = _card(quantity: 3);
      final existingSale = _card(
        id: 'existing-sale',
        quantity: 1,
        collectionType: CollectionTypes.forSale,
      );

      expect(
        availableQuantityForSale(source: source, existingSale: existingSale),
        2,
      );

      final result = buildSaleImportRecord(
        source: source,
        existingSale: existingSale,
        quantity: 2,
        now: DateTime.utc(2026, 7, 24),
        generatedId: 'unused',
      );

      expect(result.id, 'existing-sale');
      expect(result.quantity, 3);
      expect(result.collectionType, CollectionTypes.forSale);
    });

    test('impede anunciar mais cópias do que existem na coleção', () {
      final source = _card(quantity: 2);
      final existingSale = _card(
        id: 'existing-sale',
        quantity: 1,
        collectionType: CollectionTypes.forSale,
      );

      expect(
        () => buildSaleImportRecord(
          source: source,
          existingSale: existingSale,
          quantity: 2,
          now: DateTime.utc(2026, 7, 24),
          generatedId: 'unused',
        ),
        throwsArgumentError,
      );
    });

    test('avisa e pede confirmação antes de incrementar uma venda', () {
      final source = File(
        'lib/features/collection/collection_screen.dart',
      ).readAsStringSync();

      expect(source, contains('Carta já está nas vendas'));
      expect(source, contains('já possui'));
      expect(source, contains('Deseja acrescentar mais cartas da coleção?'));
      expect(source, contains("'Adicionar mais'"));
      expect(
        source,
        contains('existingSaleQuantity: existingSale?.quantity ?? 0'),
      );
      expect(source, contains('Agora existem'));
    });
  });
}

CardRecord _card({
  String id = 'owned-card',
  int quantity = 1,
  String collectionType = CollectionTypes.owned,
}) {
  return CardRecord(
    id: id,
    cardCode: 'OP01-001',
    name: 'Roronoa Zoro',
    imageUrl: 'https://example.com/op01-001.png',
    dateAddedUtc: DateTime.utc(2026, 7, 1),
    setName: 'Romance Dawn',
    rarity: 'Leader',
    color: 'Red',
    type: 'Leader',
    text: 'Card text',
    attribute: 'Slash',
    quantity: quantity,
    collectionType: collectionType,
  );
}
