import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/op_card.dart';
import 'package:optcg_manager/data/services/op_card_image_catalog.dart';

OpCard card(String name, String image, {String setName = 'Test Set'}) {
  return OpCard(
    code: 'OP09-093',
    name: name,
    image: image,
    setName: setName,
    rarity: 'SR',
    color: 'Black',
    type: 'Character',
    subTypes: '',
    text: '',
    attribute: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled R2 mirror for a real reprint', () async {
    final resolved = await OpCardImageCatalog.resolve(
      cardCode: 'EB01-061',
      cardName: 'Mr.2.Bon.Kurei (Bentham) (Reprint)',
      setName: 'Premium Booster -The Best- Vol. 2',
      currentImageUrl:
          'https://www.optcgapi.com/media/static/Card_Images/EB01-061_r1.jpg',
    );

    expect(resolved, startsWith('https://pub-'));
    expect(resolved, contains('/one-piece/EB01-061/'));
  });

  test('selects the durable mirror for the exact stored variant', () {
    final resolved = OpCardImageCatalog.resolveFromCards(
      cards: <OpCard>[
        card('Marshall.D.Teach (093)', 'https://cdn.example/normal.jpg'),
        card(
          'Marshall.D.Teach (093) (Alternate Art)',
          'https://cdn.example/alternate.jpg',
        ),
        card('Marshall.D.Teach (093) (Manga)', 'https://cdn.example/manga.jpg'),
      ],
      cardCode: 'OP09-093',
      cardName: 'Marshall.D.Teach (093) (Alternate Art)',
      setName: 'Test Set',
      currentImageUrl: 'https://www.optcgapi.com/broken.jpg',
    );

    expect(resolved, 'https://cdn.example/alternate.jpg');
  });

  test('keeps the current URL when the mirror has no matching card', () {
    final resolved = OpCardImageCatalog.resolveFromCards(
      cards: <OpCard>[],
      cardCode: 'ST31-004',
      cardName: 'Monkey.D.Luffy',
      setName: 'Starter Deck 31',
      currentImageUrl: 'https://liga.example/st31-004.jpg',
    );

    expect(resolved, 'https://liga.example/st31-004.jpg');
  });
}
