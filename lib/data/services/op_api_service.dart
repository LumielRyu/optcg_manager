import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../local/hive_boxes.dart';
import '../models/op_card.dart';

final opApiServiceProvider = Provider<OpApiService>((ref) {
  return OpApiService();
});

class OpApiService {
  static const String _mainSetUrl =
      'https://www.optcgapi.com/api/allSetCards/?format=json';
  static const String _starterDeckUrl =
      'https://www.optcgapi.com/api/allSTCards/?format=json';
  static const String _promosUrl =
      'https://www.optcgapi.com/api/allPromos/?format=json';
  static const String _cachedCardsKey = 'all_cards';
  static const String _cachedAtKey = 'all_cards_cached_at';
  static const Duration _cacheMaxAge = Duration(hours: 12);

  List<OpCard>? _cache;
  Map<String, List<OpCard>>? _byCodeMulti;
  List<_IndexedOpCard>? _searchIndex;
  Future<void>? _preloadFuture;
  Future<void>? _backgroundRefreshFuture;

  static const Map<String, String> _textNormalizationReplacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'Ã¡': 'a',
    'Ã ': 'a',
    'Ã¢': 'a',
    'Ã£': 'a',
    'Ã¤': 'a',
    'Ã©': 'e',
    'Ã¨': 'e',
    'Ãª': 'e',
    'Ã«': 'e',
    'Ã­': 'i',
    'Ã¬': 'i',
    'Ã®': 'i',
    'Ã¯': 'i',
    'Ã³': 'o',
    'Ã²': 'o',
    'Ã´': 'o',
    'Ãµ': 'o',
    'Ã¶': 'o',
    'Ãº': 'u',
    'Ã¹': 'u',
    'Ã»': 'u',
    'Ã¼': 'u',
    'Ã§': 'c',
    'Ã±': 'n',
    'ÃƒÂ¡': 'a',
    'ÃƒÂ ': 'a',
    'ÃƒÂ¢': 'a',
    'ÃƒÂ£': 'a',
    'ÃƒÂ¤': 'a',
    'ÃƒÂ©': 'e',
    'ÃƒÂ¨': 'e',
    'ÃƒÂª': 'e',
    'ÃƒÂ«': 'e',
    'ÃƒÂ­': 'i',
    'ÃƒÂ¬': 'i',
    'ÃƒÂ®': 'i',
    'ÃƒÂ¯': 'i',
    'ÃƒÂ³': 'o',
    'ÃƒÂ²': 'o',
    'ÃƒÂ´': 'o',
    'ÃƒÂµ': 'o',
    'ÃƒÂ¶': 'o',
    'ÃƒÂº': 'u',
    'ÃƒÂ¹': 'u',
    'ÃƒÂ»': 'u',
    'ÃƒÂ¼': 'u',
    'ÃƒÂ§': 'c',
    'ÃƒÂ±': 'n',
  };

  Future<void> preload() {
    if (_cache != null && _byCodeMulti != null && _searchIndex != null) {
      return Future.value();
    }

    _preloadFuture ??= _preloadInternal().whenComplete(() {
      _preloadFuture = null;
    });
    return _preloadFuture!;
  }

  Future<void> _preloadInternal() async {
    final cachedCards = _loadCardsFromDisk();
    if (cachedCards.isNotEmpty) {
      _setMemoryCache(cachedCards);

      if (_isDiskCacheStale()) {
        _refreshInBackground();
      }

      return;
    }

    await _refreshFromApi();
  }

  void _refreshInBackground() {
    if (_backgroundRefreshFuture != null) return;

    _backgroundRefreshFuture = _refreshFromApi().whenComplete(() {
      _backgroundRefreshFuture = null;
    });
  }

  Future<void> _refreshFromApi() async {
    final responses = await Future.wait([
      _getJson(_mainSetUrl),
      _getJson(_starterDeckUrl),
      _getJson(_promosUrl),
    ]);

    final allCards = <OpCard>[];

    for (final list in responses) {
      allCards.addAll(list.map(OpCard.fromJson));
    }

    _setMemoryCache(allCards);
    await _saveCardsToDisk(allCards);
  }

  Future<List<OpCard>> findAllByCode(String code) async {
    await preload();

    for (final candidate in _normalizeCodeCandidates(code)) {
      final matches = _byCodeMulti![candidate];
      if (matches != null && matches.isNotEmpty) {
        return List<OpCard>.from(matches);
      }
    }

    return const [];
  }

  Future<OpCard?> findCardByCode(String code) async {
    final list = await findAllByCode(code);
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<List<OpCard>> loadAllCards() async {
    await preload();
    return List<OpCard>.from(_cache!);
  }

  Future<List<OpCard>> searchCardsByName(String query, {int limit = 5}) async {
    await preload();

    final normalizedQuery = _normalizeText(query);
    if (normalizedQuery.isEmpty) return const [];

    final queryWords = normalizedQuery
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    final scored =
        _searchIndex!
            .map((entry) {
              final normalizedName = entry.normalizedName;
              if (normalizedName.isEmpty) return null;

              var score = 0;
              if (normalizedName == normalizedQuery) {
                score = 1000;
              } else if (normalizedName.startsWith(normalizedQuery)) {
                score = 700;
              } else if (normalizedName.contains(normalizedQuery)) {
                score = 500;
              } else {
                final matchedWords = queryWords
                    .where((word) => normalizedName.contains(word))
                    .length;

                if (matchedWords == 0) return null;
                score = matchedWords * 100;
              }

              score -= (normalizedName.length - normalizedQuery.length).abs();
              if (entry.hasImage) {
                score += 10;
              }

              return (card: entry.card, score: score);
            })
            .whereType<({OpCard card, int score})>()
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(limit).map((entry) => entry.card).toList();
  }

  Future<OpCard?> findBestCardForManualEntry({
    required String name,
    String? color,
  }) async {
    await preload();

    final normalizedName = _normalizeText(name);
    if (normalizedName.isEmpty) return null;

    final normalizedColor = _normalizeText(color ?? '');
    final results = await searchCardsByName(name, limit: 20);
    if (results.isEmpty) return null;

    final scored = results.map((card) {
      var score = 0;
      final cardName = _normalizeText(card.name);
      final cardColor = _normalizeText(card.color);

      if (cardName == normalizedName) {
        score += 5000;
      } else if (cardName.startsWith(normalizedName)) {
        score += 3000;
      } else if (cardName.contains(normalizedName) ||
          normalizedName.contains(cardName)) {
        score += 1800;
      }

      final inputWords = normalizedName
          .split(' ')
          .where((word) => word.length >= 3)
          .toList(growable: false);
      final matchedWords = inputWords
          .where((word) => cardName.contains(word))
          .length;
      score += matchedWords * 250;

      if (normalizedColor.isNotEmpty && cardColor.contains(normalizedColor)) {
        score += 800;
      }

      if (card.image.trim().isNotEmpty) {
        score += 100;
      }

      return (card: card, score: score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first;
    if (best.score < 1200) {
      return null;
    }

    return best.card;
  }

  Future<OpCard?> findBestCardFromOcrText({
    required String rawText,
    List<String> candidateNames = const [],
    List<String> extractedLines = const [],
  }) async {
    await preload();

    final normalizedRaw = _normalizeText(rawText);
    if (normalizedRaw.isEmpty) return null;

    final normalizedCandidates = candidateNames
        .map(_normalizeText)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final normalizedExtracted = extractedLines
        .map((line) => _normalizeCode(line.replaceFirst(RegExp(r'^\d+x'), '')))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final scored = <({OpCard card, int score})>[];

    for (final entry in _searchIndex!) {
      final card = entry.card;
      final normalizedName = entry.normalizedName;
      if (normalizedName.isEmpty) continue;

      final nameWords = entry.nameWords;
      if (nameWords.isEmpty) continue;

      var score = 0;

      if (normalizedRaw.contains(normalizedName)) {
        score += 5000;
      }

      for (final candidate in normalizedCandidates) {
        if (candidate == normalizedName) {
          score += 4000;
        } else if (candidate.contains(normalizedName) ||
            normalizedName.contains(candidate)) {
          score += 2500;
        }
      }

      final matchedWords = nameWords
          .where((word) => normalizedRaw.contains(word))
          .length;

      if (matchedWords == nameWords.length) {
        score += 1800;
      } else {
        score += matchedWords * 250;
      }

      final matchedTextKeywords = entry.textKeywords
          .where((word) => normalizedRaw.contains(word))
          .length;
      final textKeywordScore = matchedTextKeywords * 120;
      score += textKeywordScore > 2200 ? 2200 : textKeywordScore;

      if (entry.normalizedType.isNotEmpty &&
          normalizedRaw.contains(entry.normalizedType)) {
        score += 180;
      }

      if (entry.normalizedSetName.isNotEmpty &&
          normalizedRaw.contains(entry.normalizedSetName)) {
        score += 120;
      }

      final code = _normalizeCode(card.code);
      for (final extractedCode in normalizedExtracted) {
        if (extractedCode == code) {
          score += 4000;
        } else if (extractedCode.isNotEmpty &&
            (code.contains(extractedCode) || extractedCode.contains(code))) {
          score += 1000;
        } else if (_shareCodePrefix(extractedCode, code)) {
          score += 600;
        }
      }

      if (entry.hasImage) {
        score += 20;
      }

      if (score > 0) {
        scored.add((card: card, score: score));
      }
    }

    if (scored.isEmpty) return null;

    scored.sort((a, b) => b.score.compareTo(a.score));
    final best = scored.first;
    final secondScore = scored.length > 1 ? scored[1].score : 0;

    if (best.score < 2200) {
      return null;
    }

    if (best.score - secondScore < 250) {
      return null;
    }

    return best.card;
  }

  Future<List<Map<String, dynamic>>> _getJson(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao carregar cartas da API: ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Formato inesperado retornado pela API.');
    }

    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  String normalizeCode(String input) => _normalizeCode(input);

  String normalizeSearchText(String input) => _normalizeText(input);

  void _setMemoryCache(List<OpCard> cards) {
    final sortedCards = List<OpCard>.from(cards)
      ..sort((a, b) => a.code.compareTo(b.code));

    final grouped = <String, List<OpCard>>{};

    for (final card in sortedCards) {
      final key = _normalizeCode(card.code);
      if (key.isEmpty) continue;

      grouped.putIfAbsent(key, () => <OpCard>[]).add(card);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final aHasImage = a.image.trim().isNotEmpty;
        final bHasImage = b.image.trim().isNotEmpty;

        if (aHasImage != bHasImage) {
          return bHasImage ? 1 : -1;
        }

        final aRarity = a.rarity.trim().toLowerCase();
        final bRarity = b.rarity.trim().toLowerCase();
        return aRarity.compareTo(bRarity);
      });
    }

    _cache = sortedCards;
    _byCodeMulti = grouped;
    _searchIndex = sortedCards
        .map(_IndexedOpCard.fromCard)
        .toList(growable: false);
  }

  List<OpCard> _loadCardsFromDisk() {
    final box = Hive.box(HiveBoxes.apiCache);
    final rawCards = box.get(_cachedCardsKey);
    if (rawCards is! List || rawCards.isEmpty) {
      return const <OpCard>[];
    }

    return rawCards
        .whereType<Map>()
        .map((entry) => OpCard.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  bool _isDiskCacheStale() {
    final box = Hive.box(HiveBoxes.apiCache);
    final rawTimestamp = box.get(_cachedAtKey);
    if (rawTimestamp is! String || rawTimestamp.trim().isEmpty) {
      return true;
    }

    final timestamp = DateTime.tryParse(rawTimestamp);
    if (timestamp == null) {
      return true;
    }

    return DateTime.now().difference(timestamp) > _cacheMaxAge;
  }

  Future<void> _saveCardsToDisk(List<OpCard> cards) async {
    final box = Hive.box(HiveBoxes.apiCache);
    await box.put(
      _cachedCardsKey,
      cards.map((card) => card.toJson()).toList(growable: false),
    );
    await box.put(_cachedAtKey, DateTime.now().toIso8601String());
  }

  String _normalizeCode(String input) {
    final candidates = _normalizeCodeCandidates(input);
    if (candidates.isEmpty) return '';
    return candidates.first;
  }

  List<String> _normalizeCodeCandidates(String input) {
    var code = input.trim().toUpperCase();

    code = code.replaceAll('_', '-');
    code = code.replaceAll('???', '-');
    code = code.replaceAll('???', '-');
    code = code.replaceAll(RegExp(r'\s+'), '');
    code = code.replaceAll(RegExp(r'[^A-Z0-9\-]'), '');

    if (code.isEmpty) return const [];

    final results = <String>{};

    void addCandidate(String value) {
      final normalized = _normalizeCodeStrict(value);
      if (normalized.isNotEmpty) {
        results.add(normalized);
      }
    }

    final compact = code.replaceAll('-', '');
    addCandidate(code);
    addCandidate(compact);
    addCandidate(_fixCommonOcrCodeMistakes(compact));

    if (compact.length > 2) {
      final withoutLeading = compact.substring(1);
      addCandidate(withoutLeading);
      addCandidate(_fixCommonOcrCodeMistakes(withoutLeading));
    }

    return results.toList(growable: false);
  }

  String _normalizeCodeStrict(String input) {
    var code = input.trim().toUpperCase();
    code = code.replaceAll(RegExp(r'[^A-Z0-9\-]'), '');

    if (code.isEmpty) return '';

    if (RegExp(r'^[A-Z]{1,4}\d{1,2}-\d{3}[A-Z]{0,2}$').hasMatch(code)) {
      return code;
    }

    final compact = code.replaceAll('-', '');

    final setStyle = RegExp(r'^([A-Z]{1,4}\d{1,2})(\d{3})([A-Z]{0,2})$');
    final setMatch = setStyle.firstMatch(compact);
    if (setMatch != null) {
      final suffix = setMatch.group(3) ?? '';
      return '${setMatch.group(1)}-${setMatch.group(2)}$suffix';
    }

    final promoStyle = RegExp(r'^([A-Z]{1,3})(\d{3})$');
    final promoMatch = promoStyle.firstMatch(compact);
    if (promoMatch != null) {
      return '${promoMatch.group(1)}-${promoMatch.group(2)}';
    }

    return '';
  }

  String _fixCommonOcrCodeMistakes(String compact) {
    final match = RegExp(
      r'^([A-Z]{1,5})([A-Z0-9]{1,2})([A-Z0-9]{3})([A-Z]{0,2})$',
    ).firstMatch(compact);

    if (match == null) {
      return compact;
    }

    const toDigit = {
      'O': '0',
      'Q': '0',
      'D': '0',
      'I': '1',
      'L': '1',
      'Z': '2',
      'S': '5',
      'B': '8',
      'G': '6',
    };

    final prefix = match.group(1) ?? '';
    final setDigits = (match.group(2) ?? '')
        .split('')
        .map((char) => toDigit[char] ?? char)
        .join();
    final cardDigits = (match.group(3) ?? '')
        .split('')
        .map((char) => toDigit[char] ?? char)
        .join();
    final suffix = match.group(4) ?? '';

    return '$prefix$setDigits$cardDigits$suffix';
  }

  String _normalizeText(String input) {
    var text = input.trim().toLowerCase();
    if (text.isEmpty) return '';

    _textNormalizationReplacements.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  bool _shareCodePrefix(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final compactA = a.replaceAll('-', '');
    final compactB = b.replaceAll('-', '');
    if (compactA.length < 3 || compactB.length < 3) return false;

    final prefixLength = compactA.length < compactB.length
        ? compactA.length
        : compactB.length;

    final shared = StringBuffer();
    for (var i = 0; i < prefixLength; i++) {
      if (compactA[i] != compactB[i]) break;
      shared.write(compactA[i]);
    }

    return shared.length >= 3;
  }
}

class _IndexedOpCard {
  final OpCard card;
  final String normalizedName;
  final String normalizedType;
  final String normalizedSetName;
  final Set<String> textKeywords;
  final List<String> nameWords;
  final bool hasImage;

  const _IndexedOpCard({
    required this.card,
    required this.normalizedName,
    required this.normalizedType,
    required this.normalizedSetName,
    required this.textKeywords,
    required this.nameWords,
    required this.hasImage,
  });

  factory _IndexedOpCard.fromCard(OpCard card) {
    final normalizedName = _normalize(card.name);
    final normalizedType = _normalize(card.type);
    final normalizedSetName = _normalize(card.setName);
    final normalizedText = _normalize(card.text);

    return _IndexedOpCard(
      card: card,
      normalizedName: normalizedName,
      normalizedType: normalizedType,
      normalizedSetName: normalizedSetName,
      textKeywords: normalizedText
          .split(' ')
          .where((word) => word.length >= 4)
          .toSet(),
      nameWords: normalizedName
          .split(' ')
          .where((word) => word.length >= 3)
          .toList(growable: false),
      hasImage: card.image.trim().isNotEmpty,
    );
  }

  static String _normalize(String input) {
    var text = input.trim().toLowerCase();
    if (text.isEmpty) return '';

    OpApiService._textNormalizationReplacements.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
