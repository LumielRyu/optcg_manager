class PokemonCard {
  final String id;
  final String name;
  final String number;
  final String imageUrl;
  final String largeImageUrl;
  final String setName;
  final String rarity;
  final String supertype;
  final List<String> subtypes;
  final List<String> types;
  final String hp;
  final String description;

  PokemonCard({
    required this.id,
    required this.name,
    required this.number,
    required this.imageUrl,
    required this.largeImageUrl,
    required this.setName,
    required this.rarity,
    required this.supertype,
    required this.subtypes,
    required this.types,
    required this.hp,
    required this.description,
  });

  factory PokemonCard.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as Map<String, dynamic>? ?? const {});
    final setData = (json['set'] as Map<String, dynamic>? ?? const {});
    final rules = (json['rules'] as List<dynamic>? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final flavorText = (json['flavorText'] ?? '').toString().trim();

    return PokemonCard(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      number: (json['number'] ?? '').toString().trim(),
      imageUrl: (images['small'] ?? '').toString().trim(),
      largeImageUrl: (images['large'] ?? images['small'] ?? '')
          .toString()
          .trim(),
      setName: (setData['name'] ?? '').toString().trim(),
      rarity: (json['rarity'] ?? '').toString().trim(),
      supertype: (json['supertype'] ?? '').toString().trim(),
      subtypes: (json['subtypes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      types: (json['types'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      hp: (json['hp'] ?? '').toString().trim(),
      description: [
        if (rules.isNotEmpty) rules.join('\n'),
        if (flavorText.isNotEmpty) flavorText,
      ].join('\n\n').trim(),
    );
  }
}
