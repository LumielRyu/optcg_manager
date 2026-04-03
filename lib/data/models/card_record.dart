import 'package:hive/hive.dart';

part 'card_record.g.dart';

@HiveType(typeId: 1)
class CardRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String cardCode;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String imageUrl;

  @HiveField(4)
  final DateTime dateAddedUtc;

  @HiveField(5)
  final String setName;

  @HiveField(6)
  final String rarity;

  @HiveField(7)
  final String color;

  @HiveField(8)
  final String type;

  @HiveField(9)
  final String text;

  @HiveField(10)
  final String attribute;

  @HiveField(11)
  final int quantity;

  @HiveField(12)
  final String collectionType;

  @HiveField(13)
  final String? deckName;

  @HiveField(14)
  final bool isFavorite;

  CardRecord({
    required this.id,
    required this.cardCode,
    required this.name,
    required this.imageUrl,
    required this.dateAddedUtc,
    required this.setName,
    required this.rarity,
    required this.color,
    required this.type,
    required this.text,
    required this.attribute,
    required this.quantity,
    required this.collectionType,
    this.deckName,
    this.isFavorite = false,
  });

  CardRecord copyWith({
    String? id,
    String? cardCode,
    String? name,
    String? imageUrl,
    DateTime? dateAddedUtc,
    String? setName,
    String? rarity,
    String? color,
    String? type,
    String? text,
    String? attribute,
    int? quantity,
    String? collectionType,
    String? deckName,
    bool? isFavorite,
  }) {
    return CardRecord(
      id: id ?? this.id,
      cardCode: cardCode ?? this.cardCode,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      dateAddedUtc: dateAddedUtc ?? this.dateAddedUtc,
      setName: setName ?? this.setName,
      rarity: rarity ?? this.rarity,
      color: color ?? this.color,
      type: type ?? this.type,
      text: text ?? this.text,
      attribute: attribute ?? this.attribute,
      quantity: quantity ?? this.quantity,
      collectionType: collectionType ?? this.collectionType,
      deckName: deckName ?? this.deckName,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}