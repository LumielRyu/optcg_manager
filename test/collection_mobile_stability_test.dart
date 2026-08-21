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
      expect(source, contains('Duration(milliseconds: 800)'));
      expect(source, contains("'Tentando carregar imagem...'"));
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

  test(
    'collection folders remain horizontally accessible in narrow windows',
    () {
      final source = File(
        'lib/features/collection/collection_screen.dart',
      ).readAsStringSync();

      expect(source, contains("Key('collection-folders-strip')"));
      expect(source, contains('PointerDeviceKind.mouse'));
      expect(source, contains('PointerDeviceKind.trackpad'));
      expect(source, contains('thumbVisibility: true'));
      expect(source, contains('_handleFolderPointerSignal'));
      expect(source, contains('_scrollFolders(1)'));
      expect(source, contains('Deslize ou arraste para ver mais pastas'));
    },
  );

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

  test('sales search and metrics avoid repeated full-page work', () {
    final source = File(
      'lib/features/sales/sales_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Timer(const Duration(milliseconds: 220)'));
    expect(source, contains('_cachedSaleMetrics = _saleMetricsSnapshot'));
    expect(source, contains('Map.unmodifiable(byFolder)'));
    expect(source, isNot(contains('itemsSignature')));
  });

  test('sales mobile header is compact and prices remain visible', () {
    final source = File(
      'lib/features/sales/sales_screen.dart',
    ).readAsStringSync();
    final foldersSource = File(
      'lib/features/sales/widgets/sale_folders_section.dart',
    ).readAsStringSync();

    expect(source, contains("'Resumo das vendas'"));
    expect(source, contains("'Recolher resumo'"));
    expect(source, contains('class _CompactSalesStat'));
    expect(source, contains('footer: _SalesCardFooter(card: item)'));
    expect(source, contains("'Carregando suas vendas...'"));
    expect(foldersSource, contains('width: compact ? 178 : 205'));
    expect(foldersSource, contains("tooltip: 'Nova pasta'"));
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

  test('public store does not wait for the complete card catalog', () {
    final source = File(
      'lib/data/repositories/marketplace_repository.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf(
      'Future<List<MarketplaceListing>> getPublicListingsByUser(',
    );
    final methodEnd = source.indexOf(
      'Future<List<MarketplaceListing>> getGlobalPublicListings()',
      methodStart,
    );
    final method = source.substring(methodStart, methodEnd);

    expect(method, contains('_selectListingRows('));
    expect(method, contains('_warmUpSellerNames({userId})'));
    expect(method, contains('final rowsFuture ='));
    expect(method, contains('final sellerFuture ='));
    expect(method, contains('final rows = await rowsFuture;'));
    expect(method, contains('await sellerFuture;'));
    expect(method, isNot(contains('_fetchListings(')));
    expect(method, isNot(contains('_opApi.preload()')));
  });
}
