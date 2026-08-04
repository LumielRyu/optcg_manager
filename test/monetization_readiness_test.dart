import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:optcg_manager/core/privacy/cookie_consent.dart';
import 'package:optcg_manager/data/local/hive_boxes.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'tcgbh-cookie-consent-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox(HiveBoxes.appPrefs);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box(HiveBoxes.appPrefs).clear();
  });

  test('new visitors are asked before optional storage is enabled', () {
    final notifier = CookieConsentNotifier();

    expect(notifier.state.showBanner, isTrue);
    expect(notifier.state.consent, isNull);
  });

  test(
    'rejecting optional purposes is persisted with policy version',
    () async {
      final notifier = CookieConsentNotifier();
      await notifier.rejectOptional();

      expect(notifier.state.showBanner, isFalse);
      expect(notifier.state.consent?.analytics, isFalse);
      expect(notifier.state.consent?.personalizedAds, isFalse);

      final restored = CookieConsentNotifier();
      expect(restored.state.showBanner, isFalse);
      expect(restored.state.consent?.analytics, isFalse);
    },
  );

  test('legal navigation and inactive ad infrastructure are present', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    final home = File(
      'lib/features/tcg/tcg_selector_screen.dart',
    ).readAsStringSync();
    final webIndex = File('web/index.html').readAsStringSync();
    final ads = File('web/ads.txt').readAsStringSync();

    for (final route in ['/privacy', '/cookies', '/terms', '/contact']) {
      expect(router, contains("path: '$route'"));
    }
    expect(home, contains("placement: 'home-after-game-list'"));
    expect(webIndex, isNot(contains('adsbygoogle.js')));
    expect(ads, contains('publisher entry will be added only'));
  });
}
