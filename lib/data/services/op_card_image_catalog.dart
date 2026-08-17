import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/op_card.dart';
import 'op_card_variant_resolver.dart';

/// Resolves One Piece card images to the durable R2 mirror bundled with the
/// visual catalog. The upstream OPTCG image host is intentionally only kept as
/// a last resort because it can become unavailable for long periods.
class OpCardImageCatalog {
  static const String _assetPath = 'assets/one_piece_image_catalog.json';
  static Future<Map<String, List<OpCard>>>? _catalogFuture;

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
      cards: catalog[cardCode.trim().toUpperCase()] ?? const <OpCard>[],
      cardCode: cardCode,
      cardName: cardName,
      setName: setName,
      currentImageUrl: current,
    );
  }

  static Future<List<OpCard>> replaceUnreliableImages(
    Iterable<OpCard> cards,
  ) async {
    final catalog = await (_catalogFuture ??= _loadCatalog());
    return cards
        .map((card) {
          if (_isDurableImage(card.image)) return card;

          final resolved = resolveFromCards(
            cards: catalog[card.code.trim().toUpperCase()] ?? const <OpCard>[],
            cardCode: card.code,
            cardName: card.name,
            setName: card.setName,
            currentImageUrl: card.image,
          );
          if (resolved.isEmpty || resolved == card.image) return card;

          return OpCard(
            code: card.code,
            name: card.name,
            image: resolved,
            setName: card.setName,
            rarity: card.rarity,
            color: card.color,
            type: card.type,
            subTypes: card.subTypes,
            text: card.text,
            attribute: card.attribute,
          );
        })
        .toList(growable: false);
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
    // The Liga repository is authoritative, but it does not consistently
    // allow cross-origin image decoding in Flutter Web. Keep the R2 mirror as
    // the only terminal URL so persisted Liga/OPTCG URLs are repaired before
    // reaching the renderer.
    return host == 'pub-b575d68981e0471899723c0f36cb89aa.r2.dev';
  }

  static Future<Map<String, List<OpCard>>> _loadCatalog() async {
    try {
      final decoded = jsonDecode(await rootBundle.loadString(_assetPath));
      if (decoded is! List) return const <String, List<OpCard>>{};

      final cards = decoded
          .whereType<Map>()
          .map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return OpCard(
              code: (item['c'] ?? '').toString().trim().toUpperCase(),
              name: (item['n'] ?? '').toString().trim(),
              image: (item['i'] ?? '').toString().trim(),
              setName: (item['s'] ?? '').toString().trim(),
              rarity: (item['r'] ?? '').toString().trim(),
              color: (item['o'] ?? '').toString().trim(),
              type: (item['t'] ?? '').toString().trim(),
              subTypes: '',
              text: '',
              attribute: '',
            );
          })
          .where((card) {
            return card.code.isNotEmpty && card.image.isNotEmpty;
          })
          .toList(growable: false);
      final byCode = <String, List<OpCard>>{};
      for (final card in cards) {
        byCode.putIfAbsent(card.code, () => <OpCard>[]).add(card);
      }
      return byCode;
    } catch (_) {
      return const <String, List<OpCard>>{};
    }
  }
}
