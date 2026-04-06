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
    );
  }

  String get formattedPrice {
    final value = priceInCents;
    if (value == null || value <= 0) {
      return 'Sem preco';
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
}
