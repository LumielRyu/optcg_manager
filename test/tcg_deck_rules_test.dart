import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/tcg/tcg_deck_adapter.dart';
import 'package:optcg_manager/core/tcg/tcg_deck_rules.dart';
import 'package:optcg_manager/core/tcg/tcg_game.dart';
import 'package:optcg_manager/data/models/tcg_deck.dart';

TcgDeckEntry entry({
  required String id,
  required int quantity,
  required TcgDeckZone zone,
  String? name,
  Set<String> identities = const {},
  bool basic = false,
  int? copyLimit,
}) {
  return TcgDeckEntry(
    cardId: id,
    cardNumber: id,
    cardName: name ?? id,
    quantity: quantity,
    zone: zone,
    identities: identities,
    isBasicResource: basic,
    copyLimitOverride: copyLimit,
  );
}

void main() {
  const validator = TcgDeckValidator();

  test('registry exposes every supported TCG and Magic formats', () {
    for (final game in TcgGame.values) {
      expect(TcgDeckRulesRegistry.forGame(game), isNotEmpty);
    }

    expect(
      TcgDeckRulesRegistry.forGame(TcgGame.magic).map((item) => item.slug),
      containsAll(['magic-standard', 'magic-commander']),
    );
  });

  test('One Piece validates deck zones and leader color identity', () {
    final result = validator.validate(
      rules: TcgDeckRulesRegistry.onePieceConstructed,
      context: const TcgDeckValidationContext(allowedIdentities: {'red'}),
      entries: [
        entry(
          id: 'OP-L',
          quantity: 1,
          zone: TcgDeckZone.leader,
          identities: {'red'},
        ),
        entry(
          id: 'OP-MAIN',
          quantity: 50,
          zone: TcgDeckZone.main,
          identities: {'blue'},
          copyLimit: 50,
        ),
        entry(id: 'DON', quantity: 10, zone: TcgDeckZone.resource, basic: true),
      ],
    );

    expect(result.isValid, isFalse);
    expect(
      result.errors.any((error) => error.contains('nao permitida pelo deck')),
      isTrue,
    );
  });

  test('Pokemon accepts 60 basic Energy cards as a copy-limit exception', () {
    final result = validator.validate(
      rules: TcgDeckRulesRegistry.pokemonStandard,
      entries: [
        entry(
          id: 'BASIC-ENERGY',
          name: 'Energia Basica',
          quantity: 60,
          zone: TcgDeckZone.main,
          basic: true,
        ),
      ],
    );

    expect(result.errors, isEmpty);
  });

  test('Digimon keeps the 50-card and Digi-Egg zones separate', () {
    final result = validator.validate(
      rules: TcgDeckRulesRegistry.digimonConstructed,
      entries: [
        entry(
          id: 'BT-MAIN',
          quantity: 50,
          zone: TcgDeckZone.main,
          copyLimit: 50,
        ),
        entry(id: 'EGG-A', quantity: 3, zone: TcgDeckZone.digiEgg),
        entry(id: 'EGG-B', quantity: 2, zone: TcgDeckZone.digiEgg),
      ],
    );

    expect(result.errors, isEmpty);
  });

  test('Magic Commander validates singleton and color identity', () {
    final result = validator.validate(
      rules: TcgDeckRulesRegistry.magicCommander,
      context: const TcgDeckValidationContext(allowedIdentities: {'W', 'U'}),
      entries: [
        entry(
          id: 'PLAINS',
          name: 'Plains',
          quantity: 99,
          zone: TcgDeckZone.main,
          identities: {'W'},
          basic: true,
        ),
        entry(
          id: 'COMMANDER',
          quantity: 1,
          zone: TcgDeckZone.commander,
          identities: {'W', 'U'},
        ),
      ],
    );

    expect(result.errors, isEmpty);
  });

  test('Riftbound accepts only zero or eight sideboard cards', () {
    final result = validator.validate(
      rules: TcgDeckRulesRegistry.riftboundConstructed,
      entries: [
        entry(id: 'MAIN', quantity: 39, zone: TcgDeckZone.main, copyLimit: 39),
        entry(id: 'CHAMPION', quantity: 1, zone: TcgDeckZone.chosenChampion),
        entry(id: 'LEGEND', quantity: 1, zone: TcgDeckZone.legend),
        entry(
          id: 'RUNES',
          quantity: 12,
          zone: TcgDeckZone.resource,
          basic: true,
        ),
        entry(
          id: 'BATTLEFIELDS',
          name: 'Mesmo campo',
          quantity: 3,
          zone: TcgDeckZone.battlefield,
          copyLimit: 3,
        ),
        entry(id: 'SIDE', quantity: 4, zone: TcgDeckZone.side, copyLimit: 4),
      ],
    );

    expect(result.errors.any((error) => error.contains('Side Deck')), isTrue);
    expect(result.errors.any((error) => error.contains('nome unico')), isTrue);
  });

  test('Yu-Gi-Oh applies a current restricted-card snapshot', () {
    final result = validator.validate(
      rules: TcgDeckRulesRegistry.yugiohAdvanced,
      context: const TcgDeckValidationContext(
        restrictedCopiesByCardId: {'LIMITED': 1},
      ),
      entries: [
        entry(
          id: 'LIMITED',
          quantity: 40,
          zone: TcgDeckZone.main,
          copyLimit: 40,
        ),
      ],
    );

    expect(
      result.errors.any((error) => error.contains('limite atual de 1')),
      isTrue,
    );
  });

  test('stored Pokemon Basic Energy becomes a copy-limit exception', () {
    const item = TcgDeckItem(
      id: 'item',
      deckId: 'deck',
      gameSlug: 'pokemon',
      catalogCardId: 'energy',
      variantId: 'energy',
      cardCode: 'POKEMON:SVE:1',
      name: 'Basic Lightning Energy',
      imageUrl: '',
      setName: '',
      rarity: '',
      color: 'Lightning',
      type: 'Energy',
      text: '',
      attribute: 'Basic',
      quantity: 20,
      zone: TcgDeckZone.main,
    );

    final adapted = deckEntryFromItem(item);

    expect(adapted.isBasicResource, isTrue);
    expect(adapted.cardNumber, '1');
  });

  test('Commander identity is derived from the commander printing', () {
    const commander = TcgDeckItem(
      id: 'commander',
      deckId: 'deck',
      gameSlug: 'magic',
      catalogCardId: 'card',
      variantId: 'set:1',
      cardCode: 'MAGIC:SET:1',
      name: 'Commander',
      imageUrl: '',
      setName: '',
      rarity: '',
      color: 'W, U',
      type: 'Legendary Creature',
      text: '',
      attribute: '',
      quantity: 1,
      zone: TcgDeckZone.commander,
    );
    final deck = TcgDeck(
      id: 'deck',
      name: 'Azorius',
      gameSlug: 'magic',
      formatSlug: 'magic-commander',
      createdAt: DateTime.utc(2026),
      items: const [commander],
    );

    final context = validationContextFromDeck(
      deck,
      TcgDeckRulesRegistry.magicCommander,
    );

    expect(context.allowedIdentities, {'W', 'U'});
  });
}
