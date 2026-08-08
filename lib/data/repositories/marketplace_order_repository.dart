import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_order.dart';
import '../services/supabase_client_provider.dart';

final marketplaceOrderRepositoryProvider = Provider<MarketplaceOrderRepository>(
  (ref) => MarketplaceOrderRepository(ref.watch(supabaseClientProvider)),
);

class MarketplaceOrderRepository {
  final SupabaseClient _client;

  const MarketplaceOrderRepository(this._client);

  static const String _orderColumns =
      'id, seller_id, buyer_id, status, buyer_name, buyer_contact, '
      'seller_name, seller_contact, created_at, expires_at, confirmed_at, '
      'resolved_at, marketplace_order_items(id, listing_id, quantity, '
      'unit_price_cents, game_slug, card_code, card_name, image_url, '
      'card_condition)';

  Future<MarketplaceReservationReceipt> reserveItems(
    Map<String, int> quantitiesByListing,
  ) async {
    final items = quantitiesByListing.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
        .map(
          (entry) => {'listing_id': entry.key.trim(), 'quantity': entry.value},
        )
        .toList(growable: false);
    if (items.isEmpty) {
      throw const MarketplaceReservationException(
        'Selecione ao menos uma carta para reservar.',
      );
    }

    try {
      final response = await _client.rpc(
        'reserve_marketplace_items',
        params: {'p_items': items},
      );
      final rows = response as List? ?? const [];
      if (rows.isEmpty) {
        throw const MarketplaceReservationException(
          'O banco não confirmou a criação da reserva.',
        );
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      final orderId = (row['order_id'] ?? '').toString();
      final expiration = DateTime.tryParse(
        (row['reservation_expires_at'] ?? '').toString(),
      )?.toUtc();
      if (orderId.isEmpty || expiration == null) {
        throw const MarketplaceReservationException(
          'A confirmação da reserva veio incompleta.',
        );
      }
      return MarketplaceReservationReceipt(
        orderId: orderId,
        expiresAt: expiration,
      );
    } on MarketplaceReservationException {
      rethrow;
    } on PostgrestException catch (error) {
      throw MarketplaceReservationException(_friendlyMessage(error.message));
    }
  }

  Future<List<MarketplaceOrder>> getSellerOrders({
    bool pendingOnly = true,
    String? gameSlug,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    await _expirePendingOrders();

    var query = _client
        .from('marketplace_orders')
        .select(_orderColumns)
        .eq('seller_id', user.id);
    if (pendingOnly) query = query.eq('status', MarketplaceOrder.pendingStatus);
    final response = await query
        .order('created_at', ascending: false)
        .limit(50);
    return (response as List)
        .map(
          (raw) =>
              MarketplaceOrder.fromMap(Map<String, dynamic>.from(raw as Map)),
        )
        .where((order) => !pendingOnly || order.isPending)
        .where(
          (order) =>
              gameSlug == null ||
              order.items.any((item) => item.gameSlug == gameSlug),
        )
        .toList(growable: false);
  }

  Future<List<MarketplaceOrder>> getBuyerOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    await _expirePendingOrders();

    final response = await _client
        .from('marketplace_orders')
        .select(_orderColumns)
        .eq('buyer_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return (response as List)
        .map(
          (raw) =>
              MarketplaceOrder.fromMap(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(growable: false);
  }

  Future<void> confirmOrder(String orderId) {
    return _resolveOrder(orderId: orderId, action: 'confirm');
  }

  Future<void> rejectOrder(String orderId) {
    return _resolveOrder(orderId: orderId, action: 'reject');
  }

  Future<void> cancelOrder(String orderId) {
    return _resolveOrder(orderId: orderId, action: 'cancel');
  }

  Future<void> _resolveOrder({
    required String orderId,
    required String action,
  }) async {
    try {
      await _client.rpc(
        'resolve_marketplace_order',
        params: {'p_order_id': orderId, 'p_action': action},
      );
    } on PostgrestException catch (error) {
      throw MarketplaceReservationException(_friendlyMessage(error.message));
    }
  }

  Future<void> _expirePendingOrders() async {
    try {
      await _client.rpc('expire_marketplace_orders');
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.code == '42883') return;
      rethrow;
    }
  }

  static String _friendlyMessage(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return 'Não foi possível concluir a reserva. Tente novamente.';
    }
    return normalized;
  }
}

class MarketplaceReservationException implements Exception {
  final String message;

  const MarketplaceReservationException(this.message);

  @override
  String toString() => message;
}
