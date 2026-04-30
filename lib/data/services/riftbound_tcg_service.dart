import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/riftbound_card.dart';

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
        'User-Agent': 'TCGManager/1.0',
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
}
