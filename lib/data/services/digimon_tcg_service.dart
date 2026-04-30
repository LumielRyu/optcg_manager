import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/digimon_card.dart';

final digimonTcgServiceProvider = Provider<DigimonTcgService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return DigimonTcgService(client);
});

class DigimonCardSearchResult {
  final List<DigimonCard> cards;
  final int page;
  final int pageSize;
  final int totalCount;

  const DigimonCardSearchResult({
    required this.cards,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  bool get hasMore => page * pageSize < totalCount;
}

class DigimonTcgService {
  final http.Client _client;

  DigimonTcgService(this._client);

  Future<DigimonCardSearchResult> searchCards({
    required String query,
    required int page,
    int pageSize = 60,
  }) async {
    final normalizedQuery = query.trim();
    final searchQuery = normalizedQuery.isEmpty
        ? 'category:digimon'
        : normalizedQuery;
    final uri = Uri.https('api.heroi.cc', '/search', {
      'q': searchQuery,
      'page': '$page',
    });

    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.api+json',
        'Accept-Language': 'en',
        'User-Agent': 'TCGManager/1.0',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Heroicc retornou ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final releases = <String, String>{};
    for (final item in (payload['included'] as List<dynamic>? ?? const [])) {
      if (item is! Map<String, dynamic>) continue;
      final id = (item['id'] ?? '').toString().trim();
      final meta = (item['meta'] as Map<String, dynamic>? ?? const {});
      final name = (meta['name'] ?? '').toString().trim();
      if (id.isNotEmpty && name.isNotEmpty) {
        releases[id] = name;
      }
    }

    final allCards = (payload['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => _mapCard(item, releases))
        .toList(growable: false);

    final pagedCards = allCards.take(pageSize).toList(growable: false);
    final totalCount =
        (payload['meta'] as Map<String, dynamic>? ?? const {})['total-cards']
            as num? ??
        allCards.length;

    return DigimonCardSearchResult(
      cards: pagedCards,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount.toInt(),
    );
  }

  DigimonCard _mapCard(
    Map<String, dynamic> item,
    Map<String, String> releases,
  ) {
    final attributes = item['attributes'] as Map<String, dynamic>? ?? const {};
    final relationships =
        item['relationships'] as Map<String, dynamic>? ?? const {};
    final releasesData =
        (relationships['releases'] as Map<String, dynamic>? ??
        const {})['data'];

    String setName = (attributes['notes'] ?? '').toString().trim();
    if (releasesData is List && releasesData.isNotEmpty) {
      final first = releasesData.first;
      if (first is Map<String, dynamic>) {
        final releaseId = (first['id'] ?? '').toString().trim();
        setName = releases[releaseId] ?? setName;
      }
    }

    return DigimonCard(
      id: (item['id'] ?? '').toString().trim(),
      name: (attributes['name'] ?? '').toString().trim(),
      number: (attributes['number'] ?? '').toString().trim(),
      imageUrl: (attributes['image'] ?? '').toString().trim(),
      category: (attributes['category'] ?? '').toString().trim(),
      rarity: (attributes['rarity'] ?? '').toString().trim(),
      attribute: (attributes['attribute'] ?? '').toString().trim(),
      type: (attributes['type'] ?? '').toString().trim(),
      form: (attributes['form'] ?? '').toString().trim(),
      effect: (attributes['effect'] ?? '').toString().trim(),
      inheritedEffect: (attributes['inherited-effect'] ?? '').toString().trim(),
      securityEffect: (attributes['security-effect'] ?? '').toString().trim(),
      setName: setName,
      colors: (attributes['color'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      level: (attributes['level'] as num?)?.toInt() ?? 0,
      playCost: (attributes['play-cost'] as num?)?.toInt() ?? 0,
      dp: (attributes['dp'] as num?)?.toInt() ?? 0,
    );
  }
}
