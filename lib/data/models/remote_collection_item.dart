import '../../core/constants/collection_types.dart';
import 'card_record.dart';

class RemoteCollectionItem {
  final String id;
  final String userId;
  final String cardCode;
  final int quantity;
  final String collectionType;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  RemoteCollectionItem({
    required this.id,
    required this.userId,
    required this.cardCode,
    required this.quantity,
    required this.collectionType,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteCollectionItem.fromJson(Map<String, dynamic> json) {
    return RemoteCollectionItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cardCode: json['card_code'] as String,
      quantity: json['quantity'] as int,
      collectionType: json['collection_type'] as String,
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  CardRecord toCardRecord({
    required String name,
    required String imageUrl,
    required String setName,
    required String rarity,
    required String color,
    required String type,
    required String text,
    required String attribute,
  }) {
    return CardRecord(
      id: id,
      cardCode: cardCode,
      name: name,
      imageUrl: imageUrl,
      dateAddedUtc: createdAt,
      setName: setName,
      rarity: rarity,
      color: color,
      type: type,
      text: text,
      attribute: attribute,
      quantity: quantity,
      collectionType: collectionType == CollectionTypes.forSale
          ? CollectionTypes.forSale
          : CollectionTypes.owned,
      isFavorite: isFavorite,
      deckName: null,
    );
  }
}