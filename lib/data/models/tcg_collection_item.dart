class TcgCollectionItem {
  final String id;
  final String userId;
  final String gameSlug;
  final String catalogCardId;
  final String variantId;
  final String cardCode;
  final String name;
  final String imageUrl;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String text;
  final String attribute;
  final int quantity;
  final bool isFavorite;
  final DateTime createdAt;

  const TcgCollectionItem({
    required this.id,
    required this.userId,
    required this.gameSlug,
    required this.catalogCardId,
    required this.variantId,
    required this.cardCode,
    required this.name,
    required this.imageUrl,
    required this.setName,
    required this.rarity,
    required this.color,
    required this.type,
    required this.text,
    required this.attribute,
    required this.quantity,
    required this.isFavorite,
    required this.createdAt,
  });

  factory TcgCollectionItem.fromJson(Map<String, dynamic> json) {
    return TcgCollectionItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      gameSlug: (json['game_slug'] ?? 'one-piece').toString(),
      catalogCardId: (json['catalog_card_id'] ?? '').toString(),
      variantId: (json['variant_id'] ?? '').toString(),
      cardCode: (json['card_code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      setName: (json['set_name'] ?? '').toString(),
      rarity: (json['rarity'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      attribute: (json['attribute'] ?? '').toString(),
      quantity: int.tryParse((json['quantity'] ?? 1).toString()) ?? 1,
      isFavorite: json['is_favorite'] == true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class TcgCollectionDraft {
  final String gameSlug;
  final String catalogCardId;
  final String variantId;
  final String cardCode;
  final String name;
  final String imageUrl;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String text;
  final String attribute;

  const TcgCollectionDraft({
    required this.gameSlug,
    required this.catalogCardId,
    required this.variantId,
    required this.cardCode,
    required this.name,
    required this.imageUrl,
    required this.setName,
    required this.rarity,
    required this.color,
    required this.type,
    required this.text,
    required this.attribute,
  });

  Map<String, dynamic> toInsertJson(String userId) {
    return {
      'user_id': userId,
      'game_slug': gameSlug,
      'catalog_card_id': catalogCardId,
      'variant_id': variantId,
      'card_code': cardCode,
      'collection_type': 'owned',
      'quantity': 1,
      'is_favorite': false,
      'name': name,
      'image_url': imageUrl,
      'set_name': setName,
      'rarity': rarity,
      'color': color,
      'type': type,
      'text': text,
      'attribute': attribute,
    };
  }
}
