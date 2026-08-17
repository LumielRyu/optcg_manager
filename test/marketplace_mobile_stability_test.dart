import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String marketplaceSource;
  late String repositorySource;

  setUpAll(() {
    marketplaceSource = File(
      'lib/features/marketplace/global_marketplace_screen.dart',
    ).readAsStringSync();
    repositorySource = File(
      'lib/data/repositories/marketplace_repository.dart',
    ).readAsStringSync();
  });

  test(
    'mobile marketplace virtualizes cards and releases offscreen children',
    () {
      expect(marketplaceSource, contains('_buildMobileEditorialMarketplace('));
      expect(marketplaceSource, contains('scrollable: false'));
      expect(marketplaceSource, contains('child: CustomScrollView('));
      expect(marketplaceSource, contains('sliver: SliverGrid('));
      expect(marketplaceSource, contains('addAutomaticKeepAlives: false'));
      expect(marketplaceSource, contains('addRepaintBoundaries: false'));
    },
  );

  test(
    'marketplace thumbnails use bounded decoding without forced HTML views',
    () {
      expect(marketplaceSource, contains('cacheWidth: decodeWidth'));
      expect(marketplaceSource, contains('filterQuality: FilterQuality.low'));
      expect(
        marketplaceSource,
        contains('webHtmlElementStrategy: WebHtmlElementStrategy.fallback'),
      );
    },
  );

  test('Liga price responses are batched instead of rebuilding every card', () {
    expect(
      marketplaceSource,
      contains('fetchCachedPublicCardSnapshotsForCards'),
    );
    expect(marketplaceSource, contains('_queueLigaPriceRefresh('));
    expect(
      marketplaceSource,
      contains('Timer(const Duration(milliseconds: 120)'),
    );
    expect(marketplaceSource, contains('_ligaPriceRefreshTimer?.cancel();'));
  });

  test('public marketplace and owner sales skip the complete card catalog', () {
    final globalStart = repositorySource.indexOf(
      'Future<List<MarketplaceListing>> getGlobalPublicListings()',
    );
    final globalEnd = repositorySource.indexOf(
      'Future<String> getPublicListingContact',
      globalStart,
    );
    final globalMethod = repositorySource.substring(globalStart, globalEnd);

    final ownerStart = repositorySource.indexOf(
      'Future<List<MarketplaceListing>> getMyListings()',
    );
    final ownerEnd = repositorySource.indexOf(
      'Future<List<MarketplaceListing>> getPublicListingsByUser(',
      ownerStart,
    );
    final ownerMethod = repositorySource.substring(ownerStart, ownerEnd);

    expect(globalMethod, contains('loadCardCatalog: false'));
    expect(ownerMethod, contains('loadCardCatalog: false'));
  });

  test('every primary card browser uses a lazy grid or sliver', () {
    const primaryCardScreens = [
      'lib/features/library/one_piece_library_screen.dart',
      'lib/features/pokemon/pokemon_library_screen.dart',
      'lib/features/digimon/digimon_library_screen.dart',
      'lib/features/magic/magic_library_screen.dart',
      'lib/features/yugioh/yugioh_library_screen.dart',
      'lib/features/riftbound/riftbound_library_screen.dart',
      'lib/features/collection/collection_screen.dart',
      'lib/features/collection/tcg_collection_screen.dart',
      'lib/features/sales/sales_screen.dart',
      'lib/features/sales/tcg_sales_screen.dart',
      'lib/features/wanted/wanted_cards_screen.dart',
      'lib/features/wanted/tcg_wanted_screen.dart',
      'lib/features/marketplace/tcg_marketplace_screen.dart',
      'lib/features/collection/shared_store_screen.dart',
    ];

    for (final path in primaryCardScreens) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('SliverGrid(') || source.contains('GridView.builder('),
        isTrue,
        reason: '$path deve construir somente os cards visiveis',
      );
    }
  });

  test('web app releases decoded images under browser memory pressure', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('class _AppMemoryPressureObserver'));
    expect(source, contains('imageCache.clear();'));
    expect(source, contains('imageCache.clearLiveImages();'));
  });
}
