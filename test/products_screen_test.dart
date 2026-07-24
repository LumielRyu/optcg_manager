import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/features/products/products_screen.dart';

void main() {
  testWidgets('product configurator exposes every customizable group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Monte sua Deck Box One Piece'), findsOneWidget);
    expect(find.text('Cores de cada peça'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is DropdownButton),
      findsNWidgets(8),
    );
    expect(find.text('Base das fichas'), findsOneWidget);
    expect(find.text('Detalhes das fichas'), findsOneWidget);
  });

  testWidgets('product preview switches to the separated-parts view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Peças'));
    await tester.pumpAndSettle();

    expect(find.text('Vista das peças'), findsOneWidget);
  });
}
