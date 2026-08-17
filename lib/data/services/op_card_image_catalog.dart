import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/op_card.dart';
import 'op_card_variant_resolver.dart';

/// Resolves One Piece card images to the durable R2 mirror bundled with the
/// visual catalog. The upstream OPTCG image host is intentionally only kept as
/// a last resort because it can become unavailable for long periods.
class OpCardImageCatalog {
  static const String _assetPath = 'assets/visual_card_fingerprints.json';
  static Future<List<OpCard>>? _catalogFuture;

  static Future<String> resolve({
    required String cardCode,
    required String cardName,
    required String setName,
    required String currentImageUrl,
  }) async {
    final current = currentImageUrl.trim();
    if (_isDurableImage(current)) return current;

    final catalog = await (_catalogFuture ??= _loadCatalog());
    return resolveFromCards(
      cards: catalog,
      cardCode: cardCode,
      cardName: cardName,
      setName: setName,
      currentImageUrl: current,
    );
  }

  @visibleForTesting
  static String resolveFromCards({
    required Iterable<OpCard> cards,
    required String cardCode,
    required String cardName,
    required String setName,
    required String currentImageUrl,
  }) {
    final normalizedCode = cardCode.trim().toUpperCase();
    final variants = cards.where(
      (card) => card.code.trim().toUpperCase() == normalizedCode,
    );
    final match = bestOpCardForStoredIdentity(
      variants: variants,
      cardCode: normalizedCode,
      storedName: cardName,
      storedSetName: setName,
      storedImageUrl: currentImageUrl,
    );
    final mirror = match?.image.trim() ?? '';
    return mirror.isNotEmpty ? mirror : currentImageUrl.trim();
  }

  static bool _isDurableImage(String imageUrl) {
    final host = Uri.tryParse(imageUrl)?.host.toLowerCase() ?? '';
    return host == 'pub-b575d68981e0471899723c0f36cb89aa.r2.dev' ||
        (host == 'repositorio.sbrauble.com' &&
            imageUrl.toLowerCase().contains('/arquivos/in/onepiece/'));
  }

  static Future<List<OpCard>> _loadCatalog() async {
    try {
      final decoded = jsonDecode(await rootBundle.loadString(_assetPath));
      if (decoded is! List) return const <OpCard>[];

      return decoded
          .whereType<Map>()
          .map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return OpCard(
              code: (item['code'] ?? '').toString().trim().toUpperCase(),
              name: (item['name'] ?? '').toString().trim(),
              image: (item['imageUrl'] ?? '').toString().trim(),
              setName: (item['setName'] ?? '').toString().trim(),
              rarity: (item['rarity'] ?? '').toString().trim(),
              color: (item['color'] ?? '').toString().trim(),
              type: (item['type'] ?? '').toString().trim(),
              subTypes: '',
              text: '',
              attribute: '',
            );
          })
          .where((card) {
            return card.code.isNotEmpty && card.image.isNotEmpty;
          })
          .toList(growable: false);
    } catch (_) {
      return const <OpCard>[];
    }
  }
}
