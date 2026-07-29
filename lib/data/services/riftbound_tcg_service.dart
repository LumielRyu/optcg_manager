import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/riftbound_card.dart';
import '../../core/tcg/riftbound_text_deck_parser.dart';

final riftboundTcgServiceProvider = Provider<RiftboundTcgService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RiftboundTcgService(client);
});

class RiftboundCardSearchResult {
  final List<RiftboundCard> cards;
  final int page;
  final int pageSize;
  final int totalCount;

  const RiftboundCardSearchResult({
    required this.cards,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  bool get hasMore => page * pageSize < totalCount;
}

class RiftboundTcgService {
  final http.Client _client;

  RiftboundTcgService(this._client);

  Future<RiftboundCardSearchResult> searchCards({
    required String query,
    required int page,
    int pageSize = 60,
  }) async {
    final normalizedQuery = query.trim();
    final Uri uri;
    if (normalizedQuery.isEmpty) {
      uri = Uri.https('api.riftcodex.com', '/cards', {
        'size': '$pageSize',
        'page': '$page',
        'sort': 'collector_number',
      });
    } else {
      uri = Uri.https('api.riftcodex.com', '/cards/name', {
        'fuzzy': normalizedQuery,
        'size': '$pageSize',
        'page': '$page',
      });
    }

    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'TCG-BH/1.0 (+https://tcgbh.vercel.app)',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Riftcodex retornou ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final cards = (payload['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RiftboundCard.fromJson)
        .toList(growable: false);

    return RiftboundCardSearchResult(
      cards: cards,
      page: (payload['page'] as num?)?.toInt() ?? page,
      pageSize: (payload['size'] as num?)?.toInt() ?? pageSize,
      totalCount: (payload['total'] as num?)?.toInt() ?? cards.length,
    );
  }

  Future<Map<String, List<RiftboundCard>>> resolveExactNames(
    Iterable<String> names,
  ) async {
    final uniqueNames = <String, String>{};
    for (final name in names) {
      final normalized = normalizeRiftboundCardName(name);
      if (normalized.isNotEmpty) {
        uniqueNames.putIfAbsent(normalized, () => name.trim());
      }
    }

    final resolved = <String, List<RiftboundCard>>{};
    final pending = uniqueNames.entries.toList(growable: false);
    const concurrency = 4;
    for (var offset = 0; offset < pending.length; offset += concurrency) {
      final end = (offset + concurrency).clamp(0, pending.length);
      final chunk = pending.sublist(offset, end);
      final results = await Future.wait(
        chunk.map(
          (entry) async =>
              MapEntry(entry.key, await _findExactNameCandidates(entry.value)),
        ),
      );
      resolved.addEntries(results);
    }
    return resolved;
  }

  Future<List<RiftboundCard>> _findExactNameCandidates(String name) async {
    final result = await searchCards(query: name, page: 1, pageSize: 100);
    final normalizedName = normalizeRiftboundBaseCardName(name);
    final unique = <String, RiftboundCard>{};
    for (final card in result.cards) {
      if (normalizeRiftboundBaseCardName(card.name) != normalizedName) {
        continue;
      }
      unique.putIfAbsent(card.ligaLookupCode, () => card);
    }
    final cards = unique.values.toList(growable: false)
      ..sort(_compareImportCandidates);
    return cards;
  }

  int _compareImportCandidates(RiftboundCard left, RiftboundCard right) {
    const setPriority = {
      'UNL': 0,
      'SFD': 1,
      'OGN': 2,
      'OGS': 3,
      'VEN': 4,
      'PR': 5,
      'OPP': 6,
      'JDG': 7,
    };
    final leftPriority = setPriority[left.setCode.toUpperCase()] ?? 99;
    final rightPriority = setPriority[right.setCode.toUpperCase()] ?? 99;
    final bySet = leftPriority.compareTo(rightPriority);
    if (bySet != 0) return bySet;
    final byNumber = left.collectorNumber.compareTo(right.collectorNumber);
    if (byNumber != 0) return byNumber;
    return left.riftboundId.compareTo(right.riftboundId);
  }
}
