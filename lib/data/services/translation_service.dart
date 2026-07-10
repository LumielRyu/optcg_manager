import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';

class TranslationService {
  TranslationService({http.Client? client, GoogleTranslator? translator})
    : _client = client ?? http.Client(),
      _translator = translator ?? GoogleTranslator();

  final http.Client _client;
  final GoogleTranslator _translator;

  Future<String> translateToPortuguese(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return '';

    try {
      return await _translateViaAppApi(cleanText);
    } catch (_) {
      final result = await _translator.translate(
        cleanText,
        from: 'en',
        to: 'pt',
      );
      return result.text.trim();
    }
  }

  Future<String> _translateViaAppApi(String text) async {
    final endpoint = Uri.base.resolve('/api/translate-card-text');
    final response = await _client.post(
      endpoint,
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TranslationException(
        'Translation API returned ${response.statusCode}',
      );
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) {
      throw const TranslationException('Unexpected translation response');
    }

    final translatedText = (payload['translatedText'] ?? '').toString().trim();
    if (translatedText.isEmpty) {
      throw const TranslationException('Empty translation response');
    }

    return translatedText;
  }
}

class TranslationException implements Exception {
  final String message;

  const TranslationException(this.message);

  @override
  String toString() => message;
}
