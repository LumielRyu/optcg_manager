import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_reporter.dart';
import '../local/hive_boxes.dart';
import 'liga_variant_classifier.dart';
import 'supabase_client_provider.dart';

final ligaOnePieceServiceProvider = Provider<LigaOnePieceService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return LigaOnePieceService(client);
});

@visibleForTesting
String inferLigaLookupCode({
  required String cardName,
  required String cardCode,
}) {
  return inferPrimaryLigaVariantCode(cardName: cardName, cardCode: cardCode);
}

@visibleForTesting
List<String> inferLigaLookupCodes({
  required String cardName,
  required String cardCode,
}) {
  return inferLigaVariantCandidateCodes(cardName: cardName, cardCode: cardCode);
}

class LigaOnePieceService {
  static const String _baseCardPageUrl = 'https://www.ligaonepiece.com.br/';
  static const String _autocompleteBaseUrl =
      'https://www.clubedaliga.com.br/api/cardsearch';
  static const String _priceCacheAssetPath =
      'assets/liga_one_piece_price_cache.json';
  static const String _remoteCacheTable = 'liga_card_price_cache';
  static const String _variantMappingTable = 'liga_card_variant_mappings';
  static const String _snapshotCachePrefix = 'liga_snapshot_v3_';
  static const String _snapshotCachedAtPrefix = 'liga_snapshot_v3_cached_at_';
  static const Duration _snapshotCacheMaxAge = Duration(hours: 12);
  static const String defaultCardUrl =
      'https://www.ligaonepiece.com.br/?view=cards/card&card=Porche+%28OP07-072%29&ed=OP-07&num=OP07-072';

  Future<Map<String, LigaOnePieceCardSnapshot>>? _assetCacheFuture;
  final Map<String, LigaOnePieceCardSnapshot> _memorySnapshotCache =
      <String, LigaOnePieceCardSnapshot>{};
  final Map<String, String> _confirmedMappingCache = <String, String>{};
  final Set<String> _loadedMappingKeys = <String>{};
  final SupabaseClient _supabase;

  LigaOnePieceService(this._supabase);

  String lookupCodeForCard({
    required String cardName,
    required String cardCode,
  }) {
    return inferLigaLookupCode(cardName: cardName, cardCode: cardCode);
  }

  List<String> lookupCodesForCard({
    required String cardName,
    required String cardCode,
  }) {
    return inferLigaLookupCodes(cardName: cardName, cardCode: cardCode);
  }

  String priceReferenceKeyForCard({
    required String cardName,
    required String cardCode,
    String imageUrl = '',
  }) {
    final lookupCode = lookupCodeForCard(
      cardName: cardName,
      cardCode: cardCode,
    );
    final imageIdentity = _imageIdentity(imageUrl);
    return imageIdentity.isEmpty
        ? lookupCode
        : '$lookupCode::IMG::$imageIdentity';
  }

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
      queryParameters: {'view': 'cards/card', 'card': descriptor, 'tipo': '1'},
    );

    return uri.toString();
  }

  String buildCodeSearchUrl({required String cardCode}) {
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
    String imageUrl = '',
  }) async {
    final normalizedCode = cardCode.trim().toUpperCase();
    final lookupCode = lookupCodeForCard(
      cardName: cardName,
      cardCode: normalizedCode,
    );
    final strictVariant = classifyLigaVariant(
      cardName: cardName,
      cardCode: normalizedCode,
    ).requiresStrictMatch;

    final referenceKey = priceReferenceKeyForCard(
      cardName: cardName,
      cardCode: normalizedCode,
      imageUrl: imageUrl,
    );
    final remoteCached = await _remoteSnapshotForCard(
      cardName: cardName,
      cardCode: normalizedCode,
      imageUrl: imageUrl,
    );
    if (remoteCached != null) {
      _saveSnapshotForCardCode(referenceKey, remoteCached);
      return remoteCached;
    }
    if (strictVariant) {
      throw StateError(
        'A variante possui mais de uma impressao possivel na Liga e ainda nao foi confirmada.',
      );
    }

    final memoryCached =
        _memorySnapshotForCardCode(referenceKey) ??
        _memorySnapshotForCardCode(lookupCode);
    if (memoryCached != null) {
      return memoryCached;
    }

    final persistedCached = _persistedSnapshotForCardCode(lookupCode);
    if (persistedCached != null) {
      _storeInMemoryCache(lookupCode, persistedCached);
      return persistedCached;
    }

    final cached = await _assetSnapshotForCardCode(lookupCode);
    if (cached != null) {
      _saveSnapshotForCardCode(lookupCode, cached);
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
        _saveSnapshotForCardCode(lookupCode, snapshot);
        return snapshot;
      } catch (_) {
        if (verified != null) {
          _saveSnapshotForCardCode(lookupCode, verified);
          return verified;
        }
      }
    }

    final resolvedUrl =
        await _resolvePublicCardUrlForCard(
          cardName: cardName,
          cardCode: normalizedCode,
        ) ??
        buildPublicCardUrl(cardName: cardName, cardCode: normalizedCode);

    try {
      final snapshot = await fetchPublicCardSnapshot(url: resolvedUrl);
      _saveSnapshotForCardCode(lookupCode, snapshot);
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
          _saveSnapshotForCardCode(lookupCode, snapshot);
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
      _saveSnapshotForCardCode(lookupCode, snapshot);
      return snapshot;
    } catch (_) {
      if (verified != null) {
        _saveSnapshotForCardCode(lookupCode, verified);
        return verified;
      }
      rethrow;
    }
  }

  Future<LigaOnePieceCardSnapshot?> fetchCachedPublicCardSnapshotForCardCode(
    String cardCode,
  ) async {
    final normalizedCode = cardCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return null;
    }

    final remoteCached = await _remoteSnapshotForCardCode(normalizedCode);
    if (remoteCached != null) {
      _saveSnapshotForCardCode(normalizedCode, remoteCached);
      return remoteCached;
    }

    final memoryCached = _memorySnapshotForCardCode(normalizedCode);
    if (memoryCached != null) {
      return memoryCached;
    }

    final persistedCached = _persistedSnapshotForCardCode(normalizedCode);
    if (persistedCached != null) {
      _storeInMemoryCache(normalizedCode, persistedCached);
      return persistedCached;
    }

    final assetCached = await _assetSnapshotForCardCode(normalizedCode);
    if (assetCached != null) {
      _saveSnapshotForCardCode(normalizedCode, assetCached);
      return assetCached;
    }

    return null;
  }

  Future<LigaOnePieceCardSnapshot?> fetchCachedPublicCardSnapshotForCard({
    required String cardName,
    required String cardCode,
    String imageUrl = '',
  }) async {
    final lookupCode = lookupCodeForCard(
      cardName: cardName,
      cardCode: cardCode,
    );
    if (lookupCode.isEmpty) {
      return null;
    }

    final referenceKey = priceReferenceKeyForCard(
      cardName: cardName,
      cardCode: cardCode,
      imageUrl: imageUrl,
    );
    final remoteCached = await _remoteSnapshotForCard(
      cardName: cardName,
      cardCode: cardCode,
      imageUrl: imageUrl,
    );
    if (remoteCached != null) {
      _saveSnapshotForCardCode(referenceKey, remoteCached);
      return remoteCached;
    }
    if (classifyLigaVariant(
      cardName: cardName,
      cardCode: cardCode,
    ).requiresStrictMatch) {
      return null;
    }

    final memoryCached =
        _memorySnapshotForCardCode(referenceKey) ??
        _memorySnapshotForCardCode(lookupCode);
    if (memoryCached != null) {
      return memoryCached;
    }

    final persistedCached = _persistedSnapshotForCardCode(lookupCode);
    if (persistedCached != null) {
      _storeInMemoryCache(lookupCode, persistedCached);
      return persistedCached;
    }

    final assetCached = await _assetSnapshotForCardCode(lookupCode);
    if (assetCached != null) {
      _saveSnapshotForCardCode(lookupCode, assetCached);
      return assetCached;
    }

    return null;
  }

  Future<Map<String, LigaOnePieceCardSnapshot>>
  fetchCachedPublicCardSnapshotsForCards(
    Iterable<({String cardName, String cardCode, String imageUrl})> cards,
  ) async {
    final references = cards.toList(growable: false);
    if (references.isEmpty) {
      return const <String, LigaOnePieceCardSnapshot>{};
    }

    final snapshots = <String, LigaOnePieceCardSnapshot>{};
    final missingReferences =
        <
          ({
            String cardName,
            String cardCode,
            String imageUrl,
            String referenceKey,
          })
        >[];
    for (final card in references) {
      final referenceKey = priceReferenceKeyForCard(
        cardName: card.cardName,
        cardCode: card.cardCode,
        imageUrl: card.imageUrl,
      );
      final cached = _memorySnapshotForCardCode(referenceKey);
      if (cached == null) {
        missingReferences.add((
          cardName: card.cardName,
          cardCode: card.cardCode,
          imageUrl: card.imageUrl,
          referenceKey: referenceKey,
        ));
      } else {
        snapshots[referenceKey] = cached;
      }
    }

    final rowsByCode = <String, List<Map<String, dynamic>>>{};
    final confirmedMappings = await _loadConfirmedMappings(
      missingReferences.map((card) => card.referenceKey),
    );

    void indexRow(Map<String, dynamic> row, Object? rawCode) {
      final code = _normalizeLookupCode(rawCode?.toString() ?? '');
      if (code.isEmpty) return;
      final indexed = rowsByCode.putIfAbsent(code, () => []);
      if (!indexed.contains(row)) indexed.add(row);
    }

    const chunkSize = 80;
    final queryCodes = missingReferences
        .expand(
          (card) => lookupCodesForCard(
            cardName: card.cardName,
            cardCode: card.cardCode,
          ),
        )
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList(growable: false);
    for (var offset = 0; offset < queryCodes.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, queryCodes.length);
      final chunk = queryCodes.sublist(offset, end);
      try {
        const pageSize = 1000;
        var pageStart = 0;
        while (true) {
          final rows = await _supabase
              .from(_remoteCacheTable)
              .select()
              .inFilter('card_code', chunk)
              .range(pageStart, pageStart + pageSize - 1);
          for (final rawRow in rows) {
            final row = Map<String, dynamic>.from(rawRow);
            indexRow(row, row['card_code']);
            indexRow(row, row['lookup_code']);
          }
          if (rows.length < pageSize) break;
          pageStart += pageSize;
        }
      } catch (error, stackTrace) {
        AppErrorReporter.report(
          error,
          stackTrace,
          context: 'liga-price-batch-query',
        );
        // A lista continua utilizavel mesmo se o cache remoto estiver offline.
      }
    }
    final mappedLookupCodes = confirmedMappings.values.toSet().toList();
    for (
      var offset = 0;
      offset < mappedLookupCodes.length;
      offset += chunkSize
    ) {
      final end = (offset + chunkSize).clamp(0, mappedLookupCodes.length);
      final chunk = mappedLookupCodes.sublist(offset, end);
      try {
        final rows = await _supabase
            .from(_remoteCacheTable)
            .select()
            .inFilter('lookup_code', chunk);
        for (final rawRow in rows) {
          final row = Map<String, dynamic>.from(rawRow);
          indexRow(row, row['card_code']);
          indexRow(row, row['lookup_code']);
        }
      } catch (error, stackTrace) {
        AppErrorReporter.report(
          error,
          stackTrace,
          context: 'liga-price-mapped-batch-query',
        );
      }
    }

    for (final card in missingReferences) {
      try {
        final normalizedCode = _normalizeLookupCode(card.cardCode);
        final lookupCode = lookupCodeForCard(
          cardName: card.cardName,
          cardCode: card.cardCode,
        );
        final candidateCodes = lookupCodesForCard(
          cardName: card.cardName,
          cardCode: card.cardCode,
        );
        final candidates = <Map<String, dynamic>>{
          for (final code in candidateCodes) ...?rowsByCode[code],
        };
        final mappedLookup = confirmedMappings[card.referenceKey];
        final mappedRows = mappedLookup == null
            ? const <Map<String, dynamic>>[]
            : rowsByCode[mappedLookup] ?? const <Map<String, dynamic>>[];
        final mappedRow = mappedRows
            .where(
              (candidate) =>
                  _normalizeLookupCode(
                    candidate['lookup_code']?.toString() ?? '',
                  ) ==
                  mappedLookup,
            )
            .firstOrNull;
        final row =
            mappedRow ??
            selectBestRemoteRow(
              candidates,
              cardName: card.cardName,
              lookupCode: lookupCode,
              imageUrl: card.imageUrl,
            );
        final strictVariant = classifyLigaVariant(
          cardName: card.cardName,
          cardCode: card.cardCode,
        ).requiresStrictMatch;
        final snapshot = row == null
            ? (strictVariant || candidates.isNotEmpty)
                  ? null
                  : await _cachedFallbackForBatchCard(
                      referenceKey: card.referenceKey,
                      lookupCode: lookupCode,
                      normalizedCode: normalizedCode,
                    )
            : _snapshotFromRemoteRow(row);
        if (snapshot == null) continue;
        _registerBatchSnapshot(
          snapshots,
          referenceKey: card.referenceKey,
          lookupCode: lookupCode,
          normalizedCode: normalizedCode,
          snapshot: snapshot,
        );
      } catch (error, stackTrace) {
        AppErrorReporter.report(
          error,
          stackTrace,
          context: 'liga-price-batch-map',
        );
      }
    }

    return snapshots;
  }

  Future<LigaOnePieceCardSnapshot?> _cachedFallbackForBatchCard({
    required String referenceKey,
    required String lookupCode,
    required String normalizedCode,
  }) async {
    final memoryCached =
        _memorySnapshotForCardCode(referenceKey) ??
        _memorySnapshotForCardCode(lookupCode) ??
        _memorySnapshotForCardCode(normalizedCode);
    if (memoryCached != null) return memoryCached;

    final persistedCached =
        _persistedSnapshotForCardCode(lookupCode) ??
        _persistedSnapshotForCardCode(normalizedCode);
    if (persistedCached != null) return persistedCached;

    return await _assetSnapshotForCardCode(lookupCode) ??
        await _assetSnapshotForCardCode(normalizedCode);
  }

  void _registerBatchSnapshot(
    Map<String, LigaOnePieceCardSnapshot> snapshots, {
    required String referenceKey,
    required String lookupCode,
    required String normalizedCode,
    required LigaOnePieceCardSnapshot snapshot,
  }) {
    snapshots[referenceKey] = snapshot;
    snapshots.putIfAbsent(lookupCode, () => snapshot);
    if (lookupCode == normalizedCode) {
      snapshots.putIfAbsent(normalizedCode, () => snapshot);
    }
    _saveSnapshotForCardCode(referenceKey, snapshot);
    _saveSnapshotForCardCode(lookupCode, snapshot);
  }

  Future<LigaOnePieceCardSnapshot?> requestLigaCacheRefreshForCard({
    required String cardName,
    required String cardCode,
  }) async {
    if (!kIsWeb) return null;

    final normalizedCode = cardCode.trim().toUpperCase();
    final lookupCode = lookupCodeForCard(
      cardName: cardName,
      cardCode: normalizedCode,
    );
    if (normalizedCode.isEmpty) return null;

    try {
      final uri = Uri.base.resolve('/api/request-liga-cache-refresh');
      await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'cardName': cardName, 'cardCode': normalizedCode}),
      );
    } catch (_) {
      return null;
    }

    const waits = <Duration>[
      Duration(seconds: 6),
      Duration(seconds: 8),
      Duration(seconds: 10),
      Duration(seconds: 12),
      Duration(seconds: 14),
    ];

    for (final wait in waits) {
      await Future<void>.delayed(wait);
      final snapshot = await _remoteSnapshotForCardCode(lookupCode);
      if (snapshot != null) {
        _saveSnapshotForCardCode(lookupCode, snapshot);
        return snapshot;
      }
    }

    return null;
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
      queryParameters: {'view': 'cards/card', 'card': descriptor, 'tipo': '1'},
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
    return _memorySnapshotCache[cardCode] ??
        _memorySnapshotCache[normalizedCode];
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
      final row = await _supabase
          .from(_remoteCacheTable)
          .select()
          .eq('lookup_code', normalizedCode)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return _snapshotFromRemoteRow(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<LigaOnePieceCardSnapshot?> _remoteSnapshotForCard({
    required String cardName,
    required String cardCode,
    required String imageUrl,
  }) async {
    final referenceKey = priceReferenceKeyForCard(
      cardName: cardName,
      cardCode: cardCode,
      imageUrl: imageUrl,
    );
    final confirmedMappings = await _loadConfirmedMappings([referenceKey]);
    final mappedLookup = confirmedMappings[referenceKey];
    if (mappedLookup != null) {
      final mapped = await _remoteSnapshotForCardCode(mappedLookup);
      if (mapped != null) return mapped;
    }
    final requestedVariant = classifyLigaVariant(
      cardName: cardName,
      cardCode: cardCode,
    );
    try {
      final lookupCode = lookupCodeForCard(
        cardName: cardName,
        cardCode: cardCode,
      );
      final queryCodes = lookupCodesForCard(
        cardName: cardName,
        cardCode: cardCode,
      );
      if (queryCodes.isEmpty) return null;

      final rows = await _supabase
          .from(_remoteCacheTable)
          .select()
          .inFilter('card_code', queryCodes);
      final candidates = rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      final selected = selectBestRemoteRow(
        candidates,
        cardName: cardName,
        lookupCode: lookupCode,
        imageUrl: imageUrl,
      );
      return selected == null ? null : _snapshotFromRemoteRow(selected);
    } catch (_) {
      if (requestedVariant.requiresStrictMatch) return null;
    }

    if (requestedVariant.requiresStrictMatch) return null;
    return _remoteSnapshotForCardCode(
      lookupCodeForCard(cardName: cardName, cardCode: cardCode),
    );
  }

  Future<Map<String, String>> _loadConfirmedMappings(
    Iterable<String> referenceKeys,
  ) async {
    final keys = referenceKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    final pending = keys
        .where((key) => !_loadedMappingKeys.contains(key))
        .toList(growable: false);
    const chunkSize = 80;
    for (var offset = 0; offset < pending.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, pending.length);
      final chunk = pending.sublist(offset, end);
      try {
        final rows = await _supabase
            .from(_variantMappingTable)
            .select('catalog_variant_key, liga_lookup_code')
            .eq('game_slug', 'one-piece')
            .eq('status', 'confirmed')
            .inFilter('catalog_variant_key', chunk);
        for (final rawRow in rows) {
          final row = Map<String, dynamic>.from(rawRow);
          final key = row['catalog_variant_key']?.toString().trim() ?? '';
          final lookup = _normalizeLookupCode(
            row['liga_lookup_code']?.toString() ?? '',
          );
          if (key.isNotEmpty && lookup.isNotEmpty) {
            _confirmedMappingCache[key] = lookup;
          }
        }
      } catch (_) {
        // O seletor heuristico continua disponivel enquanto a auditoria carrega.
      } finally {
        _loadedMappingKeys.addAll(chunk);
      }
    }
    final result = <String, String>{};
    for (final key in keys) {
      final lookup = _confirmedMappingCache[key];
      if (lookup != null) result[key] = lookup;
    }
    return result;
  }

  @visibleForTesting
  static Map<String, dynamic>? selectBestRemoteRow(
    Iterable<Map<String, dynamic>> rows, {
    required String cardName,
    required String lookupCode,
    required String imageUrl,
  }) {
    Map<String, dynamic>? best;
    var bestScore = -1 << 30;
    DateTime? bestResolvedAt;
    String? bestPrintingIdentity;
    final bestPrintingIdentities = <String>{};
    final requestedVariant = classifyLigaVariant(
      cardName: cardName,
      cardCode: lookupCode,
    );
    final requestedImage = imageUrl.trim();
    final requestedImageIdentity = _imageIdentity(requestedImage);
    final requestedBaseCode = requestedVariant.baseCode;
    final expectedEdition = _expectedOriginalEdition(requestedBaseCode);

    for (final row in rows) {
      var score = 0;
      final rowLookup = (row['lookup_code']?.toString() ?? '')
          .trim()
          .toUpperCase();
      final edition = (row['edition_code']?.toString() ?? '')
          .trim()
          .toUpperCase();
      final rowImage = row['image_url']?.toString().trim() ?? '';
      final rowImageIdentity = _imageIdentity(rowImage);
      final rowCode = (row['card_code']?.toString() ?? rowLookup)
          .trim()
          .toUpperCase();
      final rowName = (row['card_name']?.toString() ?? '').trim();
      final candidateVariant = classifyLigaVariant(
        cardName: rowName,
        cardCode: rowCode,
      );
      if (candidateVariant.baseCode != requestedBaseCode ||
          !ligaVariantMatchesEditionHint(
            requestedVariant.kind,
            candidateVariant.kind,
            edition,
          )) {
        continue;
      }

      score +=
          ligaVariantKindsCompatible(
            requestedVariant.kind,
            candidateVariant.kind,
          )
          ? 900
          : 700;
      if (requestedImage.isNotEmpty && rowImage == requestedImage) {
        score += 1200;
      } else if (requestedImageIdentity.isNotEmpty &&
          rowImageIdentity == requestedImageIdentity) {
        score += 900;
      }
      if (!requestedVariant.requiresStrictMatch &&
          expectedEdition.isNotEmpty &&
          edition == expectedEdition) {
        score += 380;
      }

      final resolvedAt = DateTime.tryParse(
        row['resolved_at']?.toString() ?? '',
      );
      final printingIdentity = [
        rowCode,
        edition,
        rowImageIdentity,
        row['minimum_price']?.toString() ?? '',
      ].join('|');
      if (best == null || score > bestScore) {
        best = row;
        bestScore = score;
        bestResolvedAt = resolvedAt;
        bestPrintingIdentity = printingIdentity;
        bestPrintingIdentities
          ..clear()
          ..add(printingIdentity);
      } else if (score == bestScore) {
        bestPrintingIdentities.add(printingIdentity);
        if (printingIdentity == bestPrintingIdentity &&
            resolvedAt != null &&
            (bestResolvedAt == null || resolvedAt.isAfter(bestResolvedAt))) {
          best = row;
          bestResolvedAt = resolvedAt;
        }
      }
    }

    return bestPrintingIdentities.length > 1 ? null : best;
  }

  static String _expectedOriginalEdition(String cardCode) {
    final match = RegExp(r'^(OP|EB|ST)(\d{2})-').firstMatch(cardCode);
    if (match == null) return '';
    return switch (match.group(1)) {
      'OP' => 'OP-${match.group(2)}',
      'EB' => 'EB${match.group(2)}',
      'ST' => 'ST${match.group(2)}',
      _ => '',
    };
  }

  static String _imageIdentity(String imageUrl) {
    final value = imageUrl.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    final path = uri?.path ?? value;
    final fileName = path.split('/').last.toLowerCase();
    return fileName.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  LigaOnePieceCardSnapshot _snapshotFromRemoteRow(Map<String, dynamic> row) {
    final snapshot = LigaOnePieceCardSnapshot.fromJson({
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
      'resolvedAt': row['resolved_at'],
    });

    return snapshot.copyWith(
      note:
          'Cache compartilhado do app salvo no Supabase. A leitura direta da LigaOnePiece pode falhar no web.',
    );
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
  }

  void _storeInMemoryCache(String cardCode, LigaOnePieceCardSnapshot snapshot) {
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
          'resolvedAt': decoded['updatedAt'],
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
    if (kIsWeb) {
      final knownFallback = _verifiedFallbackForKnownUrl(url);
      if (knownFallback != null) {
        return knownFallback;
      }

      try {
        final snapshot = await _fetchUrlViaProxy(url);
        final normalizedCode = _normalizeLookupCode(snapshot.cardCode);
        if (normalizedCode.isNotEmpty) {
          _saveSnapshotForCardCode(normalizedCode, snapshot);
        }
        return snapshot;
      } catch (error) {
        final fallback = _verifiedFallbackFor(url, error);
        if (fallback != null) {
          return fallback;
        }
        throw Exception(_buildReadableError(error));
      }
    }

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
      final stock = _decodeInlineJsonList(html, variableName: 'cards_stock');
      final stores = _decodeInlineJsonMap(html, variableName: 'cards_stores');

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
      final requestedDescriptor =
          Uri.tryParse(url)?.queryParameters['card'] ?? cardName;
      final preferFoil = _wantsFoilPrice(requestedDescriptor);
      final publicPrices = _selectPriceMap(edition['price'], preferFoil);
      final desiredExtra = preferFoil ? 2 : 0;

      final minimumPrice = _parseMoney(publicPrices['p']);
      final averagePrice = _parseMoney(publicPrices['m']);
      final maximumPrice = _parseMoney(publicPrices['g']);

      final listings =
          stock
              .where((item) {
                if (item['extras'] == null) return true;
                return int.tryParse(_stringValue(item['extras'])) ==
                    desiredExtra;
              })
              .map(LigaOnePieceListing.fromJson)
              .toList(growable: false)
            ..sort((a, b) => a.price.compareTo(b.price));

      final lowestListing = listings.isEmpty ? null : listings.first;
      final lowestStore = lowestListing == null
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

  Future<LigaOnePieceCardSnapshot> _fetchUrlViaProxy(String url) async {
    final proxyUri = Uri.base
        .resolve('/api/liga-one-piece')
        .replace(queryParameters: {'url': url});

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

    return LigaOnePieceCardSnapshot.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<LigaOnePieceCardSnapshot> _fetchViaProxy({
    required String cardName,
    required String cardCode,
  }) async {
    final proxyUri = Uri.base
        .resolve('/api/liga-one-piece')
        .replace(queryParameters: {'cardName': cardName, 'cardCode': cardCode});

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

    return LigaOnePieceCardSnapshot.fromJson(
      Map<String, dynamic>.from(decoded),
    );
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

  bool _wantsFoilPrice(String cardName) {
    final normalized = cardName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (normalized.isEmpty) return false;

    final tokens = normalized.split(RegExp(r'\s+')).toSet();
    return tokens.contains('sp') ||
        normalized.contains('alternate art') ||
        normalized.contains('alt art') ||
        normalized.contains('parallel') ||
        normalized.contains('manga') ||
        normalized.contains('special') ||
        normalized.contains('treasure') ||
        normalized.contains('wanted');
  }

  Map<String, dynamic> _selectPriceMap(dynamic rawPrice, bool preferFoil) {
    if (rawPrice is List) {
      if (rawPrice.isEmpty) return const <String, dynamic>{};
      final foilIndex = rawPrice.length > 2 ? 2 : 1;
      final index = preferFoil ? foilIndex : 0;
      return _mapValue(index < rawPrice.length ? rawPrice[index] : rawPrice[0]);
    }

    final priceMap = _mapValue(rawPrice);
    if (preferFoil) {
      final foilPrice = _mapValue(priceMap['2'] ?? priceMap['1']);
      if (foilPrice.isNotEmpty) return foilPrice;
    }

    final normalPrice = _mapValue(priceMap['0']);
    if (normalPrice.isNotEmpty) return normalPrice;

    for (final value in priceMap.values) {
      final nested = _mapValue(value);
      if (nested.isNotEmpty) return nested;
    }

    return priceMap;
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

    return _verifiedFallbackForKnownUrl(url);
  }

  LigaOnePieceCardSnapshot? _verifiedFallbackForKnownUrl(String url) {
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

    return _verifiedFallbackFromParts(card: card, num: num, edition: edition);
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
    final wantsAlternate = _normalizeTextForMatching(
      cardName,
    ).contains('alternate art');
    final wantsSp = RegExp(
      r'(^|[\s(])sp([\s)])',
      caseSensitive: false,
    ).hasMatch(cardName);

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

      final nameWords = normalizedName
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
    final ligaCode = isReprint && !cardCode.endsWith('-RE')
        ? '$cardCode-RE'
        : cardCode;
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
    name = name.replaceAll(
      RegExp(
        r'\s*\((?:Alternate Art|Alt Art|SP|Parallel|Manga|Special|Treasure|Wanted)\)',
        caseSensitive: false,
      ),
      '',
    );
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
    final match = RegExp(
      r'^([A-Z]{1,4})(\d{2})-\d{3}(?:-[A-Z0-9]+)?$',
    ).firstMatch(cardCode);
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
  static const Duration staleAfter = Duration(hours: 30);

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
  final DateTime? resolvedAt;

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
    this.resolvedAt,
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
      lowestListing: json['lowestListing'] is Map
          ? LigaOnePieceListing.fromJson(
              Map<String, dynamic>.from(json['lowestListing'] as Map),
            )
          : null,
      lowestStore: json['lowestStore'] is Map
          ? LigaOnePieceStore.fromJson(
              Map<String, dynamic>.from(json['lowestStore'] as Map),
            )
          : null,
      historyEndpointRequiresLogin:
          json['historyEndpointRequiresLogin'] == true,
      usedVerifiedFallback: json['usedVerifiedFallback'] == true,
      note: json['note']?.toString(),
      resolvedAt: DateTime.tryParse(json['resolvedAt']?.toString() ?? ''),
    );
  }

  bool get isStale {
    final value = resolvedAt;
    if (value == null) return true;
    return DateTime.now().toUtc().difference(value.toUtc()) > staleAfter;
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
      'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
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
    DateTime? resolvedAt,
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
      resolvedAt: resolvedAt ?? this.resolvedAt,
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
          int.tryParse((json['quantity'] ?? json['quant'])?.toString() ?? '') ??
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
    return {'name': name, 'city': city, 'state': state, 'phone': phone};
  }
}
