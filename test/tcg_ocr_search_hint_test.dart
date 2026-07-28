import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/tcg/tcg_game.dart';
import 'package:optcg_manager/features/imports/tcg_import/tcg_ocr_search_hint.dart';

void main() {
  group('TcgOcrSearchHint', () {
    test('prioritizes Pokemon printed code', () {
      const text = '''
Pikachu
Basic Pokemon
SV1 - 025
Thunder Shock
''';

      expect(TcgOcrSearchHint.extract(text, TcgGame.pokemon), 'SV1-025');
    });

    test('recognizes Digimon card number', () {
      const text = '''
Agumon
Rookie
BT14-001
On Play
''';

      expect(TcgOcrSearchHint.extract(text, TcgGame.digimon), 'BT14-001');
    });

    test('recognizes Yu-Gi-Oh printing code', () {
      const text = '''
Dark Magician
Spellcaster
LOB-005
ATK 2500 DEF 2100
''';

      expect(TcgOcrSearchHint.extract(text, TcgGame.yugioh), 'LOB-005');
    });

    test('falls back to a title-like card name', () {
      const text = '''
Lightning Bolt
Instant
Lightning Bolt deals 3 damage to any target.
Illustration
''';

      expect(TcgOcrSearchHint.extract(text, TcgGame.magic), 'Lightning Bolt');
    });
  });
}
