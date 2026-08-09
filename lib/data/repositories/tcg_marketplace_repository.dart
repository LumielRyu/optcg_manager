import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tcg_collection_item.dart';
import '../models/tcg_marketplace_listing.dart';
import '../services/liga_tcg_price_service.dart';
import '../services/supabase_client_provider.dart';
import 'user_preferences_repository.dart';

final tcgMarketplaceRepositoryProvider = Provider<TcgMarketplaceRepository>((
  ref,
) {
  return TcgMarketplaceRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(userPreferencesRepositoryProvider),
    ref.watch(ligaTcgPriceServiceProvider),
  );
});

class TcgMarketplaceRepository {
  static const _columns =
      'id, user_id, game_slug, catalog_card_id, variant_id, card_code, '
      'quantity, is_public, created_at, image_url, name, set_name, rarity, '
      'color, type, text, attribute, sale_price_cents, sale_notes, '
      'sale_status, card_condition, sale_expires_at, sale_pricing_mode, '
      'sale_liga_percentage, sale_liga_rounding, sale_liga_base_price_cents, '
      'sale_liga_price_updated_at, sale_liga_price_source';
  static const _mineColumns = '$_columns, sale_folder_id';
  static const _priceMaxAge = Duration(hours: 24);

  final SupabaseClient _client;
  final UserPreferencesRepository _preferences;
  final LigaTcgPriceService _prices;

  const TcgMarketplaceRepository(this._client, this._preferences, this._prices);

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('É necessário entrar para vender cartas.');
    }
    return user;
  }

  Future<List<TcgMarketplaceListing>> listMine(String gameSlug) async {
    final user = _requireUser();
    final rows = await _client
        .from('collection_items')
        .select(_mineColumns)
        .eq('user_id', user.id)
        .eq('game_slug', gameSlug)
        .eq('collection_type', 'forSale')
        .order('created_at', ascending: false);
    final mapped = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    await _refreshStalePrices(mapped, user.id);
    return mapped.map(TcgMarketplaceListing.fromRow).toList(growable: false);
  }

  Future<List<TcgMarketplaceListing>> listPublic(String gameSlug) async {
    final rows = await _client
        .from('collection_items')
        .select(_columns)
        .eq('game_slug', gameSlug)
        .eq('collection_type', 'forSale')
        .eq('is_public', true)
        .eq('sale_status', TcgMarketplaceListing.activeStatus)
        .gt('sale_expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    final mapped = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final sellerNames = await _loadSellerNames(
      mapped.map((row) => (row['user_id'] ?? '').toString()).toSet(),
    );
    return mapped
        .map(
          (row) => TcgMarketplaceListing.fromRow(
            row,
            sellerName: sellerNames[(row['user_id'] ?? '').toString()] ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<void> addFromCollection(TcgCollectionItem card) async {
    final user = _requireUser();
    final existing = await _client
        .from('collection_items')
        .select('id, quantity')
        .eq('user_id', user.id)
        .eq('game_slug', card.gameSlug)
        .eq('collection_type', 'forSale')
        .eq('catalog_card_id', card.catalogCardId)
        .eq('variant_id', card.variantId)
        .limit(1);
    if (existing.isNotEmpty) {
      final row = Map<String, dynamic>.from(existing.first);
      final current = int.tryParse((row['quantity'] ?? 0).toString()) ?? 0;
      if (current >= card.quantity) {
        throw StateError('Todas as cópias já estão em Cartas à venda.');
      }
      await _client
          .from('collection_items')
          .update({'quantity': current + 1})
          .eq('id', row['id']);
      return;
    }

    await _client.from('collection_items').insert({
      'user_id': user.id,
      'game_slug': card.gameSlug,
      'catalog_card_id': card.catalogCardId,
      'variant_id': card.variantId,
      'card_code': card.cardCode,
      'collection_type': 'forSale',
      'quantity': 1,
      'is_favorite': false,
      'is_public': false,
      'name': card.name,
      'image_url': card.imageUrl,
      'set_name': card.setName,
      'rarity': card.rarity,
      'color': card.color,
      'type': card.type,
      'text': card.text,
      'attribute': card.attribute,
      'sale_status': TcgMarketplaceListing.activeStatus,
      'card_condition': TcgMarketplaceListing.mintCondition,
      'sale_pricing_mode': TcgMarketplaceListing.manualPricingMode,
    });
  }

  Future<void> saveListing({
    required TcgMarketplaceListing listing,
    required int quantity,
    required bool publish,
    required int? manualPriceInCents,
    required String pricingMode,
    required double? ligaPercentage,
    required String ligaRounding,
    required String saleStatus,
    required String cardCondition,
    required String notes,
    String? saleFolderId,
  }) async {
    final user = _requireUser();
    final ownedRows = await _client
        .from('collection_items')
        .select('quantity')
        .eq('user_id', user.id)
        .eq('game_slug', listing.gameSlug)
        .eq('collection_type', 'owned')
        .eq('catalog_card_id', listing.catalogCardId)
        .eq('variant_id', listing.variantId)
        .limit(1);
    final ownedQuantity = ownedRows.isEmpty
        ? 0
        : int.tryParse((ownedRows.first['quantity'] ?? 0).toString()) ?? 0;
    if (quantity > ownedQuantity) {
      throw StateError(
        'Você possui $ownedQuantity cópia(s) desta impressão na coleção.',
      );
    }

    int? finalPrice = manualPriceInCents;
    int? basePriceInCents;
    String source = '';
    DateTime? priceUpdatedAt;

    if (pricingMode == TcgMarketplaceListing.ligaPercentagePricingMode) {
      final snapshots = await _prices.fetchSnapshots([listing.cardCode]);
      final snapshot =
          snapshots[LigaTcgPriceService.normalizeLookupCode(listing.cardCode)];
      final basePrice = snapshot?.minimumPrice;
      if (basePrice == null || basePrice <= 0) {
        throw StateError(
          'A Liga ainda não possui preço verificado para esta impressão.',
        );
      }
      final percentage = ligaPercentage ?? 0;
      finalPrice = TcgMarketplaceListing.calculateLigaPercentagePriceInCents(
        basePrice: basePrice,
        percentage: percentage,
        rounding: ligaRounding,
      );
      basePriceInCents = (basePrice * 100).round();
      source = snapshot!.sourceUrl;
      priceUpdatedAt = DateTime.now().toUtc();
    }

    if (publish && (finalPrice ?? 0) <= 0) {
      throw StateError('Defina um preço antes de publicar o anúncio.');
    }

    final whatsApp = await _preferences.getCurrentWhatsAppPhone();
    if (publish && whatsApp.trim().isEmpty) {
      throw StateError('Cadastre seu WhatsApp no perfil antes de publicar.');
    }
    final isActive = saleStatus == TcgMarketplaceListing.activeStatus;
    final expiresAt = publish && isActive
        ? DateTime.now().toUtc().add(const Duration(days: 7))
        : null;

    await _client
        .from('collection_items')
        .update({
          'quantity': quantity,
          'is_public': publish && isActive,
          'sale_price_cents': finalPrice,
          'sale_contact_info': whatsApp,
          'sale_notes': notes.trim(),
          'sale_status': saleStatus,
          'card_condition': cardCondition,
          'sale_pricing_mode': pricingMode,
          'sale_liga_percentage':
              pricingMode == TcgMarketplaceListing.ligaPercentagePricingMode
              ? ligaPercentage
              : null,
          'sale_liga_rounding': ligaRounding,
          'sale_liga_base_price_cents': basePriceInCents,
          'sale_liga_price_updated_at': priceUpdatedAt?.toIso8601String(),
          'sale_liga_price_source': source,
          'sale_expires_at': expiresAt?.toIso8601String(),
          'sale_folder_id': saleFolderId,
        })
        .eq('id', listing.id);
  }

  Future<void> delete(String id) async {
    final user = _requireUser();
    await _client
        .from('collection_items')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<String> getPublicContact(String listingId) async {
    _requireUser();
    final response = await _client.rpc(
      'get_public_marketplace_listing_contact',
      params: {'listing_id': listingId},
    );
    return (response ?? '').toString();
  }

  Future<Map<String, String>> _loadSellerNames(Set<String> userIds) async {
    userIds.removeWhere((id) => id.isEmpty);
    if (userIds.isEmpty) return const {};
    final response = await _client.rpc(
      'get_public_seller_profiles',
      params: {'user_ids': userIds.toList(growable: false)},
    );
    return {
      for (final raw in response as List)
        (raw['id'] ?? '').toString(): (raw['name'] ?? '').toString(),
    };
  }

  Future<void> _refreshStalePrices(
    List<Map<String, dynamic>> rows,
    String userId,
  ) async {
    final staleRows = rows
        .where((row) {
          if ((row['user_id'] ?? '').toString() != userId) return false;
          if ((row['sale_pricing_mode'] ?? '').toString() !=
              TcgMarketplaceListing.ligaPercentagePricingMode) {
            return false;
          }
          final updatedAt = DateTime.tryParse(
            (row['sale_liga_price_updated_at'] ?? '').toString(),
          );
          return updatedAt == null ||
              DateTime.now().toUtc().difference(updatedAt.toUtc()) >
                  _priceMaxAge;
        })
        .toList(growable: false);
    if (staleRows.isEmpty) return;

    final snapshots = await _prices.fetchSnapshots(
      staleRows.map((row) => (row['card_code'] ?? '').toString()),
    );
    for (final row in staleRows) {
      final code = LigaTcgPriceService.normalizeLookupCode(
        (row['card_code'] ?? '').toString(),
      );
      final snapshot = snapshots[code];
      final basePrice = snapshot?.minimumPrice;
      final percentage = (row['sale_liga_percentage'] as num?)?.toDouble();
      if (basePrice == null || basePrice <= 0 || percentage == null) continue;
      final rounding =
          (row['sale_liga_rounding'] ?? TcgMarketplaceListing.noRounding)
              .toString();
      final price = TcgMarketplaceListing.calculateLigaPercentagePriceInCents(
        basePrice: basePrice,
        percentage: percentage,
        rounding: rounding,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('collection_items')
          .update({
            'sale_price_cents': price,
            'sale_liga_base_price_cents': (basePrice * 100).round(),
            'sale_liga_price_updated_at': now,
            'sale_liga_price_source': snapshot!.sourceUrl,
          })
          .eq('id', row['id']);
      row
        ..['sale_price_cents'] = price
        ..['sale_liga_base_price_cents'] = (basePrice * 100).round()
        ..['sale_liga_price_updated_at'] = now
        ..['sale_liga_price_source'] = snapshot.sourceUrl;
    }
  }
}
