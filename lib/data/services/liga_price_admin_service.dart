import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/op_card.dart';
import 'liga_variant_classifier.dart';
import 'op_api_service.dart';
import 'supabase_client_provider.dart';

final ligaPriceAdminServiceProvider = Provider<LigaPriceAdminService>((ref) {
  return LigaPriceAdminService(
    ref.watch(supabaseClientProvider),
    ref.watch(opApiServiceProvider),
  );
});

enum LigaEditionUpdateState { current, partial, stale, neverUpdated }

class LigaEditionPriceStatus {
  final int editionId;
  final String acronym;
  final DateTime? releaseDate;
  final String group;
  final int cardCount;
  final int pricedCardCount;
  final DateTime? oldestUpdate;
  final DateTime? latestUpdate;

  const LigaEditionPriceStatus({
    required this.editionId,
    required this.acronym,
    required this.releaseDate,
    required this.group,
    required this.cardCount,
    required this.pricedCardCount,
    required this.oldestUpdate,
    required this.latestUpdate,
  });

  LigaEditionUpdateState stateAt(
    DateTime now, {
    Duration maximumAge = const Duration(hours: 30),
  }) {
    final newest = latestUpdate;
    if (newest == null) return LigaEditionUpdateState.neverUpdated;
    if (now.toUtc().difference(newest.toUtc()) > maximumAge) {
      return LigaEditionUpdateState.stale;
    }
    final oldest = oldestUpdate;
    if (oldest != null && now.toUtc().difference(oldest.toUtc()) > maximumAge) {
      return LigaEditionUpdateState.partial;
    }
    return LigaEditionUpdateState.current;
  }

  double get pricedRatio => cardCount == 0 ? 0 : pricedCardCount / cardCount;
}

class LigaVariantAuditSummary {
  final int catalogCardCount;
  final int multiPrintingFamilyCount;
  final int cardsInMultiPrintingFamilies;
  final int maximumVariantsPerCode;
  final int uniquelyMatchedCards;
  final int ambiguousCards;
  final int missingCards;
  final Map<String, int> variantCounts;
  final int auditedPriceRows;
  final DateTime? lastAuditAt;

  const LigaVariantAuditSummary({
    required this.catalogCardCount,
    required this.multiPrintingFamilyCount,
    required this.cardsInMultiPrintingFamilies,
    required this.maximumVariantsPerCode,
    required this.uniquelyMatchedCards,
    required this.ambiguousCards,
    required this.missingCards,
    required this.variantCounts,
    this.auditedPriceRows = 0,
    this.lastAuditAt,
  });

  double get safeCoverageRatio =>
      catalogCardCount == 0 ? 0 : uniquelyMatchedCards / catalogCardCount;
}

class LigaPriceAdminDashboardData {
  final List<LigaEditionPriceStatus> editionStatuses;
  final LigaVariantAuditSummary variantAudit;

  const LigaPriceAdminDashboardData({
    required this.editionStatuses,
    required this.variantAudit,
  });
}

class LigaPriceAdminService {
  static const _editionsAsset = 'assets/liga_one_piece_editions.json';
  static const _priceTable = 'liga_card_price_cache';
  static const _pageSize = 1000;

  final SupabaseClient _client;
  final OpApiService _opApi;

  LigaPriceAdminService(this._client, this._opApi);

  Future<LigaPriceAdminDashboardData> loadDashboardData() async {
    final results = await Future.wait<dynamic>([
      rootBundle.loadString(_editionsAsset),
      _loadAllPriceRows(),
      _opApi.loadAllCards(),
      _loadLatestAuditRun(),
    ]);
    final rawCatalog = jsonDecode(results[0] as String);
    final catalog = (rawCatalog as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final priceRows = results[1] as List<Map<String, dynamic>>;
    final cards = results[2] as List<OpCard>;
    final auditRun = results[3] as Map<String, dynamic>?;
    final computedAudit = buildVariantAudit(cards: cards, priceRows: priceRows);
    return LigaPriceAdminDashboardData(
      editionStatuses: buildEditionStatuses(
        catalog: catalog,
        priceRows: priceRows,
      ),
      variantAudit: auditRun == null
          ? computedAudit
          : LigaVariantAuditSummary(
              catalogCardCount:
                  _asInt(auditRun['catalog_card_count']) ??
                  computedAudit.catalogCardCount,
              multiPrintingFamilyCount: computedAudit.multiPrintingFamilyCount,
              cardsInMultiPrintingFamilies:
                  computedAudit.cardsInMultiPrintingFamilies,
              maximumVariantsPerCode: computedAudit.maximumVariantsPerCode,
              uniquelyMatchedCards:
                  _asInt(auditRun['uniquely_matched_count']) ??
                  computedAudit.uniquelyMatchedCards,
              ambiguousCards:
                  _asInt(auditRun['ambiguous_count']) ??
                  computedAudit.ambiguousCards,
              missingCards:
                  _asInt(auditRun['missing_count']) ??
                  computedAudit.missingCards,
              variantCounts: computedAudit.variantCounts,
              auditedPriceRows:
                  _asInt((auditRun['details'] as Map?)?['price_rows']) ??
                  priceRows.length,
              lastAuditAt: DateTime.tryParse(
                auditRun['completed_at']?.toString() ?? '',
              ),
            ),
    );
  }

  Future<Map<String, dynamic>?> _loadLatestAuditRun() async {
    try {
      final rows = await _client
          .from('liga_price_audit_runs')
          .select(
            'catalog_card_count, uniquely_matched_count, ambiguous_count, '
            'missing_count, details, completed_at',
          )
          .eq('game_slug', 'one-piece')
          .eq('status', 'completed')
          .order('started_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<List<LigaEditionPriceStatus>> loadEditionStatuses() async {
    final rawCatalog = jsonDecode(await rootBundle.loadString(_editionsAsset));
    final catalog = (rawCatalog as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final rows = await _loadAllPriceRows();
    return buildEditionStatuses(catalog: catalog, priceRows: rows);
  }

  Future<List<Map<String, dynamic>>> _loadAllPriceRows() async {
    final allRows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await _client
          .from(_priceTable)
          .select(
            'lookup_code, card_code, card_name, edition_code, image_url, '
            'resolved_at, minimum_price',
          )
          .range(from, from + _pageSize - 1);
      final typedPage = page
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      allRows.addAll(typedPage);
      if (typedPage.length < _pageSize) break;
      from += _pageSize;
    }
    return allRows;
  }

  static List<LigaEditionPriceStatus> buildEditionStatuses({
    required List<Map<String, dynamic>> catalog,
    required List<Map<String, dynamic>> priceRows,
  }) {
    final aggregates = <String, _EditionAggregate>{};
    for (final row in priceRows) {
      final code = row['edition_code']?.toString().trim().toUpperCase() ?? '';
      if (code.isEmpty) continue;
      final aggregate = aggregates.putIfAbsent(code, _EditionAggregate.new);
      aggregate.cardCount++;
      if (row['minimum_price'] != null) aggregate.pricedCardCount++;
      final resolvedAt = DateTime.tryParse(
        row['resolved_at']?.toString() ?? '',
      );
      if (resolvedAt == null) continue;
      if (aggregate.oldestUpdate == null ||
          resolvedAt.isBefore(aggregate.oldestUpdate!)) {
        aggregate.oldestUpdate = resolvedAt;
      }
      if (aggregate.latestUpdate == null ||
          resolvedAt.isAfter(aggregate.latestUpdate!)) {
        aggregate.latestUpdate = resolvedAt;
      }
    }

    return catalog
        .map((edition) {
          final acronym =
              edition['acronym']?.toString().trim().toUpperCase() ?? '';
          final aggregate = aggregates[acronym];
          return LigaEditionPriceStatus(
            editionId:
                int.tryParse(edition['edition_id']?.toString() ?? '') ?? 0,
            acronym: acronym,
            releaseDate: DateTime.tryParse(
              edition['release_date']?.toString() ?? '',
            ),
            group: edition['group']?.toString() ?? 'main',
            cardCount: aggregate?.cardCount ?? 0,
            pricedCardCount: aggregate?.pricedCardCount ?? 0,
            oldestUpdate: aggregate?.oldestUpdate,
            latestUpdate: aggregate?.latestUpdate,
          );
        })
        .toList(growable: false);
  }

  static LigaVariantAuditSummary buildVariantAudit({
    required List<OpCard> cards,
    required List<Map<String, dynamic>> priceRows,
  }) {
    final cardsByCode = <String, List<OpCard>>{};
    final rowsByCode = <String, List<Map<String, dynamic>>>{};
    final variantCounts = <String, int>{};

    for (final card in cards) {
      final code = baseLigaCardCode(card.code);
      if (code.isEmpty) continue;
      cardsByCode.putIfAbsent(code, () => <OpCard>[]).add(card);
      final descriptor = classifyLigaVariant(
        cardName: card.name,
        cardCode: card.code,
      );
      if (descriptor.kind != LigaVariantKind.normal) {
        final label = ligaVariantKindLabel(descriptor.kind);
        variantCounts[label] = (variantCounts[label] ?? 0) + 1;
      }
    }
    for (final row in priceRows) {
      if (row['minimum_price'] == null) continue;
      final rowCode = (row['card_code'] ?? row['lookup_code'] ?? '').toString();
      final code = baseLigaCardCode(rowCode);
      if (code.isEmpty) continue;
      rowsByCode.putIfAbsent(code, () => <Map<String, dynamic>>[]).add(row);
    }

    var unique = 0;
    var ambiguous = 0;
    var missing = 0;
    for (final card in cards) {
      final requested = classifyLigaVariant(
        cardName: card.name,
        cardCode: card.code,
      );
      var candidates = (rowsByCode[requested.baseCode] ?? const [])
          .where((row) {
            final rowCode = (row['card_code'] ?? row['lookup_code'] ?? '')
                .toString();
            final candidate = classifyLigaVariant(
              cardName: row['card_name']?.toString() ?? '',
              cardCode: rowCode,
            );
            return ligaVariantMatchesEditionHint(
              requested.kind,
              candidate.kind,
              row['edition_code']?.toString() ?? '',
            );
          })
          .toList(growable: false);
      final imageIdentity = _imageIdentity(card.image);
      if (imageIdentity.isNotEmpty) {
        final exactImages = candidates
            .where(
              (row) =>
                  _imageIdentity(row['image_url']?.toString() ?? '') ==
                  imageIdentity,
            )
            .toList(growable: false);
        if (exactImages.isNotEmpty) candidates = exactImages;
      }
      final identities = candidates.map(_printingIdentity).toSet();
      if (identities.isEmpty) {
        missing++;
      } else if (identities.length == 1) {
        unique++;
      } else {
        ambiguous++;
      }
    }

    final multipleFamilies = cardsByCode.values
        .where((family) => family.length > 1)
        .toList(growable: false);
    final sortedCounts = Map<String, int>.fromEntries(
      variantCounts.entries.toList()
        ..sort((left, right) => right.value.compareTo(left.value)),
    );
    return LigaVariantAuditSummary(
      catalogCardCount: cards.length,
      multiPrintingFamilyCount: multipleFamilies.length,
      cardsInMultiPrintingFamilies: multipleFamilies.fold(
        0,
        (total, family) => total + family.length,
      ),
      maximumVariantsPerCode: cardsByCode.values.fold(
        0,
        (maximum, family) => family.length > maximum ? family.length : maximum,
      ),
      uniquelyMatchedCards: unique,
      ambiguousCards: ambiguous,
      missingCards: missing,
      variantCounts: sortedCounts,
    );
  }

  static String _printingIdentity(Map<String, dynamic> row) {
    final cardCode = (row['card_code'] ?? row['lookup_code'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final edition = row['edition_code']?.toString().trim().toUpperCase() ?? '';
    final image = _imageIdentity(row['image_url']?.toString() ?? '');
    final price = row['minimum_price']?.toString() ?? '';
    return '$cardCode|$edition|$image|$price';
  }

  static String _imageIdentity(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.pathSegments.isEmpty) return '';
    return uri.pathSegments.last.toLowerCase().split('?').first;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _EditionAggregate {
  int cardCount = 0;
  int pricedCardCount = 0;
  DateTime? oldestUpdate;
  DateTime? latestUpdate;
}
