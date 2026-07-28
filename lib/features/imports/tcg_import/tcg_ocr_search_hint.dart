import '../../../core/tcg/tcg_game.dart';

class TcgOcrSearchHint {
  static String extract(String rawText, TcgGame game) {
    final normalized = rawText.replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.length >= 2)
        .toList(growable: false);

    final codePatterns = switch (game) {
      TcgGame.pokemon => <RegExp>[
        RegExp(r'\b[A-Z]{1,5}\d{0,2}\s*-\s*\d{1,3}\b', caseSensitive: false),
      ],
      TcgGame.digimon => <RegExp>[
        RegExp(
          r'\b(?:BT|EX|ST|P|LM|RB|AD|PB)\d{0,2}\s*-\s*\d{2,3}\b',
          caseSensitive: false,
        ),
      ],
      TcgGame.magic => <RegExp>[
        RegExp(r'\b[A-Z0-9]{2,6}-\d{1,4}[A-Z]?\b', caseSensitive: false),
      ],
      TcgGame.riftbound => <RegExp>[
        RegExp(r'\b[A-Z0-9]{2,8}-\d{1,4}\b', caseSensitive: false),
      ],
      TcgGame.yugioh => <RegExp>[
        RegExp(r'\b[A-Z0-9]{2,8}-[A-Z]{0,4}\d{2,4}\b', caseSensitive: false),
      ],
      TcgGame.onePiece => <RegExp>[
        RegExp(
          r'\b(?:OP|EB|ST|P|PRB)\d{0,2}\s*-\s*\d{3}\b',
          caseSensitive: false,
        ),
      ],
    };

    for (final line in lines) {
      for (final pattern in codePatterns) {
        final match = pattern.firstMatch(line.toUpperCase());
        if (match != null) {
          return (match.group(0) ?? '')
              .replaceAll(RegExp(r'\s*-\s*'), '-')
              .toUpperCase();
        }
      }
    }

    const ignored = {
      'character',
      'trainer',
      'pokemon',
      'basic pokemon',
      'digimon',
      'security',
      'effect',
      'when attacking',
      'on play',
      'instant',
      'sorcery',
      'creature',
      'battlefield',
      'champion',
      'quick effect',
      'attack',
      'defense',
      'illustration',
      'copyright',
    };

    final candidates = lines
        .where((line) {
          final lower = line.toLowerCase();
          if (line.length > 42) return false;
          if (!RegExp(r'[A-Za-zÀ-ÿ]{3}').hasMatch(line)) return false;
          if (RegExp(r'\b\d{3,}\b').hasMatch(line)) return false;
          return !ignored.any(
            (term) => lower == term || lower.startsWith('$term:'),
          );
        })
        .toList(growable: false);

    if (candidates.isEmpty) return '';
    candidates.sort((a, b) {
      final aScore = _nameScore(a);
      final bScore = _nameScore(b);
      return bScore.compareTo(aScore);
    });
    return candidates.first;
  }

  static int _nameScore(String value) {
    var score = 0;
    final words = value.split(' ').where((word) => word.isNotEmpty).length;
    if (words >= 2 && words <= 5) score += 4;
    if (value.length >= 5 && value.length <= 28) score += 3;
    if (!RegExp(r'\d').hasMatch(value)) score += 2;
    if (RegExp(r'^[A-ZÀ-Ý]').hasMatch(value)) score += 1;
    return score;
  }
}
