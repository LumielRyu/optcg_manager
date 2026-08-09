class OpCard {
  static const Map<String, String> _localizedColorLabels = <String, String>{
    'red': 'Vermelho',
    'green': 'Verde',
    'blue': 'Azul',
    'purple': 'Roxo',
    'black': 'Preto',
    'yellow': 'Amarelo',
  };

  final String code;
  final String name;
  final String image;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String subTypes;
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
    required this.subTypes,
    required this.text,
    required this.attribute,
  });

  List<String> get colorCodes {
    final normalized = color.trim().toLowerCase();
    if (normalized.isEmpty) return const <String>[];

    final matches = RegExp(r'[a-z]+')
        .allMatches(normalized)
        .map((match) => match.group(0) ?? '')
        .where(_localizedColorLabels.containsKey);
    return matches.toSet().toList(growable: false);
  }

  bool get isMulticolor {
    final normalized = color.trim().toLowerCase();
    return colorCodes.length > 1 || normalized.contains('multi');
  }

  String get localizedColor {
    final codes = colorCodes;
    if (codes.isEmpty) return color;
    return codes.map((code) => _localizedColorLabels[code]!).join(' / ');
  }

  factory OpCard.fromJson(Map<String, dynamic> json) {
    return OpCard(
      code: (json['card_set_id'] ?? '').toString().trim().toUpperCase(),
      name: (json['card_name'] ?? '').toString().trim(),
      image: (json['card_image'] ?? '').toString().trim(),
      setName: (json['set_name'] ?? '').toString().trim(),
      rarity: (json['rarity'] ?? '').toString().trim(),
      color: (json['card_color'] ?? '').toString().trim(),
      type: (json['card_type'] ?? '').toString().trim(),
      subTypes: _normalizeSubTypes(json['sub_types']),
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
      'sub_types': subTypes,
      'card_text': text,
      'attribute': attribute,
    };
  }

  static String _normalizeNullableText(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.toUpperCase() == 'NULL') return '';
    return text;
  }

  static String _normalizeSubTypes(dynamic value) {
    final text = _normalizeNullableText(value);
    if (text.isEmpty) return '';

    return text
        .split('/')
        .map(_splitKnownSubTypes)
        .where((part) => part.isNotEmpty)
        .join(' / ');
  }

  static String _splitKnownSubTypes(String value) {
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';

    final parts = <String>[];
    var index = 0;

    while (index < text.length) {
      while (index < text.length && text[index] == ' ') {
        index++;
      }
      if (index >= text.length) break;

      String? match;
      for (final subtype in _knownSubTypes) {
        if (!_matchesAtWordBoundary(text, subtype, index)) continue;
        match = subtype;
        break;
      }

      if (match == null) {
        parts.add(text.substring(index).trim());
        break;
      }

      parts.add(match);
      index += match.length;
    }

    return parts.join(' / ');
  }

  static bool _matchesAtWordBoundary(String text, String subtype, int index) {
    if (!text.startsWith(subtype, index)) return false;

    final nextIndex = index + subtype.length;
    return nextIndex == text.length || text[nextIndex] == ' ';
  }

  static const List<String> _knownSubTypes = <String>[
    'The Seven Warlords of the Sea',
    'The Owner of Cindry\'s Shadow',
    'Monkey Mountain Alliance',
    'The Flying Fish Riders',
    'New Giant Pirate Crew',
    'Animal Kingdom Pirates',
    'Red-Haired Pirates',
    'Whitebeard Pirates',
    'Blackbeard Pirates',
    'The Four Emperors',
    'Thriller Bark Pirates',
    'Donquixote Pirates',
    'Revolutionary Army',
    'Former Whitebeard Pirates',
    'Beautiful Pirates',
    'Biological Weapon',
    'Golden Lion Pirates',
    'Shandian Warrior',
    'The Vinsmoke Family',
    'Kingdom of Prodence',
    'Galley-La Company',
    'Big Mom Pirates',
    'Straw Hat Crew',
    'The Akazaya Nine',
    'The Tontattas',
    'The Sun Pirates',
    'World Government',
    'Former Rocks Pirates',
    'Former Roger Pirates',
    'Former Baroque Works',
    'Former Arlong Pirates',
    'New Fish-Man Pirates',
    'Jailer Beast',
    'Kouzuki Clan',
    'Kurozumi Clan',
    'The House of Lambs',
    'The Pirates Fest',
    'The Victims\' Club',
    'Five Elders',
    'Muggy Kingdom',
    'Water Seven',
    'Land of Wano',
    'Fish-Man Island',
    'East Blue',
    'Sky Island',
    'Punk Hazard',
    'Whole Cake Island',
    'Drum Kingdom',
    'Goa Kingdom',
    'Frost Moon Village',
    'Long Ring Long Land',
    'Sabaody Archipelago',
    'Baterilla',
    'Bowin Island',
    'Crown Island',
    'Asuka Island',
    'Mecha Island',
    'Omatsuri Island',
    'Shipbuilding Town',
    'Foolshout Island',
    'Fish-Man',
    'Supernovas',
    'Heart Pirates',
    'Kid Pirates',
    'Drake Pirates',
    'Hawkins Pirates',
    'Barto Club',
    'Firetank Pirates',
    'Caribou Pirates',
    'Fallen Monk Pirates',
    'Kuja Pirates',
    'Buggy Pirates',
    'Arlong Pirates',
    'Krieg Pirates',
    'Foxy Pirates',
    'Black Cat Pirates',
    'Alvida Pirates',
    'Gasparde Pirates',
    'Eldoraggo Crew',
    'Jellyfish Pirates',
    'Trump Pirates',
    'Rolling Pirates',
    'Rumbar Pirates',
    'Spade Pirates',
    'Treasure Pirates',
    'World Pirates',
    'Bellamy Pirates',
    'Bonney Pirates',
    'Cross Guild',
    'Buggy\'s Delivery',
    'Happosui Army',
    'Yonta Maria Fleet',
    'The Franky Family',
    'Bluejam Pirates',
    'Gyro Pirates',
    'Peachbeard Pirates',
    'Blackbeard Pirates Allies',
    'Whitebeard Pirates Allies',
    'Mountain Bandits',
    'Baroque Works',
    'Minks',
    'Merfolk',
    'Giant',
    'Navy',
    'Former Navy',
    'Neo Navy',
    'SWORD',
    'CP0',
    'CP6',
    'CP7',
    'CP8',
    'CP9',
    'Former CP9',
    'Celestial Dragons',
    'Scientist',
    'Botanist',
    'Journalist',
    'Neptunian',
    'Homies',
    'Lunarian',
    'Seraphim',
    'Plague',
    'SMILE',
    'Smile',
    'ODYSSEY',
    'FILM',
    'Film',
    'Music',
    'Dressrosa',
    'Alabasta',
    'Impel Down',
    'Egghead',
    'Jaya',
    'Ohara',
    'Mary Geoise',
    'Amazon Lily',
    'Flevance',
    'Lulucia Kingdom',
    'Wano Country',
    'Windmill Village',
    'The Moon',
    'GERMA 66',
    'Accino Family',
    'Alchemi',
    'Evil Black',
    'Fake Straw Hat Crew',
    'Monsters',
    'Sprite',
    'Sniper Island',
    'Weevil\'s Mother',
    'Animal',
  ];
}
