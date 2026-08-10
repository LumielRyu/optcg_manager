import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/op_card.dart';
import 'package:optcg_manager/data/services/op_api_service.dart';

void main() {
  test('base code returns exact cards and every suffixed variant', () async {
    final cards = <OpCard>[
      for (var index = 0; index < 4; index++)
        _card(code: 'OP09-119', name: 'Monkey.D.Luffy ${index + 1}'),
      _card(code: 'OP09-119-3A', name: 'Monkey.D.Luffy Japanese 1'),
      _card(code: 'OP09-119-3A', name: 'Monkey.D.Luffy Japanese 2'),
      _card(code: 'OP09-118-AA', name: 'Gol.D.Roger'),
    ];
    final service = OpApiService.withCardsForTesting(cards);

    final matches = await service.findAllByCode('OP09-119');

    expect(matches, hasLength(6));
    expect(matches.map((card) => card.code).toSet(), {
      'OP09-119',
      'OP09-119-3A',
    });
    expect((await service.findCardByCode('OP09-119'))?.code, 'OP09-119');
  });

  test('full suffixed code keeps the search limited to that variant', () async {
    final service = OpApiService.withCardsForTesting([
      _card(code: 'OP09-119', name: 'Base'),
      _card(code: 'OP09-119-3A', name: 'Japanese 1'),
      _card(code: 'OP09-119-3A', name: 'Japanese 2'),
    ]);

    final matches = await service.findAllByCode('OP09-119-3A');

    expect(matches, hasLength(2));
    expect(matches.every((card) => card.code == 'OP09-119-3A'), isTrue);
  });

  test('normalizes set, promo and DON suffix formats consistently', () {
    final service = OpApiService.withCardsForTesting(const []);

    expect(service.normalizeCode('OP01-006-AA'), 'OP01-006-AA');
    expect(service.normalizeCode('OP01006AA'), 'OP01-006-AA');
    expect(service.normalizeCode('P-001-SP'), 'P-001-SP');
    expect(service.normalizeCode('DON-001-3A'), 'DON-001-3A');
  });
}

OpCard _card({required String code, required String name}) {
  return OpCard(
    code: code,
    name: name,
    image: '$code-$name.webp',
    setName: 'Test set',
    rarity: 'R',
    color: 'Red',
    type: 'Character',
    subTypes: '',
    text: '',
    attribute: '',
  );
}
