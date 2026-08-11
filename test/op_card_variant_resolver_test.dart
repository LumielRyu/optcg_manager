import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/op_card.dart';
import 'package:optcg_manager/data/services/op_card_variant_resolver.dart';

void main() {
  final normal = _card(
    code: 'OP16-108',
    name: 'Shiryu',
    image: 'https://cards.example/op16-108-normal.jpg',
  );
  final fullArt = _card(
    code: 'OP16-108-FA',
    name: 'Shiryu (Full Art)',
    image: 'https://cards.example/op16-108-full-art.jpg',
  );

  test('Full Art replaces a stored normal image for the same base code', () {
    final selected = bestOpCardForStoredIdentity(
      variants: [normal, fullArt],
      cardCode: 'OP16-108',
      storedName: 'Shiryu (Full Art)',
      storedSetName: 'The Time of Battle',
      storedImageUrl: normal.image,
    );

    expect(selected, same(fullArt));
    expect(
      resolvedStoredCardImage(
        cardCode: 'OP16-108',
        storedName: 'Shiryu (Full Art)',
        storedImageUrl: normal.image,
        catalogCard: selected,
      ),
      fullArt.image,
    );
  });

  test('normal printing keeps its own stored image', () {
    final selected = bestOpCardForStoredIdentity(
      variants: [normal, fullArt],
      cardCode: 'OP16-108',
      storedName: 'Shiryu',
      storedSetName: 'The Time of Battle',
      storedImageUrl: normal.image,
    );

    expect(selected, same(normal));
    expect(
      resolvedStoredCardImage(
        cardCode: 'OP16-108',
        storedName: 'Shiryu',
        storedImageUrl: normal.image,
        catalogCard: selected,
      ),
      normal.image,
    );
  });

  test('strict variant never falls back to the normal printing', () {
    final selected = bestOpCardForStoredIdentity(
      variants: [normal],
      cardCode: 'OP16-108',
      storedName: 'Shiryu (Full Art)',
      storedSetName: 'The Time of Battle',
      storedImageUrl: normal.image,
    );

    expect(selected, isNull);
  });

  test('Liga Full Art image is not replaced by a mislabeled catalog image', () {
    const ligaFullArtImage =
        'https://repositorio.sbrauble.com/arquivos/in/onepiece/81/full-art.jpg';
    final mislabeledCatalogCard = _card(
      code: 'OP16-108',
      name: 'Shiryu (Full Art)',
      image: normal.image,
    );

    expect(
      resolvedStoredCardImage(
        cardCode: 'OP16-108',
        storedName: 'Shiryu (Full Art)',
        storedImageUrl: ligaFullArtImage,
        catalogCard: mislabeledCatalogCard,
      ),
      ligaFullArtImage,
    );
  });

  test('stale non-Liga Full Art image can still be repaired by catalog', () {
    expect(
      resolvedStoredCardImage(
        cardCode: 'OP16-108',
        storedName: 'Shiryu (Full Art)',
        storedImageUrl: normal.image,
        catalogCard: fullArt,
      ),
      fullArt.image,
    );
  });
}

OpCard _card({
  required String code,
  required String name,
  required String image,
}) {
  return OpCard(
    code: code,
    name: name,
    image: image,
    setName: 'The Time of Battle',
    rarity: 'SR',
    color: 'Blue',
    type: 'Character',
    subTypes: 'Blackbeard Pirates',
    text: '',
    attribute: 'Slash',
  );
}
