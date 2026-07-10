import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optcg_manager/data/services/translation_service.dart';

void main() {
  test('translates card text through the app API', () async {
    final service = TranslationService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/translate-card-text');
        expect(request.body, contains('Draw 1 card'));
        return http.Response(
          '{"translatedText":"Compre 1 carta."}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final translated = await service.translateToPortuguese('Draw 1 card.');

    expect(translated, 'Compre 1 carta.');
  });

  test('returns empty text without calling the API', () async {
    var called = false;
    final service = TranslationService(
      client: MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    final translated = await service.translateToPortuguese('   ');

    expect(translated, isEmpty);
    expect(called, isFalse);
  });
}
