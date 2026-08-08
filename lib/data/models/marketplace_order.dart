class MarketplaceOrderItem {
  final String id;
  final String listingId;
  final int quantity;
  final int? unitPriceInCents;
  final String gameSlug;
  final String cardCode;
  final String cardName;
  final String imageUrl;
  final String cardCondition;

  const MarketplaceOrderItem({
    required this.id,
    required this.listingId,
    required this.quantity,
    required this.unitPriceInCents,
    required this.gameSlug,
    required this.cardCode,
    required this.cardName,
    required this.imageUrl,
    required this.cardCondition,
  });

  factory MarketplaceOrderItem.fromMap(Map<String, dynamic> map) {
    return MarketplaceOrderItem(
      id: (map['id'] ?? '').toString(),
      listingId: (map['listing_id'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPriceInCents: (map['unit_price_cents'] as num?)?.toInt(),
      gameSlug: (map['game_slug'] ?? 'one-piece').toString(),
      cardCode: (map['card_code'] ?? '').toString(),
      cardName: (map['card_name'] ?? '').toString(),
      imageUrl: (map['image_url'] ?? '').toString(),
      cardCondition: (map['card_condition'] ?? 'mint').toString(),
    );
  }

  int? get subtotalInCents {
    final price = unitPriceInCents;
    return price == null ? null : price * quantity;
  }
}

class MarketplaceOrder {
  final String id;
  final String sellerId;
  final String buyerId;
  final String status;
  final String buyerName;
  final String buyerContact;
  final String sellerName;
  final String sellerContact;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? confirmedAt;
  final DateTime? resolvedAt;
  final List<MarketplaceOrderItem> items;

  const MarketplaceOrder({
    required this.id,
    required this.sellerId,
    required this.buyerId,
    required this.status,
    required this.buyerName,
    required this.buyerContact,
    required this.sellerName,
    required this.sellerContact,
    required this.createdAt,
    required this.expiresAt,
    required this.confirmedAt,
    required this.resolvedAt,
    required this.items,
  });

  factory MarketplaceOrder.fromMap(Map<String, dynamic> map) {
    final rawItems = map['marketplace_order_items'] as List? ?? const [];
    return MarketplaceOrder(
      id: (map['id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      buyerId: (map['buyer_id'] ?? '').toString(),
      status: (map['status'] ?? pendingStatus).toString(),
      buyerName: (map['buyer_name'] ?? '').toString(),
      buyerContact: (map['buyer_contact'] ?? '').toString(),
      sellerName: (map['seller_name'] ?? '').toString(),
      sellerContact: (map['seller_contact'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      expiresAt:
          DateTime.tryParse((map['expires_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      confirmedAt: DateTime.tryParse(
        (map['confirmed_at'] ?? '').toString(),
      )?.toUtc(),
      resolvedAt: DateTime.tryParse(
        (map['resolved_at'] ?? '').toString(),
      )?.toUtc(),
      items: rawItems
          .map(
            (raw) => MarketplaceOrderItem.fromMap(
              Map<String, dynamic>.from(raw as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  bool get isPending => status == pendingStatus && !isExpired;
  bool get isConfirmed => status == confirmedStatus;
  bool get isCancelled => status == cancelledStatus;
  bool get isExpired =>
      status == expiredStatus ||
      (status == pendingStatus && !expiresAt.isAfter(DateTime.now().toUtc()));

  int get totalCards => items.fold(0, (sum, item) => sum + item.quantity);
  bool get hasCompletePrice =>
      items.every((item) => item.unitPriceInCents != null);
  int get knownTotalInCents =>
      items.fold(0, (sum, item) => sum + (item.subtotalInCents ?? 0));

  String get statusLabel {
    if (isExpired) return 'Expirada';
    switch (status) {
      case confirmedStatus:
        return 'Confirmada';
      case cancelledStatus:
        return 'Cancelada';
      default:
        return 'Aguardando vendedor';
    }
  }

  String get remainingLabel {
    if (!isPending) return statusLabel;
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining.inHours >= 1) {
      final hours = remaining.inHours;
      return hours == 1 ? 'Expira em 1 hora' : 'Expira em $hours horas';
    }
    final minutes = remaining.inMinutes.clamp(1, 59);
    return minutes == 1 ? 'Expira em 1 minuto' : 'Expira em $minutes minutos';
  }

  static const String pendingStatus = 'pending';
  static const String confirmedStatus = 'confirmed';
  static const String cancelledStatus = 'cancelled';
  static const String expiredStatus = 'expired';
}

class MarketplaceReservationReceipt {
  final String orderId;
  final DateTime expiresAt;

  const MarketplaceReservationReceipt({
    required this.orderId,
    required this.expiresAt,
  });
}
