class TcgMarketplaceListing {
  final String id;
  final String ownerUserId;
  final String sellerName;
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
  final int? priceInCents;
  final String notes;
  final String saleStatus;
  final String cardCondition;
  final String pricingMode;
  final double? ligaPercentage;
  final String ligaRounding;
  final int? ligaBasePriceCents;
  final DateTime? ligaPriceUpdatedAt;
  final String ligaPriceSource;
  final DateTime? saleExpiresAt;
  final DateTime createdAt;
  final String? saleFolderId;

  const TcgMarketplaceListing({
    required this.id,
    required this.ownerUserId,
    required this.sellerName,
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
    required this.priceInCents,
    required this.notes,
    required this.saleStatus,
    required this.cardCondition,
    required this.pricingMode,
    required this.ligaPercentage,
    required this.ligaRounding,
    required this.ligaBasePriceCents,
    required this.ligaPriceUpdatedAt,
    required this.ligaPriceSource,
    required this.saleExpiresAt,
    required this.createdAt,
    this.saleFolderId,
  });

  factory TcgMarketplaceListing.fromRow(
    Map<String, dynamic> row, {
    String sellerName = '',
  }) {
    return TcgMarketplaceListing(
      id: (row['id'] ?? '').toString(),
      ownerUserId: (row['user_id'] ?? '').toString(),
      sellerName: sellerName,
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
      priceInCents: (row['sale_price_cents'] as num?)?.toInt(),
      notes: (row['sale_notes'] ?? '').toString(),
      saleStatus: (row['sale_status'] ?? activeStatus).toString(),
      cardCondition: (row['card_condition'] ?? mintCondition).toString(),
      pricingMode: (row['sale_pricing_mode'] ?? manualPricingMode).toString(),
      ligaPercentage: (row['sale_liga_percentage'] as num?)?.toDouble(),
      ligaRounding: (row['sale_liga_rounding'] ?? noRounding).toString(),
      ligaBasePriceCents: (row['sale_liga_base_price_cents'] as num?)?.toInt(),
      ligaPriceUpdatedAt: DateTime.tryParse(
        (row['sale_liga_price_updated_at'] ?? '').toString(),
      ),
      ligaPriceSource: (row['sale_liga_price_source'] ?? '').toString(),
      saleExpiresAt: DateTime.tryParse(
        (row['sale_expires_at'] ?? '').toString(),
      ),
      createdAt:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      saleFolderId: row['sale_folder_id']?.toString(),
    );
  }

  bool get hasPrice => (priceInCents ?? 0) > 0;
  bool get isActive => saleStatus == activeStatus;
  bool get isExpired {
    final expiresAt = saleExpiresAt;
    return expiresAt != null &&
        !expiresAt.toUtc().isAfter(DateTime.now().toUtc());
  }

  bool get isVisible => isPublic && isActive && !isExpired;

  String get formattedPrice => formatCurrency(priceInCents);

  String get conditionLabel => switch (cardCondition) {
    nearMintCondition => 'Near Mint',
    lightlyPlayedCondition => 'Light Play',
    playedCondition => 'Played',
    damagedCondition => 'Damaged',
    _ => 'Mint',
  };

  String get statusLabel => switch (saleStatus) {
    reservedStatus => 'Reservada',
    soldStatus => 'Vendida',
    _ => isExpired ? 'Expirada' : 'Ativa',
  };

  static String formatCurrency(int? cents) {
    if (cents == null || cents <= 0) return 'Sem preço';
    final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $value';
  }

  static int calculateLigaPercentagePriceInCents({
    required double basePrice,
    required double percentage,
    required String rounding,
  }) {
    final rawCents = (basePrice * (1 + percentage / 100) * 100).round();
    return switch (rounding) {
      roundUp when rawCents % 100 != 0 => ((rawCents ~/ 100) + 1) * 100,
      roundDown => (rawCents ~/ 100) * 100,
      _ => rawCents,
    };
  }

  static const activeStatus = 'active';
  static const reservedStatus = 'reserved';
  static const soldStatus = 'sold';
  static const manualPricingMode = 'manual';
  static const ligaPercentagePricingMode = 'liga_percentage';
  static const noRounding = 'none';
  static const roundUp = 'up';
  static const roundDown = 'down';
  static const mintCondition = 'mint';
  static const nearMintCondition = 'near_mint';
  static const lightlyPlayedCondition = 'lightly_played';
  static const playedCondition = 'played';
  static const damagedCondition = 'damaged';

  static const saleStatuses = [activeStatus, reservedStatus, soldStatus];
  static const cardConditions = [
    mintCondition,
    nearMintCondition,
    lightlyPlayedCondition,
    playedCondition,
    damagedCondition,
  ];
}
