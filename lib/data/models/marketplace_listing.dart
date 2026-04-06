class MarketplaceListing {
  final String id;
  final String cardCode;
  final String name;
  final String imageUrl;
  final DateTime dateAddedUtc;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String text;
  final String attribute;
  final int quantity;
  final bool isFavorite;
  final bool isPublic;
  final String? shareCode;
  final int? priceInCents;
  final String contactInfo;
  final String notes;
  final String saleStatus;
  final String cardCondition;

  const MarketplaceListing({
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
    required this.isFavorite,
    required this.isPublic,
    required this.shareCode,
    required this.priceInCents,
    required this.contactInfo,
    required this.notes,
    required this.saleStatus,
    required this.cardCondition,
  });

  MarketplaceListing copyWith({
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
    bool? isFavorite,
    bool? isPublic,
    String? shareCode,
    int? priceInCents,
    bool clearPrice = false,
    String? contactInfo,
    String? notes,
    String? saleStatus,
    String? cardCondition,
  }) {
    return MarketplaceListing(
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
      isFavorite: isFavorite ?? this.isFavorite,
      isPublic: isPublic ?? this.isPublic,
      shareCode: shareCode ?? this.shareCode,
      priceInCents: clearPrice ? null : (priceInCents ?? this.priceInCents),
      contactInfo: contactInfo ?? this.contactInfo,
      notes: notes ?? this.notes,
      saleStatus: saleStatus ?? this.saleStatus,
      cardCondition: cardCondition ?? this.cardCondition,
    );
  }

  String get formattedPrice {
    final value = priceInCents;
    if (value == null || value <= 0) {
      return 'Sem Pre\u00E7o';
    }

    final reais = value ~/ 100;
    final cents = (value % 100).toString().padLeft(2, '0');
    final whole = reais.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < whole.length; i++) {
      final indexFromEnd = whole.length - i;
      buffer.write(whole[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$cents';
  }

  bool get hasContactInfo => contactInfo.trim().isNotEmpty;
  bool get hasNotes => notes.trim().isNotEmpty;
  bool get hasPrice => (priceInCents ?? 0) > 0;

  bool get isSold => saleStatus == soldStatus;
  bool get isReserved => saleStatus == reservedStatus;
  bool get isActive => saleStatus == activeStatus;

  bool get hasWhatsAppContact => normalizedWhatsAppNumber.isNotEmpty;

  String get normalizedWhatsAppNumber {
    final digits = contactInfo.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('55')) return digits;
    return '55$digits';
  }

  String get whatsappUrl {
    final phone = normalizedWhatsAppNumber;
    if (phone.isEmpty) return '';
    return 'https://wa.me/$phone';
  }

  String get statusLabel {
    switch (saleStatus) {
      case reservedStatus:
        return 'Reservada';
      case soldStatus:
        return 'Vendida';
      default:
        return 'Ativa';
    }
  }

  String get conditionLabel {
    switch (cardCondition) {
      case nearMintCondition:
        return 'Near Mint';
      case lightlyPlayedCondition:
        return 'Light Play';
      case playedCondition:
        return 'Played';
      case damagedCondition:
        return 'Damaged';
      default:
        return 'Mint';
    }
  }

  static const String activeStatus = 'active';
  static const String reservedStatus = 'reserved';
  static const String soldStatus = 'sold';

  static const String mintCondition = 'mint';
  static const String nearMintCondition = 'near_mint';
  static const String lightlyPlayedCondition = 'lightly_played';
  static const String playedCondition = 'played';
  static const String damagedCondition = 'damaged';

  static const List<String> saleStatuses = [
    activeStatus,
    reservedStatus,
    soldStatus,
  ];

  static const List<String> cardConditions = [
    mintCondition,
    nearMintCondition,
    lightlyPlayedCondition,
    playedCondition,
    damagedCondition,
  ];
}
