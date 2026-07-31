import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/services/liga_one_piece_service.dart';

void main() {
  final normal = <String, dynamic>{
    'lookup_code': 'OP15-001',
    'card_code': 'OP15-001',
    'edition_code': 'OP-15',
    'image_url': 'https://images.example/normal-op15-001.png',
    'resolved_at': '2026-07-24T12:00:00Z',
  };
  final releaseEvent = <String, dynamic>{
    'lookup_code': 'OP15-001@OP-15-RE',
    'card_code': 'OP15-001',
    'edition_code': 'OP-15-RE',
    'image_url': 'https://images.example/release-op15-001.png',
    'resolved_at': '2026-07-24T12:00:00Z',
  };

  test('seleciona a edição auxiliar pela imagem exata', () {
    final selected = LigaOnePieceService.selectBestRemoteRow(
      [normal, releaseEvent],
      cardName: 'Monkey.D.Luffy',
      lookupCode: 'OP15-001',
      imageUrl: 'https://images.example/release-op15-001.png',
    );

    expect(selected?['edition_code'], 'OP-15-RE');
  });

  test('seleciona Release Event quando o nome identifica a variante', () {
    final selected = LigaOnePieceService.selectBestRemoteRow(
      [normal, releaseEvent],
      cardName: 'Monkey.D.Luffy Release Event',
      lookupCode: 'OP15-001',
      imageUrl: '',
    );

    expect(selected?['edition_code'], 'OP-15-RE');
  });

  test('mantém a edição principal como padrão sem indicação de variante', () {
    final selected = LigaOnePieceService.selectBestRemoteRow(
      [normal, releaseEvent],
      cardName: 'Monkey.D.Luffy',
      lookupCode: 'OP15-001',
      imageUrl: '',
    );

    expect(selected?['edition_code'], 'OP-15');
  });

  test('mapeia carta Release Event promocional para o codigo da Liga', () {
    expect(
      inferLigaLookupCode(
        cardName: 'Girl (OP14 Release Event)',
        cardCode: 'P-096',
      ),
      'P-096-RE',
    );
  });

  test('distingue a vencedora e preserva codigos promocionais exatos', () {
    expect(
      inferLigaLookupCode(
        cardName: 'Girl (OP14 Release Event Winner)',
        cardCode: 'P-096',
      ),
      'P-096-RW',
    );
    expect(
      inferLigaLookupCode(
        cardName: 'Girl (OP14 Release Event Winner)',
        cardCode: 'P-096-RW',
      ),
      'P-096-RW',
    );
  });

  test('consulta todos os sufixos históricos de arte alternativa', () {
    expect(
      inferLigaLookupCodes(
        cardName: 'Edward.Newgate (001) (Alternate Art)',
        cardCode: 'OP02-001',
      ),
      containsAll(<String>[
        'OP02-001-AA',
        'OP02-001-PA',
        'OP02-001-PAR',
        'OP02-001-E',
        'OP02-001-A',
        'OP02-001-P',
        'OP02-001',
      ]),
    );
  });

  test('seleciona variante histórica -E para arte alternativa', () {
    final base = <String, dynamic>{
      'lookup_code': 'OP02-001@ST15',
      'card_code': 'OP02-001',
      'card_name': 'Edward.Newgate (001)',
      'edition_code': 'ST15',
      'minimum_price': 3.39,
    };
    final alternate = <String, dynamic>{
      'lookup_code': 'OP02-001-E@OP-02',
      'card_code': 'OP02-001-E',
      'card_name': 'Edward.Newgate',
      'edition_code': 'OP-02',
      'minimum_price': 698.75,
    };

    final selected = LigaOnePieceService.selectBestRemoteRow(
      [base, alternate],
      cardName: 'Edward.Newgate (001) (Alternate Art)',
      lookupCode: 'OP02-001-AA',
      imageUrl: '',
    );

    expect(selected?['card_code'], 'OP02-001-E');
  });

  test('seleciona edição original para a arte comum', () {
    final reprint = <String, dynamic>{
      'lookup_code': 'OP02-001@ST15',
      'card_code': 'OP02-001',
      'card_name': 'Edward.Newgate (001)',
      'edition_code': 'ST15',
      'minimum_price': 3.39,
    };
    final original = <String, dynamic>{
      'lookup_code': 'OP02-001@OP-02',
      'card_code': 'OP02-001',
      'card_name': 'Edward.Newgate (001)',
      'edition_code': 'OP-02',
      'minimum_price': 9.9,
    };

    final selected = LigaOnePieceService.selectBestRemoteRow(
      [reprint, original],
      cardName: 'Edward.Newgate (001)',
      lookupCode: 'OP02-001',
      imageUrl: '',
    );

    expect(selected?['edition_code'], 'OP-02');
  });
}
