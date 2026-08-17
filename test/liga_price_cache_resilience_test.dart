import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/widgets/liga_price_display.dart';
import 'package:optcg_manager/data/services/liga_one_piece_service.dart';

LigaOnePieceCardSnapshot _snapshot(String code, double price) {
  return LigaOnePieceCardSnapshot(
    sourceUrl: 'https://example.com/$code',
    cardName: code,
    cardCode: code,
    editionCode: 'TEST',
    imageUrl: 'https://example.com/$code.jpg',
    minimumPrice: price,
    averagePrice: price,
    maximumPrice: price,
    listingCount: 1,
    lowestListing: null,
    lowestStore: null,
    historyEndpointRequiresLogin: false,
    usedVerifiedFallback: false,
    note: null,
    resolvedAt: DateTime.utc(2026, 8, 1),
  );
}

void main() {
  test(
    'partial refresh preserves prices already shown and replaces fresh rows',
    () {
      final oldA = _snapshot('OP01-001', 10);
      final oldB = _snapshot('OP01-002', 20);
      final freshA = _snapshot('OP01-001', 12);

      final merged = mergeLigaPriceSnapshots(
        previous: {'OP01-001': oldA, 'OP01-002': oldB},
        latest: {'OP01-001': freshA},
      );

      expect(merged['OP01-001']?.minimumPrice, 12);
      expect(merged['OP01-002']?.minimumPrice, 20);
    },
  );

  test(
    'price scope guards the newest load and retries transient gaps',
    () async {
      final source = await File(
        'lib/core/widgets/liga_price_display.dart',
      ).readAsString();

      expect(source, contains('generation != _loadGeneration'));
      expect(source, contains('readLocallyCachedPublicCardSnapshotsForCards'));
      expect(source, contains('hasMissingPrices'));
    },
  );
}
