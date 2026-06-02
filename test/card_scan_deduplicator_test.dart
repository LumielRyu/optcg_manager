import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/features/imports/card_scan_test/card_scan_deduplicator.dart';

void main() {
  test('does not count the same card twice while it remains visible', () {
    final deduplicator = CardScanDeduplicator();

    expect(deduplicator.registerAutomaticScan('P-115').shouldCount, isTrue);
    expect(deduplicator.registerAutomaticScan('P-115').shouldCount, isFalse);
  });

  test('counts the same card again after it leaves the frame', () {
    final deduplicator = CardScanDeduplicator();

    deduplicator.registerAutomaticScan('P-115');
    expect(deduplicator.markNoCardDetected(), isFalse);
    expect(deduplicator.markNoCardDetected(), isTrue);
    expect(deduplicator.registerAutomaticScan('P-115').shouldCount, isTrue);
  });

  test('keeps the lock after a single missed frame', () {
    final deduplicator = CardScanDeduplicator();

    deduplicator.registerAutomaticScan('P-115');
    expect(deduplicator.markNoCardDetected(), isFalse);
    expect(deduplicator.registerAutomaticScan('P-115').shouldCount, isFalse);
  });

  test('counts a different card without requiring an empty frame', () {
    final deduplicator = CardScanDeduplicator();

    deduplicator.registerAutomaticScan('P-115');
    expect(deduplicator.registerAutomaticScan('OP01-001').shouldCount, isTrue);
  });
}
