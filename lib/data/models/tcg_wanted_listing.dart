class TcgWantedListing {
  final String id;
  final String ownerUserId;
  final String seekerName;
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
  final bool isPublic;
  final bool isActive;
  final String contactInfo;
  final String notes;
  final DateTime createdAt;

  const TcgWantedListing({
    required this.id,
    required this.ownerUserId,
    required this.seekerName,
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
    required this.isPublic,
    required this.isActive,
    required this.contactInfo,
    required this.notes,
    required this.createdAt,
  });

  factory TcgWantedListing.fromRow(
    Map<String, dynamic> row, {
    String seekerName = '',
  }) {
    return TcgWantedListing(
      id: (row['id'] ?? '').toString(),
      ownerUserId: (row['user_id'] ?? '').toString(),
      seekerName: seekerName,
      gameSlug: (row['game_slug'] ?? 'one-piece').toString(),
      catalogCardId: (row['catalog_card_id'] ?? '').toString(),
      variantId: (row['variant_id'] ?? '').toString(),
      cardCode: (row['card_code'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      imageUrl: (row['image_url'] ?? '').toString(),
      setName: (row['set_name'] ?? '').toString(),
      rarity: (row['rarity'] ?? '').toString(),
      color: (row['color'] ?? '').toString(),
      type: (row['type'] ?? '').toString(),
      text: (row['text'] ?? '').toString(),
      attribute: (row['attribute'] ?? '').toString(),
      quantity: int.tryParse((row['quantity'] ?? 1).toString()) ?? 1,
      isPublic: row['is_public'] == true,
      isActive: row['is_active'] != false,
      contactInfo: (row['contact_info'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  String get normalizedWhatsAppNumber {
    final digits = contactInfo.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return digits.startsWith('55') ? digits : '55$digits';
  }

  bool get hasWhatsAppContact => normalizedWhatsAppNumber.isNotEmpty;
  String get statusLabel => isActive ? 'Ativa' : 'Pausada';
}
