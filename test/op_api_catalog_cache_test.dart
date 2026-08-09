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
}
