import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/data/services/op_api_service.dart',
  ).readAsStringSync();

  test('One Piece catalog cache versions cards and timestamp together', () {
    expect(source, contains("_cachedCardsKey = 'all_cards_v6'"));
    expect(source, contains("_cachedAtKey = 'all_cards_v6_cached_at'"));
    expect(source, contains("'all_cards_v5'"));
    expect(source, contains('box.deleteAll(_legacyCacheKeys)'));
  });

  test('stale catalog refresh finishes before cached cards are returned', () {
    final start = source.indexOf('Future<void> _preloadInternal()');
    final end = source.indexOf('Future<void> _refreshFromApi()', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final preload = source.substring(start, end);
    expect(preload, contains('if (_isDiskCacheStale())'));
    expect(preload, contains('await _refreshFromApi()'));
    expect(preload, isNot(contains('_refreshInBackground')));
  });

  test('catalog freshness window follows the API cache window', () {
    expect(source, contains('Duration _cacheMaxAge = Duration(minutes: 5)'));
  });

  test('web catalog uses HTTP cache and keeps disk as fallback', () {
    final start = source.indexOf('Future<void> _preloadInternal()');
    final end = source.indexOf('Future<void> _refreshFromApi()', start);
    final preload = source.substring(start, end);

    expect(preload, contains('if (kIsWeb)'));
    expect(preload, contains('await _refreshFromApi()'));
    expect(preload, contains('_setMemoryCache(cachedCards)'));
    expect(source, contains("'/api/optcg-cards?catalog=v9'"));
    expect(source, contains('if (!isWebProxy)'));
    expect(source, contains("'Cache-Control': 'no-cache'"));
  });

  test('web shell and reset marker are versioned for OP17 rollout', () {
    final worker = File('web/pwa_service_worker.js').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();

    expect(worker, contains("CACHE_NAME = 'optcg-shell-v6'"));
    expect(index, contains('2026-08-09-one-piece-catalog-v6'));
  });
}
