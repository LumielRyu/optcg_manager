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

  test('heavy routes are split out of the initial JavaScript bundle', () {
    final router = File('lib/app/router.dart').readAsStringSync();

    expect(router, contains('deferred as global_marketplace'));
    expect(router, contains('deferred as products'));
    expect(router, contains('deferred as weekly_dashboard'));
    expect(router, contains('deferred as image_import'));
    expect(router, contains('deferred as op_routes'));
    expect(router, contains('deferred as shared_routes'));
    expect(router, contains('deferred as tcg_routes'));
    expect(router, contains('class _DeferredRoute'));
  });

  test('web bootstrap does not erase caches before starting Flutter', () {
    final entrypoint = File('web/index.html').readAsStringSync();

    expect(entrypoint, contains('loadFlutter();'));
    expect(entrypoint, isNot(contains('resetStaleCaches().finally')));
    expect(entrypoint, isNot(contains('navigator.serviceWorker.getRegistrations')));
    expect(entrypoint, isNot(contains('window.caches.keys')));
  });

  test('marketplace keeps automatic carousels outside the LCP window', () {
    final source = File(
      'lib/features/marketplace/global_marketplace_screen.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'_initialRotationDelay = Duration\(seconds: 60\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'_initialAutoScrollDelay = Duration\(seconds: 60\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains('_rotationInterval = Duration(seconds: 15)'));
    expect(source, contains('_autoScrollInterval = Duration(seconds: 7)'));
  });

  test('web entry preconnects the first marketplace data origins', () {
    final entrypoint = File('web/index.html').readAsStringSync();

    expect(entrypoint, contains('rel="preconnect"'));
    expect(entrypoint, contains('sslfaerultjnjfkivved.supabase.co'));
    expect(entrypoint, contains('pub-b575d68981e0471899723c0f36cb89aa.r2.dev'));
  });

  test('cold-start storage and backend initialization run concurrently', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final hiveSource = File('lib/data/local/hive_init.dart').readAsStringSync();

    expect(mainSource, contains('Future.wait<dynamic>'));
    expect(mainSource, contains('HiveInit.init()'));
    expect(mainSource, contains('Supabase.initialize('));
    expect(hiveSource, contains('Future.wait<Object>'));
  });
}
