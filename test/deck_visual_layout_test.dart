import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/card_record.dart';
import 'package:optcg_manager/data/models/op_card.dart';
import 'package:optcg_manager/data/services/op_api_service.dart';
import 'package:optcg_manager/features/decks/widgets/deck_art_allocation_dialog.dart';
import 'package:optcg_manager/features/decks/widgets/deck_import_export_dialog.dart';
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

  test('exporta artes diferentes como uma unica quantidade por codigo', () {
    final export = buildDeckExportText([
      _card(id: 'normal', name: 'Nico Robin', code: 'EB03-055', quantity: 3),
      _card(
        id: 'alternate',
        name: 'Nico Robin (Alternate Art)',
        code: 'EB03-055',
      ),
    ]);

    expect(export, '4xEB03-055');
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

  testWidgets('oferece uma unica distribuicao para artes do mesmo codigo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<CardRecord>? selectedGroup;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeckVisualLayout(
            deckName: 'Nami',
            items: [
              _card(
                id: 'normal',
                name: 'Nico Robin',
                code: 'EB03-055',
                quantity: 3,
              ),
              _card(
                id: 'alternate',
                name: 'Nico Robin (Alternate Art)',
                code: 'EB03-055',
              ),
            ],
            imageBuilder: (_, item) =>
                ColoredBox(color: Colors.blueGrey, child: Text(item.id)),
            onIncrement: (_) async {},
            onDecrement: (_) async {},
            onConfigureArts: (items) async => selectedGroup = items,
          ),
        ),
      ),
    );

    expect(find.text('Distribuir artes'), findsOneWidget);
    await tester.tap(find.text('Distribuir artes'));
    await tester.pump();

    expect(selectedGroup, hasLength(2));
    expect(selectedGroup!.fold<int>(0, (sum, item) => sum + item.quantity), 4);
  });

  testWidgets('distribui quatro copias entre arte normal e alternativa', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          opApiServiceProvider.overrideWithValue(
            _FakeOpApiService([
              _opCard(name: 'Nico Robin', image: 'https://example.com/n.jpg'),
              _opCard(
                name: 'Nico Robin (Alternate Art)',
                image: 'https://example.com/a.jpg',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DeckArtAllocationDialog(
              deckName: 'Nami',
              cardCode: 'EB03-055',
              currentItems: [
                _card(
                  id: 'normal',
                  name: 'Nico Robin',
                  code: 'EB03-055',
                  quantity: 4,
                  imageUrl: 'https://example.com/n.jpg',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 / 4 distribuídas'), findsOneWidget);
    expect(find.text('4x'), findsOneWidget);
    expect(find.text('0x'), findsOneWidget);

    await tester.tap(find.byTooltip('Diminuir').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Aumentar').last);
    await tester.pump();

    expect(find.text('3x'), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('4 / 4 distribuídas'), findsOneWidget);
  });
}

CardRecord _card({
  required String id,
  required String name,
  required String code,
  String type = 'Character',
  int quantity = 1,
  String imageUrl = '',
}) {
  return CardRecord(
    id: id,
    cardCode: code,
    name: name,
    imageUrl: imageUrl,
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

OpCard _opCard({required String name, required String image}) {
  return OpCard(
    code: 'EB03-055',
    name: name,
    image: image,
    setName: 'Extra Booster',
    rarity: 'R',
    color: 'Blue',
    type: 'Character',
    subTypes: 'Straw Hat Crew',
    text: '',
    attribute: '',
  );
}

class _FakeOpApiService extends OpApiService {
  final List<OpCard> variants;

  _FakeOpApiService(this.variants);

  @override
  Future<List<OpCard>> findAllByCode(String code) async => variants;
}
