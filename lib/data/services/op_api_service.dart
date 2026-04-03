import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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

  List<OpCard>? _cache;
  Map<String, OpCard>? _byCode;

  Future<void> preload() async {
    if (_cache != null && _byCode != null) return;

    final responses = await Future.wait([
      _getJson(_mainSetUrl),
      _getJson(_starterDeckUrl),
      _getJson(_promosUrl),
    ]);

    final allCards = <OpCard>[];

    for (final list in responses) {
      allCards.addAll(list.map(OpCard.fromJson));
    }

    final deduped = <String, OpCard>{};

    for (final card in allCards) {
      final key = _normalizeCode(card.code);
      if (key.isEmpty) continue;

      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = card;
        continue;
      }

      final existingHasImage = existing.image.trim().isNotEmpty;
      final currentHasImage = card.image.trim().isNotEmpty;

      if (!existingHasImage && currentHasImage) {
        deduped[key] = card;
      }
    }

    _cache = deduped.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    _byCode = {
      for (final card in _cache!) _normalizeCode(card.code): card,
    };
  }

  Future<OpCard?> findCardByCode(String code) async {
    await preload();
    return _byCode![_normalizeCode(code)];
  }

  Future<List<OpCard>> loadAllCards() async {
    await preload();
    return _cache!;
  }

  Future<List<Map<String, dynamic>>> _getJson(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: const {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao carregar cartas da API: ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Formato inesperado retornado pela API.');
    }

    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _normalizeCode(String input) {
    var code = input.trim().toUpperCase();

    code = code.replaceAll('_', '-');
    code = code.replaceAll('—', '-');
    code = code.replaceAll('–', '-');
    code = code.replaceAll(RegExp(r'\s+'), '');
    code = code.replaceAll(RegExp(r'[^A-Z0-9\-]'), '');

    if (code.isEmpty) return '';

    if (RegExp(r'^[A-Z0-9]{1,6}-[A-Z0-9]{2,}$').hasMatch(code)) {
      return code;
    }

    final compact = code.replaceAll('-', '');

    final setStyle = RegExp(r'^([A-Z]{1,4}\d{1,2})(\d{3}[A-Z0-9]*)$');
    final setMatch = setStyle.firstMatch(compact);
    if (setMatch != null) {
      return '${setMatch.group(1)}-${setMatch.group(2)}';
    }

    final promoStyle = RegExp(r'^([A-Z]{1,3})(\d{3})$');
    final promoMatch = promoStyle.firstMatch(compact);
    if (promoMatch != null) {
      return '${promoMatch.group(1)}-${promoMatch.group(2)}';
    }

    return code;
  }
}