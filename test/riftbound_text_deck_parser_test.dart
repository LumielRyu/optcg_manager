import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/tcg/riftbound_text_deck_parser.dart';
import 'package:optcg_manager/core/tcg/tcg_deck_rules.dart';

void main() {
  const sample = '''
Legend:
1 Master Yi, Wuju Bladesman

Champion:
1 Master Yi, Tempered

MainDeck:
3 Charm
2 Challenge

Battlefields:
1 Emperor's Dais

Runes:
7 Body Rune
5 Calm Rune

Sideboard:
1 Challenge
''';

  test('interpreta todas as seções do formato Piltover Archive', () {
    final result = parseRiftboundTextDeck(sample);

    expect(result.errors, isEmpty);
    expect(result.totalCards, 21);
    expect(
      result.entries
          .firstWhere((entry) => entry.cardName == 'Master Yi, Tempered')
          .zone,
      TcgDeckZone.chosenChampion,
    );
    expect(
      result.entries.firstWhere((entry) => entry.cardName == 'Body Rune').zone,
      TcgDeckZone.resource,
    );
    expect(
      result.entries
          .firstWhere(
            (entry) =>
                entry.cardName == 'Challenge' && entry.zone == TcgDeckZone.side,
          )
          .quantity,
      1,
    );
  });

  test('aceita quantidade com x e agrega nomes repetidos na mesma seção', () {
    final result = parseRiftboundTextDeck('''
Main Deck:
2x Charm
1 Charm
''');

    expect(result.isValid, isTrue);
    expect(result.entries, hasLength(1));
    expect(result.entries.single.quantity, 3);
  });

  test('informa linha inválida ou carta sem seção', () {
    final result = parseRiftboundTextDeck('''
1 Charm
Unknown:
Charm
''');

    expect(result.isValid, isFalse);
    expect(result.errors, hasLength(3));
  });

  test('normaliza pontuação e qualificadores de impressão', () {
    expect(
      normalizeRiftboundBaseCardName('Master Yi - Wuju Bladesman (Starter)'),
      normalizeRiftboundBaseCardName('Master Yi, Wuju Bladesman'),
    );
    expect(
      normalizeRiftboundBaseCardName('Fiora - Peerless (Alternate Art)'),
      normalizeRiftboundBaseCardName('Fiora, Peerless'),
    );
  });

  test('importa a lista completa de 64 cartas do exemplo', () {
    final result = parseRiftboundTextDeck('''
Legend:
1 Master Yi, Wuju Bladesman

Champion:
1 Master Yi, Tempered

MainDeck:
3 Charm
3 Defy
3 Discipline
3 Pit Rookie
3 Sabotage
3 Lonely Poro
3 Punch First
3 Scuttle Crab
2 En Garde
2 Zhonya's Hourglass
2 First Mate
2 Ruin Runner
1 Challenge
1 Primal Strength
3 Rengar, Trophy Hunter
2 Fiora, Peerless

Battlefields:
1 The Arena's Greatest
1 Emperor's Dais
1 Seat of Power

Runes:
7 Body Rune
5 Calm Rune

Sideboard:
3 Disarming Rake
2 Alpha Strike
1 Challenge
1 Ruin Runner
1 Fiora, Peerless
''');

    expect(result.errors, isEmpty);
    expect(result.totalCards, 64);
    final totals = <TcgDeckZone, int>{};
    for (final entry in result.entries) {
      totals.update(
        entry.zone,
        (quantity) => quantity + entry.quantity,
        ifAbsent: () => entry.quantity,
      );
    }
    expect(totals[TcgDeckZone.legend], 1);
    expect(totals[TcgDeckZone.chosenChampion], 1);
    expect(totals[TcgDeckZone.main], 39);
    expect(totals[TcgDeckZone.battlefield], 3);
    expect(totals[TcgDeckZone.resource], 12);
    expect(totals[TcgDeckZone.side], 8);
  });
}
