import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scanner hero asset stays within its web budget', () {
    final file = File('assets/editorial/scanner_card_stack.webp');

    expect(file.existsSync(), isTrue);
    expect(
      file.lengthSync(),
      lessThanOrEqualTo(100 * 1024),
      reason: 'The scanner hero is loaded on the main hub and must stay small.',
    );
  });

  test('marketplace hero asset stays within its web budget', () {
    final file = File('assets/editorial/marketplace_hero.webp');

    expect(file.existsSync(), isTrue);
    expect(
      file.lengthSync(),
      lessThanOrEqualTo(150 * 1024),
      reason: 'The marketplace hero is above the fold and must stay small.',
    );
  });
}
