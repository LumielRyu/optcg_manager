import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/magic_card.dart';

final magicTcgServiceProvider = Provider<MagicTcgService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return MagicTcgService(client);
});

class MagicCardSearchResult {
  final List<MagicCard> cards;
  final int page;
  final int pageSize;
  final bool hasMore;

  const MagicCardSearchResult({
    required this.cards,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
}

class MagicTcgService {
  final http.Client _client;

  MagicTcgService(this._client);

  Future<MagicCardSearchResult> searchCards({
    required String query,
    required int page,
    int pageSize = 60,
  }) async {
    final normalizedQuery = query.trim();
    final queryParameters = <String, String>{
      'order': 'released',
      'dir': 'desc',
      'page': '$page',
    };

    if (normalizedQuery.isEmpty) {
      queryParameters['q'] = 'game:paper';
    } else {
      queryParameters['q'] = normalizedQuery;
    }

    final uri = Uri.https('api.scryfall.com', '/cards/search', queryParameters);
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'TCGManager/1.0',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Scryfall retornou ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final cards = (payload['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MagicCard.fromJson)
        .where((card) => card.imageUrl.isNotEmpty)
        .take(pageSize)
        .toList(growable: false);

    return MagicCardSearchResult(
      cards: cards,
      page: page,
      pageSize: pageSize,
      hasMore: payload['has_more'] == true,
    );
  }
}
