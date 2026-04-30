class MagicCard {
  final String id;
  final String name;
  final String collectorNumber;
  final String imageUrl;
  final String largeImageUrl;
  final String setName;
  final String rarity;
  final String typeLine;
  final String oracleText;
  final String manaCost;
  final String power;
  final String toughness;
  final List<String> colors;

  MagicCard({
    required this.id,
    required this.name,
    required this.collectorNumber,
    required this.imageUrl,
    required this.largeImageUrl,
    required this.setName,
    required this.rarity,
    required this.typeLine,
    required this.oracleText,
    required this.manaCost,
    required this.power,
    required this.toughness,
    required this.colors,
  });

  factory MagicCard.fromJson(Map<String, dynamic> json) {
    final imageUris = (json['image_uris'] as Map<String, dynamic>? ?? const {});

    return MagicCard(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      collectorNumber: (json['collector_number'] ?? '').toString().trim(),
      imageUrl: (imageUris['normal'] ?? imageUris['small'] ?? '')
          .toString()
          .trim(),
      largeImageUrl: (imageUris['large'] ?? imageUris['normal'] ?? '')
          .toString()
          .trim(),
      setName: (json['set_name'] ?? '').toString().trim(),
      rarity: (json['rarity'] ?? '').toString().trim(),
      typeLine: (json['type_line'] ?? '').toString().trim(),
      oracleText: (json['oracle_text'] ?? '').toString().trim(),
      manaCost: (json['mana_cost'] ?? '').toString().trim(),
      power: (json['power'] ?? '').toString().trim(),
      toughness: (json['toughness'] ?? '').toString().trim(),
      colors: (json['colors'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }
}
