class CardScanDecision {
  final bool shouldCount;
  final bool waitingForCardRemoval;
  final bool awaitingConfirmation;

  const CardScanDecision({
    required this.shouldCount,
    required this.waitingForCardRemoval,
    this.awaitingConfirmation = false,
  });
}

class CardScanDeduplicator {
  final int emptyScansRequiredToUnlock;
  final int matchingScansRequiredToCount;

  String? _activeCardKey;
  String? _pendingCardKey;
  int _matchingScanCount = 0;
  int _emptyScanCount = 0;

  CardScanDeduplicator({
    this.emptyScansRequiredToUnlock = 2,
    this.matchingScansRequiredToCount = 2,
  });

  String? get activeCardKey => _activeCardKey;

  CardScanDecision registerAutomaticScan(String cardKey) {
    _emptyScanCount = 0;

    if (_activeCardKey == cardKey) {
      _clearPendingCard();
      return const CardScanDecision(
        shouldCount: false,
        waitingForCardRemoval: true,
      );
    }

    if (_pendingCardKey != cardKey) {
      _pendingCardKey = cardKey;
      _matchingScanCount = 1;
      if (matchingScansRequiredToCount <= 1) {
        _activeCardKey = cardKey;
        _clearPendingCard();
        return const CardScanDecision(
          shouldCount: true,
          waitingForCardRemoval: true,
        );
      }
      return CardScanDecision(
        shouldCount: false,
        waitingForCardRemoval: false,
        awaitingConfirmation: true,
      );
    }

    _matchingScanCount++;
    if (_matchingScanCount < matchingScansRequiredToCount) {
      return const CardScanDecision(
        shouldCount: false,
        waitingForCardRemoval: false,
        awaitingConfirmation: true,
      );
    }

    _activeCardKey = cardKey;
    _clearPendingCard();
    return const CardScanDecision(
      shouldCount: true,
      waitingForCardRemoval: true,
    );
  }

  bool markNoCardDetected() {
    _clearPendingCard();
    if (_activeCardKey == null) return false;

    _emptyScanCount++;
    if (_emptyScanCount < emptyScansRequiredToUnlock) return false;

    _activeCardKey = null;
    _emptyScanCount = 0;
    return true;
  }

  void reset() {
    _activeCardKey = null;
    _clearPendingCard();
    _emptyScanCount = 0;
  }

  void _clearPendingCard() {
    _pendingCardKey = null;
    _matchingScanCount = 0;
  }
}
