class OpCard {
  final String code;
  final String name;
  final String image;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String text;
  final String attribute;

  OpCard({
    required this.code,
    required this.name,
    required this.image,
    required this.setName,
    required this.rarity,
    required this.color,
    required this.type,
    required this.text,
    required this.attribute,
  });

  factory OpCard.fromJson(Map<String, dynamic> json) {
    return OpCard(
      code: (json['card_set_id'] ?? '').toString().trim().toUpperCase(),
      name: (json['card_name'] ?? '').toString().trim(),
      image: (json['card_image'] ?? '').toString().trim(),
      setName: (json['set_name'] ?? '').toString().trim(),
      rarity: (json['rarity'] ?? '').toString().trim(),
      color: (json['card_color'] ?? '').toString().trim(),
      type: (json['card_type'] ?? '').toString().trim(),
      text: _normalizeNullableText(json['card_text']),
      attribute: _normalizeNullableText(json['attribute']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card_set_id': code,
      'card_name': name,
      'card_image': image,
      'set_name': setName,
      'rarity': rarity,
      'card_color': color,
      'card_type': type,
      'card_text': text,
      'attribute': attribute,
    };
  }

  static String _normalizeNullableText(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.toUpperCase() == 'NULL') return '';
    return text;
  }
}
