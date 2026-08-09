import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/op_card.dart';

void main() {
  OpCard cardWithColor(String color) => OpCard(
    code: 'EB01-021',
    name: 'Hannyabal',
    image: 'https://example.com/card.jpg',
    setName: 'Extra Booster',
    rarity: 'L',
    color: color,
    type: 'Leader',
    subTypes: 'Impel Down',
    text: '',
    attribute: 'Slash',
  );

  test('recognizes Blue Purple as multicolor', () {
    final card = cardWithColor('Blue Purple');

    expect(card.colorCodes, <String>['blue', 'purple']);
    expect(card.isMulticolor, isTrue);
    expect(card.localizedColor, 'Azul / Roxo');
  });

  test('keeps a single color out of the multicolor group', () {
    final card = cardWithColor('Blue');

    expect(card.colorCodes, <String>['blue']);
    expect(card.isMulticolor, isFalse);
    expect(card.localizedColor, 'Azul');
  });

  test('recognizes every six-color card as multicolor', () {
    final card = cardWithColor('Blue Green Purple Red Black Yellow');

    expect(card.colorCodes, hasLength(6));
    expect(card.isMulticolor, isTrue);
    expect(
      card.localizedColor,
      'Azul / Verde / Roxo / Vermelho / Preto / Amarelo',
    );
  });
}
