import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/card_record.dart';
import 'package:optcg_manager/data/models/collection_folder.dart';

void main() {
  test('collection folder parses Supabase payload', () {
    final folder = CollectionFolder.fromJson({
      'id': 'folder-1',
      'user_id': 'user-1',
      'game_slug': 'one-piece',
      'name': 'Líderes',
      'created_at': '2026-07-31T12:00:00Z',
    });

    expect(folder.id, 'folder-1');
    expect(folder.userId, 'user-1');
    expect(folder.gameSlug, 'one-piece');
    expect(folder.name, 'Líderes');
    expect(folder.createdAt.toUtc(), DateTime.utc(2026, 7, 31, 12));
  });

  test('card record can move to and leave a folder', () {
    final card = CardRecord(
      id: 'card-1',
      cardCode: 'OP01-001',
      name: 'Roronoa Zoro',
      imageUrl: '',
      dateAddedUtc: DateTime.utc(2026, 7, 31),
      setName: 'OP-01',
      rarity: 'L',
      color: 'Red',
      type: 'Leader',
      text: '',
      attribute: 'Slash',
      quantity: 1,
      collectionType: 'owned',
    );

    final filed = card.copyWith(folderId: 'folder-1');
    final unfiled = filed.copyWith(clearFolder: true);

    expect(filed.folderId, 'folder-1');
    expect(unfiled.folderId, isNull);
  });
}
