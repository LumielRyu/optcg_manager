import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_error_reporter.dart';
import 'supabase_client_provider.dart';

final ligaTcgPriceServiceProvider = Provider<LigaTcgPriceService>((ref) {
  return LigaTcgPriceService(ref.watch(supabaseClientProvider));
});

class LigaTcgPriceSnapshot {
  static const staleAfter = Duration(hours: 30);

  final String lookupCode;
  final String sourceUrl;
  final String cardName;
  final String editionCode;
  final double? minimumPrice;
  final DateTime? resolvedAt;

  const LigaTcgPriceSnapshot({
    required this.lookupCode,
    required this.sourceUrl,
    required this.cardName,
    required this.editionCode,
    required this.minimumPrice,
    required this.resolvedAt,
  });

  factory LigaTcgPriceSnapshot.fromRow(Map<String, dynamic> row) {
    return LigaTcgPriceSnapshot(
      lookupCode: (row['lookup_code'] ?? '').toString().trim().toUpperCase(),
      sourceUrl: (row['source_url'] ?? '').toString().trim(),
      cardName: (row['card_name'] ?? '').toString().trim(),
      editionCode: (row['edition_code'] ?? '').toString().trim(),
      minimumPrice: double.tryParse((row['minimum_price'] ?? '').toString()),
      resolvedAt: DateTime.tryParse((row['resolved_at'] ?? '').toString()),
    );
  }

  bool get isStale {
    final timestamp = resolvedAt;
    if (timestamp == null) return true;
    return DateTime.now().toUtc().difference(timestamp.toUtc()) > staleAfter;
  }
}

class LigaTcgPriceService {
  static const _table = 'liga_card_price_cache';
  final SupabaseClient _supabase;

  LigaTcgPriceService(this._supabase);

  Future<Map<String, LigaTcgPriceSnapshot>> fetchSnapshots(
    Iterable<String> lookupCodes,
  ) async {
    final normalized = lookupCodes
        .map(normalizeLookupCode)
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) return const {};

    final snapshots = <String, LigaTcgPriceSnapshot>{};
    const chunkSize = 80;
    for (var offset = 0; offset < normalized.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, normalized.length);
      final chunk = normalized.sublist(offset, end);
      try {
        final rows = await _supabase
            .from(_table)
            .select(
              'lookup_code, source_url, card_name, edition_code, '
              'minimum_price, resolved_at',
            )
            .inFilter('lookup_code', chunk);
        for (final rawRow in rows) {
          final snapshot = LigaTcgPriceSnapshot.fromRow(
            Map<String, dynamic>.from(rawRow),
          );
          if (snapshot.lookupCode.isNotEmpty) {
            snapshots[snapshot.lookupCode] = snapshot;
          }
        }
      } catch (error, stackTrace) {
        AppErrorReporter.report(
          error,
          stackTrace,
          context: 'liga-tcg-price-query',
        );
      }
    }
    return snapshots;
  }

  String pokemonLookupCode({
    required String setCode,
    required String setId,
    required String number,
  }) {
    final edition = setCode.trim().isEmpty ? setId : setCode;
    return normalizeLookupCode(
      'POKEMON:${edition.trim().toUpperCase()}:${normalizeCardNumber(number)}',
    );
  }

  static String normalizeLookupCode(String value) {
    return value.trim().toUpperCase();
  }

  static String normalizeCardNumber(String value) {
    var normalized = value.trim().toUpperCase().replaceFirst('#', '');
    if (normalized.contains('/')) {
      normalized = normalized.split('/').first;
    }
    final numeric = int.tryParse(normalized);
    return numeric?.toString() ?? normalized;
  }
}
