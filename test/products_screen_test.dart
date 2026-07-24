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

  testWidgets('product preview uses the original separated model views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Peças originais do arquivo 3MF'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('model-part-plate_1.png')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('model-part-plate-3-body')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('model-part-plate-3-detail')),
      findsOneWidget,
    );
    expect(find.text('Montada'), findsNothing);
  });
}
