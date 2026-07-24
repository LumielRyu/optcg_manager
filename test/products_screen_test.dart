import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:optcg_manager/features/products/products_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('original model previews keep their backgrounds transparent', () async {
    const assets = [
      'plate_1.png',
      'plate_2.png',
      'plate_3.png',
      'plate_3_body.png',
      'plate_3_detail.png',
      'plate_4.png',
      'plate_5.png',
      'plate_6.png',
      'plate_7.png',
    ];
    for (final filename in assets) {
      final data = await rootBundle.load(
        'assets/products/deck_box/model_parts/$filename',
      );
      final decoded = image.decodePng(data.buffer.asUint8List());
      expect(decoded, isNotNull, reason: filename);
      expect(decoded!.getPixel(0, 0).a, 0, reason: filename);
      expect(decoded.any((pixel) => pixel.a > 0), isTrue, reason: filename);
    }
  });

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

  testWidgets('selecting a color updates the piece tint only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();

    final dropdowns = find.byWidgetPredicate(
      (widget) => widget is DropdownButton,
    );
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vermelho').last);
    await tester.pumpAndSettle();

    final bodyModel = find.byKey(const ValueKey('model-part-plate_4.png'));
    final filterFinder = find.descendant(
      of: bodyModel,
      matching: find.byType(ColorFiltered),
    );
    final filter = tester.widget<ColorFiltered>(filterFinder);
    expect(
      filter.colorFilter.toString(),
      const ColorFilter.mode(Color(0xFFC93832), BlendMode.modulate).toString(),
    );
  });
}
