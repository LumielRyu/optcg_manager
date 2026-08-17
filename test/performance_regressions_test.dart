import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marketplace loads Liga prices in one batched operation', () {
    final source = File(
      'lib/features/marketplace/global_marketplace_screen.dart',
    ).readAsStringSync();

    expect(source, contains('fetchCachedPublicCardSnapshotsForCards'));
    expect(source, contains('OpCardImageCatalog.resolve'));
    expect(source, isNot(contains('fetchCachedPublicCardSnapshotForCard(')));
  });

  test('public Liga reads use the indexed exact-printing key', () {
    final source = File(
      'lib/data/services/liga_one_piece_service.dart',
    ).readAsStringSync();

    expect(source, contains(".inFilter('lookup_code', chunk)"));
    expect(source, contains(".inFilter('lookup_code', queryCodes)"));
    expect(source, isNot(contains(".inFilter('card_code', queryCodes)")));
  });

  test('collection image catalog stays compact and contains durable URLs', () {
    final file = File('assets/one_piece_image_catalog.json');
    final rows = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    final first = Map<String, dynamic>.from(rows.first as Map);

    expect(file.lengthSync(), lessThan(1100 * 1024));
    expect(rows.length, greaterThan(4000));
    expect(first.keys, containsAll(<String>['c', 'n', 'i', 's']));
    expect(first['i'], startsWith('https://'));
  });

  test('web shell allows browser revalidation instead of no-store', () {
    final config = File('vercel.json').readAsStringSync();
    final serviceWorker = File('web/pwa_service_worker.js').readAsStringSync();

    expect(config, contains('public, max-age=0, must-revalidate'));
    expect(config, contains('https://repositorio.sbrauble.com'));
    expect(serviceWorker, contains("cache: 'no-cache'"));
    expect(
      serviceWorker,
      isNot(contains("fetch(request, { cache: 'no-store' }")),
    );
  });
}
