import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/constants/collection_types.dart';
import 'package:optcg_manager/data/models/card_record.dart';
import 'package:optcg_manager/data/repositories/collection_repository.dart';

void main() {
  CardRecord card({
    String id = 'item',
    String code = 'OP17-005',
    String name = 'Edward.Newgate (005)',
    String image = 'https://example.test/op17-005.jpg',
    String setName = "The World's Strongest Warriors",
    String? folderId = 'folder',
    int quantity = 1,
  }) {
    return CardRecord(
      id: id,
      cardCode: code,
      name: name,
      imageUrl: image,
      dateAddedUtc: DateTime.utc(2026),
      setName: setName,
      rarity: 'SR',
      color: 'Red',
      type: 'Character',
      text: '',
      attribute: '',
      quantity: quantity,
      collectionType: CollectionTypes.owned,
      folderId: folderId,
    );
  }

  test('recognizes the same printing despite transient image parameters', () {
    final first = card(image: 'https://example.test/op17-005.jpg?v=1');
    final second = card(
      id: 'second',
      image: 'https://example.test/op17-005.jpg?v=2#cache',
      quantity: 5,
    );

    expect(sameOwnedCollectionPrinting(first, second), isTrue);
    expect(
      ownedCollectionFolderIdentity(first),
      ownedCollectionFolderIdentity(second),
    );
  });

  test('keeps alternate printings and separate folders independent', () {
    final regular = card();
    final alternate = card(
      id: 'alternate',
      name: 'Edward.Newgate (005) (Alternate Art)',
      image: 'https://example.test/op17-005-aa.jpg',
    );
    final anotherFolder = card(id: 'other-folder', folderId: 'other');

    expect(sameOwnedCollectionPrinting(regular, alternate), isFalse);
    expect(
      ownedCollectionFolderIdentity(regular),
      isNot(ownedCollectionFolderIdentity(anotherFolder)),
    );
  });

  test('falls back to normalized card metadata without images', () {
    final first = card(image: '', name: 'Edward.Newgate (005)');
    final second = card(id: 'second', image: '', name: '  EDWARD NEWGATE 005 ');

    expect(sameOwnedCollectionPrinting(first, second), isTrue);
  });
}
