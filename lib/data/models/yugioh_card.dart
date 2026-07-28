class YugiohCard {
  final int id;
  final String name;
  final String type;
  final String race;
  final String attribute;
  final String archetype;
  final String description;
  final String imageUrl;
  final String largeImageUrl;
  final int level;
  final int attack;
  final int defense;
  final List<YugiohCardPrinting> printings;

  YugiohCard({
    required this.id,
    required this.name,
    required this.type,
    required this.race,
    required this.attribute,
    required this.archetype,
    required this.description,
    required this.imageUrl,
    required this.largeImageUrl,
    required this.level,
    required this.attack,
    required this.defense,
    required this.printings,
  });

  factory YugiohCard.fromJson(Map<String, dynamic> json) {
    final images = (json['card_images'] as List<dynamic>? ?? const []);
    final imageData = images.isNotEmpty && images.first is Map<String, dynamic>
        ? images.first as Map<String, dynamic>
        : const <String, dynamic>{};

    return YugiohCard(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      type: (json['type'] ?? '').toString().trim(),
      race: (json['race'] ?? '').toString().trim(),
      attribute: (json['attribute'] ?? '').toString().trim(),
      archetype: (json['archetype'] ?? '').toString().trim(),
      description: (json['desc'] ?? '').toString().trim(),
      imageUrl:
          (imageData['image_url'] ??
                  imageData['image_url_small'] ??
                  imageData['image_url_cropped'] ??
                  '')
              .toString()
              .trim(),
      largeImageUrl:
          (imageData['image_url'] ??
                  imageData['image_url_small'] ??
                  imageData['image_url_cropped'] ??
                  '')
              .toString()
              .trim(),
      level: (json['level'] as num?)?.toInt() ?? 0,
      attack: (json['atk'] as num?)?.toInt() ?? 0,
      defense: (json['def'] as num?)?.toInt() ?? 0,
      printings: (json['card_sets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(YugiohCardPrinting.fromJson)
          .where((printing) => printing.setCode.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class YugiohCardPrinting {
  final String setName;
  final String setCode;
  final String rarity;

  const YugiohCardPrinting({
    required this.setName,
    required this.setCode,
    required this.rarity,
  });

  factory YugiohCardPrinting.fromJson(Map<String, dynamic> json) {
    return YugiohCardPrinting(
      setName: (json['set_name'] ?? '').toString().trim(),
      setCode: (json['set_code'] ?? '').toString().trim(),
      rarity: (json['set_rarity'] ?? '').toString().trim(),
    );
  }

  String get ligaLookupCode => 'YUGIOH:${setCode.trim().toUpperCase()}';
}
