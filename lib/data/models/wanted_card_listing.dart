class WantedCardListing {
  final String id;
  final String ownerUserId;
  final String seekerName;
  final String cardCode;
  final String name;
  final String imageUrl;
  final DateTime createdAtUtc;
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

  const WantedCardListing({
    required this.id,
    required this.ownerUserId,
    required this.seekerName,
    required this.cardCode,
    required this.name,
    required this.imageUrl,
    required this.createdAtUtc,
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
  });

  bool get hasNotes => notes.trim().isNotEmpty;
  bool get hasSeekerName => seekerName.trim().isNotEmpty;
  bool get hasWhatsAppContact => normalizedWhatsAppNumber.isNotEmpty;

  String get normalizedWhatsAppNumber {
    final digits = contactInfo.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('55')) return digits;
    return '55$digits';
  }

  String get statusLabel => isActive ? 'Ativa' : 'Pausada';
}
