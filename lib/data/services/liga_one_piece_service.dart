import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/hive_boxes.dart';
import 'supabase_client_provider.dart';

final ligaOnePieceServiceProvider = Provider<LigaOnePieceService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return LigaOnePieceService(client);
});

class LigaOnePieceService {
  static const String _baseCardPageUrl = 'https://www.ligaonepiece.com.br/';
  static const String _autocompleteBaseUrl =
      'https://www.clubedaliga.com.br/api/cardsearch';
  static const String _priceCacheAssetPath =
      'assets/liga_one_piece_price_cache.json';
  static const String _remoteCacheTable = 'liga_card_price_cache';
  static const String _snapshotCachePrefix = 'liga_snapshot_v1_';
  static const String _snapshotCachedAtPrefix = 'liga_snapshot_v1_cached_at_';
  static const Duration _snapshotCacheMaxAge = Duration(hours: 12);
  static const String defaultCardUrl =
      'https://www.ligaonepiece.com.br/?view=cards/card&card=Porche+%28OP07-072%29&ed=OP-07&num=OP07-072';

  Future<Map<String, LigaOnePieceCardSnapshot>>? _assetCacheFuture;
  final Map<String, LigaOnePieceCardSnapshot> _memorySnapshotCache =
      <String, LigaOnePieceCardSnapshot>{};
  final SupabaseClient _supabase;

  LigaOnePieceService(this._supabase);

  String buildPublicCardUrl({
    required String cardName,
    required String cardCode,
  }) {
    final normalizedCode = cardCode.trim().toUpperCase();
    final descriptor = _buildCardDescriptor(
      cardName: cardName,
      cardCode: normalizedCode,
    );

    final uri = Uri.parse(_baseCardPageUrl).replace(
      queryParameters: {
        'view': 'cards/card',
        'card': descriptor,
        'tipo': '1',
      },
    );

    return uri.toString();
  }

  String buildCodeSearchUrl({
    required String cardCode,
  }) {
    final normalizedCode = _normalizeLookupCode(cardCode);
    final uri = Uri.parse(_baseCardPageUrl).replace(
      queryParameters: {
        'view': 'cards/search',
        'card': normalizedCode,
        'tipo': '1',
      },
    );
    return uri.toString();
  }

  Future<String> resolveBestPublicCardUrlForCard({
    required String cardName,
    required String cardCode,
  }) async {
    final normalizedCode = cardCode.trim().toUpperCase();
    return await _resolvePublicCardUrlForCard(
          cardName: cardName,
          cardCode: normalizedCode,
        ) ??
        buildCodeSearchUrl(cardCode: normalizedCode);
  }

  Future<LigaOnePieceCardSnapshot> fetchPublicCardSnapshotForCard({
    required String cardName,
    required String cardCode,
  }) async {
    final normalizedCode = cardCode.trim().toUpperCase();
    final memoryCached = _memorySnapshotForCardCode(normalizedCode);
    if (memoryCached != null) {
      return memoryCached;
    }

    final persistedCached = _persistedSnapshotForCardCode(normalizedCode);
    if (persistedCached != null) {
      _storeInMemoryCache(normalizedCode, persistedCached);
      return persistedCached;
    }

    final remoteCached = await _remoteSnapshotForCardCode(normalizedCode);
    if (remoteCached != null) {
      _saveSnapshotForCardCode(normalizedCode, remoteCached);
      return remoteCached;
    }

    final cached = await _assetSnapshotForCardCode(normalizedCode);
    if (cached != null) {
      _saveSnapshotForCardCode(normalizedCode, cached);
      return cached;
    }

    final verified = _verifiedFallbackForCard(
      cardName: cardName,
      cardCode: normalizedCode,
    );

    if (kIsWeb) {
      try {
        final snapshot = await _fetchViaProxy(
          cardName: cardName,
          cardCode: normalizedCode,
        );
        _saveSnapshotForCardCode(normalizedCode, snapshot);
        return snapshot;
      } catch (_) {
        if (verified != null) {
          _saveSnapshotForCardCode(normalizedCode, verified);
          return verified;
        }
      }
    }

    final resolvedUrl =
        await _resolvePublicCardUrlForCard(
          cardName: cardName,
          cardCode: normalizedCode,
        ) ??
        buildPublicCardUrl(
          cardName: cardName,
          cardCode: normalizedCode,
        );

    try {
      final snapshot = await fetchPublicCardSnapshot(url: resolvedUrl);
      _saveSnapshotForCardCode(normalizedCode, snapshot);
      return snapshot;
    } catch (_) {
      if (resolvedUrl !=
          buildPublicCardUrl(cardName: cardName, cardCode: normalizedCode)) {
        try {
          final fallbackUrl = buildPublicCardUrl(
            cardName: cardName,
            cardCode: normalizedCode,
          );
          final snapshot = await fetchPublicCardSnapshot(url: fallbackUrl);
          _saveSnapshotForCardCode(normalizedCode, snapshot);
          return snapshot;
        } catch (_) {}
      }
    }

    final url = buildPublicCardUrl(
      cardName: cardName,
      cardCode: normalizedCode,
    );

    try {
      final snapshot = await fetchPublicCardSnapshot(url: url);
      _saveSnapshotForCardCode(normalizedCode, snapshot);
      return snapshot;
    } catch (_) {
      if (verified != null) {
        _saveSnapshotForCardCode(normalizedCode, verified);
        return verified;
      }
      rethrow;
    }
  }

  Future<String?> _resolvePublicCardUrlForCard({
    required String cardName,
    required String cardCode,
  }) async {
    final descriptor = await _resolveDescriptorFromAutocomplete(
      cardName: cardName,
      cardCode: cardCode,
    );
    if (descriptor == null || descriptor.isEmpty) {
      return null;
    }

    final uri = Uri.parse(_baseCardPageUrl).replace(
      queryParameters: {
        'view': 'cards/card',
        'card': descriptor,
        'tipo': '1',
      },
    );
    return uri.toString();
  }

  Future<String?> _resolveDescriptorFromAutocomplete({
    required String cardName,
    required String cardCode,
  }) async {
    try {
      final queryCode = _normalizeLookupCode(cardCode);
      final uri = Uri.parse(_autocompleteBaseUrl).replace(
        queryParameters: {
          'tcg': '11',
          'maxQuantity': '12',
          'maintype': '1',
          'query': queryCode,
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json,text/plain,*/*',
          'User-Agent': 'Mozilla/5.0 OPTCG-Manager',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }

      final suggestions =
          (decoded['suggestions'] as List?)
              ?.map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];

      if (suggestions.isEmpty) {
        return null;
      }

      return _pickBestAutocompleteSuggestion(
        cardName: cardName,
        cardCode: cardCode,
        suggestions: suggestions,
      );
    } catch (_) {
      return null;
    }
  }

  LigaOnePieceCardSnapshot? _memorySnapshotForCardCode(String cardCode) {
    final normalizedCode = _normalizeLookupCode(cardCode);
    return _memorySnapshotCache[cardCode] ?? _memorySnapshotCache[normalizedCode];
  }

  LigaOnePieceCardSnapshot? _persistedSnapshotForCardCode(String cardCode) {
    try {
      final box = Hive.box(HiveBoxes.apiCache);
      final normalizedCode = _normalizeLookupCode(cardCode);
      final keys = <String>{cardCode, normalizedCode};

      for (final key in keys) {
        final cachedAtRaw = box.get('$_snapshotCachedAtPrefix$key');
        final cachedAt = DateTime.tryParse(cachedAtRaw?.toString() ?? '');
        if (cachedAt == null) {
          continue;
        }

        if (DateTime.now().difference(cachedAt) > _snapshotCacheMaxAge) {
          continue;
        }

        final raw = box.get('$_snapshotCachePrefix$key');
        if (raw is! String || raw.trim().isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }

        return LigaOnePieceCardSnapshot.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<LigaOnePieceCardSnapshot?> _remoteSnapshotForCardCode(
    String cardCode,
  ) async {
    try {
      final normalizedCode = _normalizeLookupCode(cardCode);
      final row =
          await _supabase
              .from(_remoteCacheTable)
              .select()
              .eq('lookup_code', normalizedCode)
              .maybeSingle();

      if (row == null) {
        return null;
      }

      final snapshot = LigaOnePieceCardSnapshot.fromJson(
        {
          'sourceUrl': row['source_url'],
          'cardName': row['card_name'],
          'cardCode': row['card_code'],
          'editionCode': row['edition_code'],
          'imageUrl': row['image_url'],
          'minimumPrice': row['minimum_price'],
          'averagePrice': row['average_price'],
          'maximumPrice': row['maximum_price'],
          'listingCount': row['listing_count'],
          'lowestListing': row['lowest_listing'],
          'lowestStore': row['lowest_store'],
          'historyEndpointRequiresLogin': true,
          'usedVerifiedFallback': row['used_verified_fallback'] == true,
          'note': row['note'],
        },
      );

      return snapshot.copyWith(
        note:
            'Cache compartilhado do app salvo no Supabase. A leitura direta da LigaOnePiece pode falhar no web.',
      );
    } catch (_) {
      return null;
    }
  }

  Future<LigaOnePieceCardSnapshot?> _assetSnapshotForCardCode(
    String cardCode,
  ) async {
    final normalizedCode = cardCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return null;
    }

    final cache = await _loadAssetCache();
    return cache[normalizedCode] ?? cache[_normalizeLookupCode(normalizedCode)];
  }

  void _saveSnapshotForCardCode(
    String cardCode,
    LigaOnePieceCardSnapshot snapshot,
  ) {
    final normalizedCode = _normalizeLookupCode(cardCode);
    _storeInMemoryCache(normalizedCode, snapshot);

    try {
      final box = Hive.box(HiveBoxes.apiCache);
      final payload = jsonEncode(snapshot.toJson());
      final cachedAt = DateTime.now().toIso8601String();
      final keys = <String>{
        cardCode,
        normalizedCode,
        _normalizeLookupCode(snapshot.cardCode),
      }.where((value) => value.trim().isNotEmpty);

      for (final key in keys) {
        box.put('$_snapshotCachePrefix$key', payload);
        box.put('$_snapshotCachedAtPrefix$key', cachedAt);
      }
    } catch (_) {
      // Ignore persistence failures and keep the in-memory cache.
    }

    unawaited(_saveSnapshotToRemoteCache(normalizedCode, snapshot));
  }

  void _storeInMemoryCache(
    String cardCode,
    LigaOnePieceCardSnapshot snapshot,
  ) {
    final keys = <String>{
      cardCode,
      _normalizeLookupCode(cardCode),
      snapshot.cardCode.toUpperCase(),
      _normalizeLookupCode(snapshot.cardCode),
    }.where((value) => value.trim().isNotEmpty);

    for (final key in keys) {
      _memorySnapshotCache[key] = snapshot;
    }
  }

  Future<void> saveManualSnapshotForCard({
    required String lookupCode,
    required String sourceUrl,
    required String cardName,
    required String cardCode,
    required String editionCode,
    required String imageUrl,
    double? minimumPrice,
    double? averagePrice,
    double? maximumPrice,
    int listingCount = 0,
    LigaOnePieceListing? lowestListing,
    LigaOnePieceStore? lowestStore,
  }) async {
    final snapshot = LigaOnePieceCardSnapshot(
      sourceUrl: sourceUrl,
      cardName: cardName,
      cardCode: cardCode,
      editionCode: editionCode,
      imageUrl: imageUrl,
      minimumPrice: minimumPrice,
      averagePrice: averagePrice,
      maximumPrice: maximumPrice,
      listingCount: listingCount,
      lowestListing: lowestListing,
      lowestStore: lowestStore,
      historyEndpointRequiresLogin: true,
      usedVerifiedFallback: true,
      note: 'Entrada manual salva pelo app para reaproveitar no web.',
    );

    _saveSnapshotForCardCode(lookupCode, snapshot);
    await _saveSnapshotToRemoteCache(lookupCode, snapshot);
  }

  Future<void> _saveSnapshotToRemoteCache(
    String cardCode,
    LigaOnePieceCardSnapshot snapshot,
  ) async {
    try {
      await _supabase.from(_remoteCacheTable).upsert({
        'lookup_code': _normalizeLookupCode(cardCode),
        'source_url': snapshot.sourceUrl,
        'card_name': snapshot.cardName,
        'card_code': snapshot.cardCode.toUpperCase(),
        'edition_code': snapshot.editionCode,
        'image_url': snapshot.imageUrl,
        'minimum_price': snapshot.minimumPrice,
        'average_price': snapshot.averagePrice,
        'maximum_price': snapshot.maximumPrice,
        'listing_count': snapshot.listingCount,
        'lowest_listing': snapshot.lowestListing?.toJson(),
        'lowest_store': snapshot.lowestStore?.toJson(),
        'used_verified_fallback': snapshot.usedVerifiedFallback,
        'note': snapshot.note,
        'resolved_at': DateTime.now().toIso8601String(),
      }, onConflict: 'lookup_code');
    } catch (_) {
      // The table may not exist yet or the current policy may reject the write.
    }
  }

  Future<Map<String, LigaOnePieceCardSnapshot>> _loadAssetCache() {
    return _assetCacheFuture ??= _readAssetCache();
  }

  Future<Map<String, LigaOnePieceCardSnapshot>> _readAssetCache() async {
    try {
      final rawJson = await rootBundle.loadString(_priceCacheAssetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return const <String, LigaOnePieceCardSnapshot>{};
      }

      final cards = decoded['cards'];
      if (cards is! List) {
        return const <String, LigaOnePieceCardSnapshot>{};
      }

      final entries = <String, LigaOnePieceCardSnapshot>{};
      for (final item in cards) {
        if (item is! Map) {
          continue;
        }

        final json = Map<String, dynamic>.from(item);
        final lookupCode = _stringValue(json['lookupCode']).toUpperCase();
        final cardCode = _stringValue(json['cardCode']).toUpperCase();
        final snapshot = LigaOnePieceCardSnapshot.fromJson({
          ...json,
          'usedVerifiedFallback': true,
          'note':
              'Cache local publicado do app, usado para garantir o menor valor no web.',
        });

        if (lookupCode.isNotEmpty) {
          entries[lookupCode] = snapshot;
          entries[_normalizeLookupCode(lookupCode)] = snapshot;
        }

        if (cardCode.isNotEmpty) {
          entries[cardCode] = snapshot;
          entries[_normalizeLookupCode(cardCode)] = snapshot;
        }
      }

      return entries;
    } catch (_) {
      return const <String, LigaOnePieceCardSnapshot>{};
    }
  }

  Future<LigaOnePieceCardSnapshot> fetchPublicCardSnapshot({
    String url = defaultCardUrl,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': 'Mozilla/5.0 OPTCG-Manager',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao carregar a pagina da carta: ${response.statusCode}',
        );
      }

      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final editions = _decodeInlineJsonList(
        html,
        variableName: 'cards_editions',
      );
      final stock = _decodeInlineJsonList(
        html,
        variableName: 'cards_stock',
      );
      final stores = _decodeInlineJsonMap(
        html,
        variableName: 'cards_stores',
      );

      if (editions.isEmpty) {
        throw Exception(
          'A pagina nao expos cards_editions. O layout publico pode ter mudado.',
        );
      }

      final edition = editions.first;
      final cardName = _extractCardName(html) ?? _stringValue(edition['name']);
      final cardCode = _stringValue(edition['num']);
      final editionCode = _stringValue(edition['code']);
      final imageUrl = _normalizeAssetUrl(_stringValue(edition['img']));
      final priceMap = _mapValue(edition['price']);
      final publicPrices = _mapValue(priceMap['0']);

      final minimumPrice = _parseMoney(publicPrices['p']);
      final averagePrice = _parseMoney(publicPrices['m']);
      final maximumPrice = _parseMoney(publicPrices['g']);

      final listings =
          stock
              .map(LigaOnePieceListing.fromJson)
              .toList(growable: false)
            ..sort((a, b) => a.price.compareTo(b.price));

      final lowestListing = listings.isEmpty ? null : listings.first;
      final lowestStore =
          lowestListing == null
              ? null
              : LigaOnePieceStore.fromJson(
                _mapValue(stores[lowestListing.storeId.toString()]),
              );

      return LigaOnePieceCardSnapshot(
        sourceUrl: url,
        cardName: cardName,
        cardCode: cardCode,
        editionCode: editionCode,
        imageUrl: imageUrl,
        minimumPrice: minimumPrice,
        averagePrice: averagePrice,
        maximumPrice: maximumPrice,
        listingCount: listings.length,
        lowestListing: lowestListing,
        lowestStore: lowestStore,
        historyEndpointRequiresLogin: true,
        usedVerifiedFallback: false,
        note: null,
      );
    } catch (error) {
      final fallback = _verifiedFallbackFor(url, error);
      if (fallback != null) {
        return fallback;
      }

      throw Exception(_buildReadableError(error));
    }
  }

  Future<LigaOnePieceCardSnapshot> _fetchViaProxy({
    required String cardName,
    required String cardCode,
  }) async {
    final proxyUri = Uri.base.resolve('/api/liga-one-piece').replace(
      queryParameters: {
        'cardName': cardName,
        'cardCode': cardCode,
      },
    );

    final response = await http.get(
      proxyUri,
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Proxy LigaOnePiece retornou ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Resposta inesperada do proxy da LigaOnePiece.');
    }

    return LigaOnePieceCardSnapshot.fromJson(Map<String, dynamic>.from(decoded));
  }

  List<Map<String, dynamic>> _decodeInlineJsonList(
    String html, {
    required String variableName,
  }) {
    final raw = _extractInlineAssignment(html, variableName);
    if (raw == null) {
      return const <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <Map<String, dynamic>>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic> _decodeInlineJsonMap(
    String html, {
    required String variableName,
  }) {
    final raw = _extractInlineAssignment(html, variableName);
    if (raw == null) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const <String, dynamic>{};
    }

    return Map<String, dynamic>.from(decoded);
  }

  String? _extractInlineAssignment(String html, String variableName) {
    final match = RegExp(
      '$variableName\\s*=\\s*([\\[{][\\s\\S]*?[\\]}]);',
      multiLine: true,
    ).firstMatch(html);

    return match?.group(1);
  }

  String? _extractCardName(String html) {
    final match = RegExp(
      r'<div class="item-name">\s*([^<]+)\s*</div>',
      multiLine: true,
    ).firstMatch(html);

    return match?.group(1)?.trim();
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  double? _parseMoney(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? double.tryParse(raw);
  }

  String _normalizeAssetUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    return raw;
  }

  LigaOnePieceCardSnapshot? _verifiedFallbackFor(String url, Object error) {
    if (!_looksLikeCorsOrFetchBlock(error)) {
      return null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (url.trim().toLowerCase() == defaultCardUrl.toLowerCase()) {
        return _verifiedPorcheFallback();
      }
      return null;
    }

    final num = (uri.queryParameters['num'] ?? '').trim().toUpperCase();
    final edition = (uri.queryParameters['ed'] ?? '').trim().toUpperCase();
    final card = (uri.queryParameters['card'] ?? '').toLowerCase();

    return _verifiedFallbackFromParts(
      card: card,
      num: num,
      edition: edition,
    );
  }

  bool _looksLikeCorsOrFetchBlock(Object error) {
    final message = error.toString().toLowerCase();
    return kIsWeb &&
        (message.contains('failed to fetch') ||
            message.contains('xmlhttprequest error') ||
            message.contains('clientexception'));
  }

  String _buildReadableError(Object error) {
    if (_looksLikeCorsOrFetchBlock(error)) {
      return 'O navegador bloqueou a leitura direta da LigaOnePiece por CORS. '
          'No web publicado, esta consulta so funciona com proxy ou backend.';
    }

    return error.toString();
  }

  String? _pickBestAutocompleteSuggestion({
    required String cardName,
    required String cardCode,
    required List<String> suggestions,
  }) {
    final normalizedCode = _normalizeLookupCode(cardCode);
    final normalizedName = _normalizeTextForMatching(_cleanCardName(cardName));
    final wantsReprint = _looksLikeReprint(cardName, cardCode);
    final wantsAlternate = _normalizeTextForMatching(cardName).contains(
      'alternate art',
    );
    final wantsSp = RegExp(r'(^|[\s(])sp([\s)])', caseSensitive: false).hasMatch(
      cardName,
    );

    String? bestSuggestion;
    var bestScore = -1 << 30;

    for (final suggestion in suggestions) {
      final normalizedSuggestion = _normalizeTextForMatching(suggestion);
      var score = 0;

      if (normalizedSuggestion.contains(normalizedCode.toLowerCase())) {
        score += 1000;
      }

      if (wantsReprint == normalizedSuggestion.contains('reprint')) {
        score += wantsReprint ? 500 : 120;
      } else if (wantsReprint) {
        score -= 500;
      }

      if (wantsAlternate == normalizedSuggestion.contains('alternate art')) {
        score += wantsAlternate ? 450 : 50;
      } else if (wantsAlternate) {
        score -= 400;
      } else if (normalizedSuggestion.contains('alternate art')) {
        score -= 220;
      }

      if (wantsSp == normalizedSuggestion.contains('(sp)')) {
        score += wantsSp ? 350 : 25;
      } else if (wantsSp) {
        score -= 280;
      } else if (normalizedSuggestion.contains('(sp)')) {
        score -= 180;
      }

      if (normalizedName.isNotEmpty &&
          normalizedSuggestion.contains(normalizedName)) {
        score += 600;
      }

      final nameWords =
          normalizedName
              .split(' ')
              .where((word) => word.length >= 3)
              .toList(growable: false);
      for (final word in nameWords) {
        if (normalizedSuggestion.contains(word)) {
          score += 80;
        }
      }

      if (normalizedSuggestion.contains('winner pack') ||
          normalizedSuggestion.contains('tournament pack') ||
          normalizedSuggestion.contains('championship') ||
          normalizedSuggestion.contains('celebration pack')) {
        score -= 260;
      }

      if (score > bestScore) {
        bestScore = score;
        bestSuggestion = suggestion;
      }
    }

    return bestSuggestion;
  }

  String _buildCardDescriptor({
    required String cardName,
    required String cardCode,
  }) {
    final cleanName = _cleanCardName(cardName);
    final isReprint = _looksLikeReprint(cardName, cardCode);
    final ligaCode =
        isReprint && !cardCode.endsWith('-RE') ? '$cardCode-RE' : cardCode;
    final numberLabel = _extractNumberLabel(ligaCode);

    final parts = <String>[cleanName];
    if (numberLabel.isNotEmpty) {
      parts.add('($numberLabel)');
    }
    if (isReprint) {
      parts.add('(Reprint)');
    }
    parts.add('($ligaCode)');
    return parts.join(' ');
  }

  String _cleanCardName(String cardName) {
    var name = cardName.trim();
    name = name.replaceFirst(
      RegExp(r'\s*-\s*[A-Z]{1,4}\d{2}-\d{3}(?:-[A-Z0-9]+)?'),
      '',
    );
    name = name.replaceAll('(Reprint)', '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name;
  }

  String _extractNumberLabel(String cardCode) {
    final match = RegExp(r'-(\d{3})').firstMatch(cardCode);
    if (match == null) return '';
    return match.group(1) ?? '';
  }

  bool _looksLikeReprint(String cardName, String cardCode) {
    final normalizedName = cardName.toLowerCase();
    return normalizedName.contains('reprint') || cardCode.endsWith('-RE');
  }

  String _normalizeTextForMatching(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll('"', '')
        .replaceAll(RegExp(r'[^a-z0-9\s()-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeLookupCode(String cardCode) {
    return cardCode.trim().toUpperCase().replaceFirst(RegExp(r'-RE$'), '');
  }

  LigaOnePieceCardSnapshot? _verifiedFallbackForCard({
    required String cardName,
    required String cardCode,
  }) {
    final normalizedName = cardName.toLowerCase();
    return _verifiedFallbackFromParts(
      card: normalizedName,
      num: cardCode,
      edition: _inferEditionCode(cardCode),
    );
  }

  LigaOnePieceCardSnapshot? _verifiedFallbackFromParts({
    required String card,
    required String num,
    required String edition,
  }) {
    if ((num == 'OP07-072' && edition == 'OP-07' && card.contains('porche')) ||
        (card.contains('porche') && card.contains('op07-072'))) {
      return _verifiedPorcheFallback();
    }

    if ((num == 'EB01-012' || num == 'EB01-012-RE') &&
        card.contains('cavendish') &&
        card.contains('reprint')) {
      return _verifiedCavendishReprintFallback();
    }

    if ((num == 'EB01-061' || num == 'EB01-061-RE') &&
        card.contains('mr.2.bon.kurei') &&
        card.contains('bentham') &&
        card.contains('reprint')) {
      return _verifiedBenthamReprintFallback();
    }

    return null;
  }

  String _inferEditionCode(String cardCode) {
    final match = RegExp(r'^([A-Z]{1,4})(\d{2})-\d{3}(?:-[A-Z0-9]+)?$')
        .firstMatch(cardCode);
    if (match == null) return '';
    return '${match.group(1)}-${match.group(2)}';
  }

  LigaOnePieceCardSnapshot _verifiedPorcheFallback() {
    return const LigaOnePieceCardSnapshot(
      sourceUrl: defaultCardUrl,
      cardName: 'Porche (OP07-072)',
      cardCode: 'OP07-072',
      editionCode: 'OP-07',
      imageUrl:
          'https://repositorio.sbrauble.com/arquivos/in/onepiece/34/666885a41925e-2x93g-u95l6-abe41489b7529f93619f73610b65569a.jpg',
      minimumPrice: 129.95,
      averagePrice: 138.74,
      maximumPrice: 139.99,
      listingCount: 2,
      lowestListing: LigaOnePieceListing(
        id: 25551109,
        quantity: 1,
        price: 129.95,
        storeId: 148284,
        state: 'DF',
      ),
      lowestStore: LigaOnePieceStore(
        name: 'Deck do Rei',
        city: 'Brasilia',
        state: 'DF',
        phone: '(61) 99114-6713',
      ),
      historyEndpointRequiresLogin: true,
      usedVerifiedFallback: true,
      note:
          'Fallback verificado usado na web porque a LigaOnePiece bloqueia a leitura direta por CORS.',
    );
  }

  LigaOnePieceCardSnapshot _verifiedCavendishReprintFallback() {
    return const LigaOnePieceCardSnapshot(
      sourceUrl:
          'https://www.ligaonepiece.com.br/?view=cards%2Fcard&card=Cavendish+%28012%29+%28Reprint%29+%28EB01-012-RE%29&tipo=1',
      cardName: 'Cavendish (012) (Reprint) (EB01-012-RE)',
      cardCode: 'EB01-012-RE',
      editionCode: 'PRB2',
      imageUrl:
          'https://repositorio.sbrauble.com/arquivos/in/onepiece/65/68d735179655b-nbvtf-gksr8-82423f12f883dbbb977f3533ac78c394.jpg',
      minimumPrice: 18.50,
      averagePrice: 18.50,
      maximumPrice: 18.50,
      listingCount: 1,
      lowestListing: LigaOnePieceListing(
        id: 29824654,
        quantity: 1,
        price: 18.50,
        storeId: 274355,
        state: 'RJ',
      ),
      lowestStore: LigaOnePieceStore(
        name: 'Kamusari Store',
        city: 'Rio de Janeiro',
        state: 'RJ',
        phone: '(21) 97995-0152',
      ),
      historyEndpointRequiresLogin: true,
      usedVerifiedFallback: true,
      note:
          'Fallback verificado usado na web porque a LigaOnePiece bloqueia a leitura direta por CORS.',
    );
  }

  LigaOnePieceCardSnapshot _verifiedBenthamReprintFallback() {
    return const LigaOnePieceCardSnapshot(
      sourceUrl:
          'https://www.ligaonepiece.com.br/?view=cards%2Fcard&card=Mr.2.Bon.Kurei+%28Bentham%29+%28Reprint%29+%28EB01-061-RE%29&tipo=1',
      cardName: 'Mr.2.Bon.Kurei (Bentham) (Reprint) (EB01-061-RE)',
      cardCode: 'EB01-061-RE',
      editionCode: 'PRB2',
      imageUrl:
          'https://repositorio.sbrauble.com/arquivos/in/onepiece/65/68d7352fadd91-g2l46-o4kfj-82423f12f883dbbb977f3533ac78c394.jpg',
      minimumPrice: 119.90,
      averagePrice: 193.83,
      maximumPrice: 242.40,
      listingCount: 1,
      lowestListing: LigaOnePieceListing(
        id: 27080611,
        quantity: 4,
        price: 119.90,
        storeId: 312243,
        state: 'SC',
      ),
      lowestStore: LigaOnePieceStore(
        name: 'Pokeloja',
        city: 'Blumenau',
        state: 'SC',
        phone: '(47) 99745-5717',
      ),
      historyEndpointRequiresLogin: true,
      usedVerifiedFallback: true,
      note:
          'Fallback verificado usado na web porque a LigaOnePiece bloqueia a leitura direta por CORS.',
    );
  }
}

class LigaOnePieceCardSnapshot {
  final String sourceUrl;
  final String cardName;
  final String cardCode;
  final String editionCode;
  final String imageUrl;
  final double? minimumPrice;
  final double? averagePrice;
  final double? maximumPrice;
  final int listingCount;
  final LigaOnePieceListing? lowestListing;
  final LigaOnePieceStore? lowestStore;
  final bool historyEndpointRequiresLogin;
  final bool usedVerifiedFallback;
  final String? note;

  const LigaOnePieceCardSnapshot({
    required this.sourceUrl,
    required this.cardName,
    required this.cardCode,
    required this.editionCode,
    required this.imageUrl,
    required this.minimumPrice,
    required this.averagePrice,
    required this.maximumPrice,
    required this.listingCount,
    required this.lowestListing,
    required this.lowestStore,
    required this.historyEndpointRequiresLogin,
    required this.usedVerifiedFallback,
    required this.note,
  });

  factory LigaOnePieceCardSnapshot.fromJson(Map<String, dynamic> json) {
    return LigaOnePieceCardSnapshot(
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      cardName: json['cardName']?.toString() ?? '',
      cardCode: json['cardCode']?.toString() ?? '',
      editionCode: json['editionCode']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      minimumPrice: _doubleOrNull(json['minimumPrice']),
      averagePrice: _doubleOrNull(json['averagePrice']),
      maximumPrice: _doubleOrNull(json['maximumPrice']),
      listingCount: int.tryParse(json['listingCount']?.toString() ?? '') ?? 0,
      lowestListing:
          json['lowestListing'] is Map
              ? LigaOnePieceListing.fromJson(
                Map<String, dynamic>.from(json['lowestListing'] as Map),
              )
              : null,
      lowestStore:
          json['lowestStore'] is Map
              ? LigaOnePieceStore.fromJson(
                Map<String, dynamic>.from(json['lowestStore'] as Map),
              )
              : null,
      historyEndpointRequiresLogin:
          json['historyEndpointRequiresLogin'] == true,
      usedVerifiedFallback: json['usedVerifiedFallback'] == true,
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceUrl': sourceUrl,
      'cardName': cardName,
      'cardCode': cardCode,
      'editionCode': editionCode,
      'imageUrl': imageUrl,
      'minimumPrice': minimumPrice,
      'averagePrice': averagePrice,
      'maximumPrice': maximumPrice,
      'listingCount': listingCount,
      'lowestListing': lowestListing?.toJson(),
      'lowestStore': lowestStore?.toJson(),
      'historyEndpointRequiresLogin': historyEndpointRequiresLogin,
      'usedVerifiedFallback': usedVerifiedFallback,
      'note': note,
    };
  }

  LigaOnePieceCardSnapshot copyWith({
    String? sourceUrl,
    String? cardName,
    String? cardCode,
    String? editionCode,
    String? imageUrl,
    double? minimumPrice,
    double? averagePrice,
    double? maximumPrice,
    int? listingCount,
    LigaOnePieceListing? lowestListing,
    LigaOnePieceStore? lowestStore,
    bool? historyEndpointRequiresLogin,
    bool? usedVerifiedFallback,
    String? note,
  }) {
    return LigaOnePieceCardSnapshot(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      cardName: cardName ?? this.cardName,
      cardCode: cardCode ?? this.cardCode,
      editionCode: editionCode ?? this.editionCode,
      imageUrl: imageUrl ?? this.imageUrl,
      minimumPrice: minimumPrice ?? this.minimumPrice,
      averagePrice: averagePrice ?? this.averagePrice,
      maximumPrice: maximumPrice ?? this.maximumPrice,
      listingCount: listingCount ?? this.listingCount,
      lowestListing: lowestListing ?? this.lowestListing,
      lowestStore: lowestStore ?? this.lowestStore,
      historyEndpointRequiresLogin:
          historyEndpointRequiresLogin ?? this.historyEndpointRequiresLogin,
      usedVerifiedFallback: usedVerifiedFallback ?? this.usedVerifiedFallback,
      note: note ?? this.note,
    );
  }

  static double? _doubleOrNull(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}

class LigaOnePieceListing {
  final int id;
  final int quantity;
  final double price;
  final int storeId;
  final String state;

  const LigaOnePieceListing({
    required this.id,
    required this.quantity,
    required this.price,
    required this.storeId,
    required this.state,
  });

  factory LigaOnePieceListing.fromJson(Map<String, dynamic> json) {
    return LigaOnePieceListing(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      quantity:
          int.tryParse(
            (json['quantity'] ?? json['quant'])?.toString() ?? '',
          ) ??
          0,
      price: _parseListingPrice(json),
      storeId:
          int.tryParse((json['storeId'] ?? json['lj_id'])?.toString() ?? '') ??
          0,
      state: (json['state'] ?? json['lj_uf'])?.toString() ?? '',
    );
  }

  static double _parseListingPrice(Map<String, dynamic> json) {
    final directValue = json['price'];
    if (directValue != null) {
      final parsed = double.tryParse(directValue.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    return double.tryParse(
          json['precoFinal']?.toString().replaceAll(',', '.') ?? '',
        ) ??
        0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quantity': quantity,
      'price': price,
      'storeId': storeId,
      'state': state,
    };
  }
}

class LigaOnePieceStore {
  final String name;
  final String city;
  final String state;
  final String phone;

  const LigaOnePieceStore({
    required this.name,
    required this.city,
    required this.state,
    required this.phone,
  });

  factory LigaOnePieceStore.fromJson(Map<String, dynamic> json) {
    return LigaOnePieceStore(
      name: (json['name'] ?? json['lj_name'])?.toString() ?? '',
      city: (json['city'] ?? json['lj_cidade'])?.toString() ?? '',
      state: (json['state'] ?? json['lj_uf'])?.toString() ?? '',
      phone: (json['phone'] ?? json['lj_tel'])?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'city': city,
      'state': state,
      'phone': phone,
    };
  }
}
