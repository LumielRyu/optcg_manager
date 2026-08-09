import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collection uses a virtualized sliver layout on mobile web', () {
    final source = File(
      'lib/features/collection/collection_screen.dart',
    ).readAsStringSync();

    expect(source, contains('final collectionContent = CustomScrollView('));
    expect(source, contains('_VirtualizedStandardLibraryView('));
    expect(source, contains('_VirtualizedDeckLibraryView('));
    expect(source, contains('sliver: SliverGrid('));
    expect(source, contains('addRepaintBoundaries: false'));
    expect(source, isNot(contains('body: SingleChildScrollView(')));
  });

  test(
    'collection grid limits decoded images and avoids forced HTML views',
    () {
      final source = File(
        'lib/features/collection/collection_screen.dart',
      ).readAsStringSync();

      expect(source, contains('cacheWidth: decodeWidth'));
      expect(
        source,
        contains('webHtmlElementStrategy: WebHtmlElementStrategy.fallback'),
      );
    },
  );

  test('collection exposes one add action with the simplified methods', () {
    final source = File(
      'lib/features/collection/collection_screen.dart',
    ).readAsStringSync();

    expect(
      RegExp(r"label: const Text\('Adicionar cartas'\)").allMatches(source),
      hasLength(1),
    );
    expect(source, contains('Importar carta pela biblioteca'));
    expect(source, contains('Adicionar por código'));
    expect(source, contains('Escanear com câmera • Beta'));
    expect(source, contains('Pastas da coleção'));
    expect(source, contains('LigaCollectionValueText('));
  });

  test('library import accepts either card code or card name', () {
    final source = File(
      'lib/features/collection/manual_add_dialog.dart',
    ).readAsStringSync();

    expect(source, contains("labelText: 'Código ou nome da carta'"));
    expect(source, contains('api.searchCardsByName(query, limit: 40)'));
    expect(source, contains("hintText: 'Ex.: OP02-001 ou Nami'"));
  });
}
