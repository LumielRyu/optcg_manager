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

  test('collection distinguishes initial loading from an empty result', () {
    final source = File(
      'lib/features/collection/collection_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Carregando sua cole\\u00e7\\u00e3o...'));
    expect(
      source,
      contains('Cartas carregadas. Atualizando imagens e detalhes...'),
    );
    expect(source, contains('CollectionLoadPhase.initial'));
    expect(source, contains('CollectionLoadPhase.details'));
  });

  test('sales uses virtualized slivers and memory-sized thumbnails', () {
    final source = File(
      'lib/features/sales/sales_screen.dart',
    ).readAsStringSync();

    expect(source, contains('return CustomScrollView('));
    expect(source, contains('sliver: SliverGrid('));
    expect(source, contains('addAutomaticKeepAlives: false'));
    expect(source, contains('cacheWidth: decodeWidth'));
    expect(
      source,
      contains('webHtmlElementStrategy: WebHtmlElementStrategy.fallback'),
    );
    expect(source, isNot(contains('return SingleChildScrollView(')));
    expect(source, isNot(contains('shrinkWrap: true')));
  });

  test('web image cache has a conservative memory ceiling', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('imageCache.maximumSize = 120'));
    expect(source, contains('imageCache.maximumSizeBytes = 48 * 1024 * 1024'));
  });

  test('library import accepts either card code or card name', () {
    final source = File(
      'lib/features/collection/manual_add_dialog.dart',
    ).readAsStringSync();

    expect(source, contains("labelText: 'Código ou nome da carta'"));
    expect(source, contains('api.searchLibraryCards(query)'));
    expect(source, isNot(contains('limit: 40')));
    expect(source, contains("hintText: 'Ex.: OP02-001 ou Nami'"));
  });

  test('sales import notice expires and opens the sales route safely', () {
    final source = File(
      'lib/features/collection/collection_screen.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'_showSalesImportSnackBar\(').allMatches(source),
      hasLength(3),
    );
    expect(source, contains('duration: const Duration(seconds: 5)'));
    expect(source, contains('persist: false'));
    expect(source, contains('messenger.removeCurrentSnackBar('));
    expect(source, contains("router.go('/sales')"));
  });

  test('public store scrolls its header together with the card grid', () {
    final source = File(
      'lib/features/collection/shared_store_screen.dart',
    ).readAsStringSync();

    expect(source, contains('return NestedScrollView('));
    expect(source, contains('headerSliverBuilder: (_, _) => ['));
    expect(
      RegExp(r'SliverToBoxAdapter\(').allMatches(source),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(source, contains('body: items.isEmpty'));
    expect(source, contains('return GridView.builder('));
    expect(source, isNot(contains('child: items.isEmpty')));
  });

  test('public store offers a clear route back to the TCG BH home', () {
    final source = File(
      'lib/features/collection/shared_store_screen.dart',
    ).readAsStringSync();

    expect(source, contains("context.go('/home')"));
    expect(source, contains("label: const Text('Ir para o TCG BH')"));
    expect(source, contains("tooltip: 'Ir para o TCG BH'"));
  });
}
