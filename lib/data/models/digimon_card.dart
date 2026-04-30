class DigimonCard {
  final String id;
  final String name;
  final String number;
  final String imageUrl;
  final String category;
  final String rarity;
  final String attribute;
  final String type;
  final String form;
  final String effect;
  final String inheritedEffect;
  final String securityEffect;
  final String setName;
  final List<String> colors;
  final int level;
  final int playCost;
  final int dp;

  DigimonCard({
    required this.id,
    required this.name,
    required this.number,
    required this.imageUrl,
    required this.category,
    required this.rarity,
    required this.attribute,
    required this.type,
    required this.form,
    required this.effect,
    required this.inheritedEffect,
    required this.securityEffect,
    required this.setName,
    required this.colors,
    required this.level,
    required this.playCost,
    required this.dp,
  });
}
