import '../../core/tcg/tcg_deck_rules.dart';

class TcgDeck {
  final String id;
  final String name;
  final String gameSlug;
  final String formatSlug;
  final DateTime createdAt;
  final List<TcgDeckItem> items;

  const TcgDeck({
    required this.id,
    required this.name,
    required this.gameSlug,
    required this.formatSlug,
    required this.createdAt,
    required this.items,
  });

  factory TcgDeck.fromJson(Map<String, dynamic> json) {
    final rawItems = json['deck_items'] as List<dynamic>? ?? const [];
    return TcgDeck(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      gameSlug: (json['game_slug'] ?? 'one-piece').toString(),
      formatSlug: (json['format_slug'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TcgDeckItem.fromJson)
          .toList(growable: false),
    );
  }

  int quantityInZone(TcgDeckZone zone) => items
      .where((item) => item.zone == zone)
      .fold(0, (total, item) => total + item.quantity);
}

class TcgDeckItem {
  final String id;
  final String deckId;
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
  final TcgDeckZone zone;

  const TcgDeckItem({
    required this.id,
    required this.deckId,
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
    required this.zone,
  });

  factory TcgDeckItem.fromJson(Map<String, dynamic> json) {
    final zoneValue = (json['deck_zone'] ?? 'main').toString();
    final zone = TcgDeckZone.values.firstWhere(
      (item) => item.name == zoneValue,
      orElse: () => TcgDeckZone.main,
    );
    return TcgDeckItem(
      id: (json['id'] ?? '').toString(),
      deckId: (json['deck_id'] ?? '').toString(),
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
      zone: zone,
    );
  }
}
