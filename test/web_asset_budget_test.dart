import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scanner hero asset stays within its web budget', () {
    final file = File('assets/editorial/scanner_card_stack.png');

    expect(file.existsSync(), isTrue);
    expect(
      file.lengthSync(),
      lessThanOrEqualTo(750 * 1024),
      reason: 'The scanner hero is loaded on the main hub and must stay small.',
    );
  });
}
