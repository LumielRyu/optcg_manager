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
      if (filename == 'plate_3_detail.png') {
        expect(
          decoded.where((pixel) => pixel.a > 128).length,
          greaterThan(500),
          reason: 'A escrita e a linha das fichas precisam formar uma camada.',
        );
      }
    }
  });

  test('every token detail variant contains its requested color', () async {
    const colors = <String, (int, int, int)>{
      'preto': (0x17, 0x19, 0x1D),
      'branco': (0xF1, 0xF0, 0xE9),
      'verde': (0x23, 0x8A, 0x52),
      'amarelo': (0xF1, 0xC6, 0x2E),
      'azul': (0x24, 0x58, 0xB8),
      'azul_claro': (0x83, 0xCE, 0xE4),
      'vermelho': (0xC9, 0x38, 0x32),
      'roxo': (0x74, 0x40, 0xA7),
      'laranja': (0xE8, 0x75, 0x25),
      'marrom': (0x76, 0x50, 0x3A),
      'rosa': (0xE5, 0x6F, 0x9F),
    };
    for (final entry in colors.entries) {
      final data = await rootBundle.load(
        'assets/products/deck_box/model_parts/'
        'plate_3_detail_${entry.key}.png',
      );
      final decoded = image.decodePng(data.buffer.asUint8List());
      expect(decoded, isNotNull, reason: entry.key);
      final (red, green, blue) = entry.value;
      expect(
        decoded!.any(
          (pixel) =>
              pixel.a > 128 &&
              (pixel.r - red).abs() <= 1 &&
              (pixel.g - green).abs() <= 1 &&
              (pixel.b - blue).abs() <= 1,
        ),
        isTrue,
        reason: entry.key,
      );
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
    final imageFinder = find.descendant(
      of: bodyModel,
      matching: find.byType(Image),
    );
    final renderedImage = tester.widget<Image>(imageFinder);
    expect(
      (renderedImage.image as AssetImage).assetName,
      endsWith('plate_4_vermelho.png'),
    );
  });

  testWidgets('token detail color updates its own rendered layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();

    final dropdowns = find.byWidgetPredicate(
      (widget) => widget is DropdownButton,
    );
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Azul claro').last);
    await tester.pumpAndSettle();

    final detailModel = find.byKey(const ValueKey('model-part-plate-3-detail'));
    final renderedImage = tester.widget<Image>(
      find.descendant(of: detailModel, matching: find.byType(Image)),
    );
    expect(
      (renderedImage.image as AssetImage).assetName,
      endsWith('plate_3_detail_azul_claro.png'),
    );
  });
}
