import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/pokemon_card.dart';

final pokemonTcgServiceProvider = Provider<PokemonTcgService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PokemonTcgService(client);
});

class PokemonCardSearchResult {
  final List<PokemonCard> cards;
  final int page;
  final int pageSize;
  final int totalCount;

  const PokemonCardSearchResult({
    required this.cards,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  bool get hasMore => page * pageSize < totalCount;
}

class PokemonTcgService {
  final http.Client _client;

  PokemonTcgService(this._client);

  Future<PokemonCardSearchResult> searchCards({
    required String query,
    required int page,
    int pageSize = 60,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      'orderBy': '-set.releaseDate,name',
      'select':
          'id,name,number,images,set,rarity,supertype,subtypes,types,hp,rules,flavorText',
    };

    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      final tokens = normalizedQuery
          .split(RegExp(r'\s+'))
          .map(_sanitizeToken)
          .where((token) => token.isNotEmpty)
          .toList(growable: false);

      if (tokens.isNotEmpty) {
        queryParameters['q'] = tokens
            .map((token) => '(name:$token* OR set.name:$token* OR number:$token*)')
            .join(' ');
      }
    }

    final uri = Uri.https('api.pokemontcg.io', '/v2/cards', queryParameters);
    final headers = <String, String>{'Accept': 'application/json'};
    final apiKey = dotenv.env['POKEMON_TCG_API_KEY']?.trim() ?? '';
    if (apiKey.isNotEmpty) {
      headers['X-Api-Key'] = apiKey;
    }

    final response = await _client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Pokemon TCG API retornou ${response.statusCode}.',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (payload['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PokemonCard.fromJson)
        .toList(growable: false);

    return PokemonCardSearchResult(
      cards: data,
      page: page,
      pageSize: pageSize,
      totalCount: (payload['totalCount'] as num?)?.toInt() ?? data.length,
    );
  }

  String _sanitizeToken(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
  }
}
