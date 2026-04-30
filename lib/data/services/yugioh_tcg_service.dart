import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/yugioh_card.dart';

final yugiohTcgServiceProvider = Provider<YugiohTcgService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return YugiohTcgService(client);
});

class YugiohCardSearchResult {
  final List<YugiohCard> cards;
  final int page;
  final int pageSize;
  final int totalCount;

  const YugiohCardSearchResult({
    required this.cards,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  bool get hasMore => page * pageSize < totalCount;
}

class YugiohTcgService {
  final http.Client _client;

  YugiohTcgService(this._client);

  Future<YugiohCardSearchResult> searchCards({
    required String query,
    required int page,
    int pageSize = 60,
  }) async {
    final offset = (page - 1) * pageSize;
    final queryParameters = <String, String>{
      'num': '$pageSize',
      'offset': '$offset',
    };

    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      queryParameters['sort'] = 'new';
    } else {
      queryParameters['fname'] = normalizedQuery;
    }

    final uri = Uri.https(
      'db.ygoprodeck.com',
      '/api/v7/cardinfo.php',
      queryParameters,
    );
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('YGOPRODeck retornou ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['error'] != null) {
      return YugiohCardSearchResult(
        cards: const [],
        page: page,
        pageSize: pageSize,
        totalCount: 0,
      );
    }

    final data = (payload['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(YugiohCard.fromJson)
        .toList(growable: false);
    final meta = payload['meta'] as Map<String, dynamic>? ?? const {};
    final totalCount = (meta['total_rows'] as num?)?.toInt() ?? data.length;

    return YugiohCardSearchResult(
      cards: data,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }
}
