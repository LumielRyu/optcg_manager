import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/card_record.dart';
import 'package:optcg_manager/features/decks/widgets/deck_visual_layout.dart';

void main() {
  test('separa a carta Leader do restante do deck', () {
    final leader = _card(
      id: 'leader',
      name: 'Nami',
      code: 'EB03-053',
      type: 'Leader',
    );
    final character = _card(
      id: 'character',
      name: 'Nico Robin',
      code: 'EB03-055',
      quantity: 4,
    );

    final sections = splitDeckVisualSections([
      character,
      leader,
    ], deckName: 'Nami');

    expect(sections.leader?.id, 'leader');
    expect(sections.cards.map((item) => item.id), ['character']);
  });

  test('usa o nome do deck como fallback para listas antigas', () {
    final leader = _card(
      id: 'legacy-leader',
      name: 'Nami (053)',
      code: 'EB03-053',
    );
    final character = _card(
      id: 'other-nami',
      name: 'Nami',
      code: 'OP01-016',
      quantity: 4,
    );

    final sections = splitDeckVisualSections([
      character,
      leader,
    ], deckName: 'Nami');

    expect(sections.leader?.id, 'legacy-leader');
    expect(sections.cards.map((item) => item.id), ['other-nami']);
  });

  testWidgets('mostra o lider principal e quantidades sobre as cartas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeckVisualLayout(
            deckName: 'Nami',
            items: [
              _card(
                id: 'leader',
                name: 'Nami',
                code: 'EB03-053',
                type: 'Leader',
              ),
              _card(
                id: 'character',
                name: 'Nico Robin',
                code: 'EB03-055',
                quantity: 4,
              ),
            ],
            imageBuilder: (_, item) => ColoredBox(
              key: ValueKey('image-${item.id}'),
              color: Colors.blueGrey,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Líder principal'), findsOneWidget);
    expect(find.text('LÍDER'), findsOneWidget);
    expect(find.text('Cartas do deck'), findsOneWidget);
    expect(find.text('4x'), findsOneWidget);
    expect(find.byKey(const ValueKey('image-leader')), findsOneWidget);
    expect(find.byKey(const ValueKey('image-character')), findsOneWidget);
  });
}

CardRecord _card({
  required String id,
  required String name,
  required String code,
  String type = 'Character',
  int quantity = 1,
}) {
  return CardRecord(
    id: id,
    cardCode: code,
    name: name,
    imageUrl: '',
    dateAddedUtc: DateTime.utc(2026),
    setName: 'Extra Booster',
    rarity: 'R',
    color: 'Blue',
    type: type,
    text: '',
    attribute: '',
    quantity: quantity,
    collectionType: 'deck',
    deckName: 'Nami',
  );
}
