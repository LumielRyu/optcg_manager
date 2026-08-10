import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/op_card.dart';
import 'package:optcg_manager/data/services/op_api_service.dart';
import 'package:optcg_manager/features/collection/manual_add_dialog.dart';

void main() {
  testWidgets('library results use a scrollable vertical grid', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cards = List<OpCard>.generate(
      60,
      (index) => OpCard(
        code: 'OP01-${index.toString().padLeft(3, '0')}',
        name: 'Nami versão ${index + 1}',
        image: '',
        setName: 'Romance Dawn',
        rarity: 'R',
        color: 'Blue',
        type: 'Character',
        subTypes: 'Straw Hat Crew',
        text: '',
        attribute: 'Special',
      ),
    );

    final api = _FakeOpApiService(cards);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          opApiServiceProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ManualAddDialog()),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Código ou nome da carta'),
      'Nami',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(
      find.text(
        '60 resultados encontrados. Escolha a carta e a arte corretas.',
      ),
      findsOneWidget,
    );
    expect(api.requestedLimit, isNull);
    expect(
      find.textContaining('Use a roda do mouse ou arraste para baixo'),
      findsOneWidget,
    );

    await tester.tap(find.text('Nami versão 1'));
    await tester.pump();

    expect(find.text('Carta selecionada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeOpApiService extends OpApiService {
  final List<OpCard> cards;
  int? requestedLimit = 5;

  _FakeOpApiService(this.cards);

  @override
  Future<void> preload() async {}

  @override
  Future<List<OpCard>> findAllByCode(String code) async => const [];

  @override
  Future<List<OpCard>> searchLibraryCards(
    String query, {
    int? limit,
  }) async {
    requestedLimit = limit;
    return limit == null
        ? List<OpCard>.from(cards)
        : cards.take(limit).toList(growable: false);
  }
}
