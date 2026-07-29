import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final piltoverArchiveImportServiceProvider =
    Provider<PiltoverArchiveImportService>((ref) {
      final client = http.Client();
      ref.onDispose(client.close);
      return PiltoverArchiveImportService(client);
    });

class PiltoverArchiveDeckImport {
  final String deckId;
  final String deckName;
  final String text;
  final int totalCards;

  const PiltoverArchiveDeckImport({
    required this.deckId,
    required this.deckName,
    required this.text,
    required this.totalCards,
  });

  factory PiltoverArchiveDeckImport.fromJson(Map<String, dynamic> json) {
    return PiltoverArchiveDeckImport(
      deckId: (json['deckId'] ?? '').toString(),
      deckName: (json['deckName'] ?? '').toString().trim(),
      text: (json['text'] ?? '').toString().trim(),
      totalCards: int.tryParse((json['totalCards'] ?? 0).toString()) ?? 0,
    );
  }
}

class PiltoverArchiveImportService {
  final http.Client _client;

  const PiltoverArchiveImportService(this._client);

  Future<PiltoverArchiveDeckImport> importDeck(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const PiltoverArchiveImportException(
        'Cole o link do deck do Piltover Archive.',
      );
    }
    final response = await _client.post(
      Uri.base.resolve('/api/import-riftbound-deck'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'url': normalizedUrl}),
    );
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) payload = decoded;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = switch (response.statusCode) {
        400 => 'O link informado não é um deck válido do Piltover Archive.',
        429 =>
          'Muitas consultas seguidas. Aguarde um minuto e tente novamente.',
        _ =>
          'O Piltover Archive não respondeu. Você ainda pode colar a lista manualmente.',
      };
      throw PiltoverArchiveImportException(message);
    }
    final imported = PiltoverArchiveDeckImport.fromJson(payload ?? const {});
    if (imported.text.isEmpty || imported.totalCards <= 0) {
      throw const PiltoverArchiveImportException(
        'O deck não possui cartas que possam ser importadas.',
      );
    }
    return imported;
  }
}

class PiltoverArchiveImportException implements Exception {
  final String message;

  const PiltoverArchiveImportException(this.message);

  @override
  String toString() => message;
}
