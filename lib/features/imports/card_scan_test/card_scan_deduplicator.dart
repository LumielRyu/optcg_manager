class CardScanDecision {
  final bool shouldCount;
  final bool waitingForCardRemoval;

  const CardScanDecision({
    required this.shouldCount,
    required this.waitingForCardRemoval,
  });
}

class CardScanDeduplicator {
  final int emptyScansRequiredToUnlock;

  String? _activeCardKey;
  int _emptyScanCount = 0;

  CardScanDeduplicator({this.emptyScansRequiredToUnlock = 2});

  String? get activeCardKey => _activeCardKey;

  CardScanDecision registerAutomaticScan(String cardKey) {
    _emptyScanCount = 0;

    if (_activeCardKey == cardKey) {
      return const CardScanDecision(
        shouldCount: false,
        waitingForCardRemoval: true,
      );
    }

    _activeCardKey = cardKey;
    return const CardScanDecision(
      shouldCount: true,
      waitingForCardRemoval: true,
    );
  }

  bool markNoCardDetected() {
    if (_activeCardKey == null) return false;

    _emptyScanCount++;
    if (_emptyScanCount < emptyScansRequiredToUnlock) return false;

    _activeCardKey = null;
    _emptyScanCount = 0;
    return true;
  }

  void reset() {
    _activeCardKey = null;
    _emptyScanCount = 0;
  }
}
