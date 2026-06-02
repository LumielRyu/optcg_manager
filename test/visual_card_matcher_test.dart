import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/op_card.dart';
import 'package:optcg_manager/features/imports/image_import/visual_card_matcher.dart';

void main() {
  test('visual catalog keeps the exact alternate art image', () {
    final fallback = OpCard(
      code: 'OP01-001',
      name: 'Roronoa Zoro',
      image: 'https://example.com/regular.jpg',
      setName: 'Romance Dawn',
      rarity: 'L',
      color: 'Red',
      type: 'Leader',
      subTypes: 'Supernovas',
      text: 'fallback text',
      attribute: 'Slash',
    );
    final entry = VisualCardCatalogEntry.fromJson({
      'code': 'OP01-001',
      'name': 'Roronoa Zoro (Parallel)',
      'imageUrl': 'https://example.com/parallel.jpg',
      'setName': 'Romance Dawn',
      'rarity': 'L',
      'color': 'Red',
      'type': 'Leader',
      'fullHash': '0000000000000000',
      'artHash': '0000000000000000',
      'footerHash': '0000000000000000',
      'avgRgb': [1, 2, 3],
    });

    final card = entry.toCard(fallback: fallback);

    expect(card.code, 'OP01-001');
    expect(card.name, 'Roronoa Zoro (Parallel)');
    expect(card.image, 'https://example.com/parallel.jpg');
    expect(card.subTypes, 'Supernovas');
    expect(card.text, 'fallback text');
  });
}
