import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_provider.dart';

final ligaPriceAdminServiceProvider = Provider<LigaPriceAdminService>((ref) {
  return LigaPriceAdminService(ref.watch(supabaseClientProvider));
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

class LigaPriceAdminService {
  static const _editionsAsset = 'assets/liga_one_piece_editions.json';
  static const _priceTable = 'liga_card_price_cache';
  static const _pageSize = 1000;

  final SupabaseClient _client;

  LigaPriceAdminService(this._client);

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
          .select('edition_code, resolved_at, minimum_price')
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
}

class _EditionAggregate {
  int cardCount = 0;
  int pricedCardCount = 0;
  DateTime? oldestUpdate;
  DateTime? latestUpdate;
}
