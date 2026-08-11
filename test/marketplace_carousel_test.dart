import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/marketplace/global_marketplace_screen.dart',
    ).readAsStringSync();
  });

  test('featured marketplace card rotates every 15 seconds', () {
    expect(source, contains('class _MarketplaceRotatingFeaturedCard'));
    expect(
      source,
      contains(
        'static const Duration _rotationInterval = Duration(seconds: 15)',
      ),
    );
    expect(source, contains('Timer.periodic(_rotationInterval'));
    expect(source, contains('AnimatedSwitcher('));
    expect(source, contains('troca em 15s'));
  });

  test('spotlight offers use a randomized automatic carousel', () {
    expect(source, contains('class _MarketplaceSpotlightRailState'));
    expect(source, contains('..shuffle(_random)'));
    expect(source, contains('Timer.periodic('));
    expect(source, contains('controller: _scrollController'));
    expect(source, contains("tooltip: 'Ofertas anteriores'"));
    expect(source, contains("tooltip: 'Proximas ofertas'"));
  });

  test('carousel timers and controller are disposed safely', () {
    expect(source, contains('_rotationTimer?.cancel();'));
    expect(source, contains('_autoScrollTimer?.cancel();'));
    expect(source, contains('_scrollController.dispose();'));
  });
}
