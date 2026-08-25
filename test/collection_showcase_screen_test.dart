import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/constants/collection_types.dart';
import 'package:optcg_manager/data/models/card_record.dart';
import 'package:optcg_manager/features/collection/collection_screen.dart';

void main() {
  testWidgets('print mode fits the whole folder and can hide controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cards = List<CardRecord>.generate(
      18,
      (index) => CardRecord(
        id: 'card-$index',
        cardCode: 'OP17-${(index + 1).toString().padLeft(3, '0')}',
        name: 'Carta ${index + 1}',
        imageUrl: '',
        dateAddedUtc: DateTime.utc(2026, 8, 25),
        setName: 'OP-17',
        rarity: 'R',
        color: 'Red',
        type: 'Character',
        text: '',
        attribute: 'Strike',
        quantity: index.isEven ? 2 : 1,
        collectionType: CollectionTypes.owned,
        folderId: 'folder-1',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CollectionShowcaseScreen(folderName: 'OP17 ALT', items: cards),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('collection-showcase-grid')), findsOneWidget);
    expect(find.text('OP17 ALT'), findsOneWidget);
    expect(find.text('18 diferentes • 27 cartas'), findsOneWidget);
    for (final card in cards) {
      expect(
        find.byKey(ValueKey('collection-showcase-card-${card.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('collection-showcase-quantity-${card.id}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const Key('collection-showcase-clean-view')));
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('collection-showcase-header')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
