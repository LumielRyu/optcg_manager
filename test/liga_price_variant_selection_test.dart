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

  test('Winner Pack usa WP e seleciona imagem e preco da variante', () {
    const winnerPackName = 'Kouzuki Hiyori (Winner Pack 2026 Vol. 1)';

    expect(
      inferLigaLookupCode(cardName: winnerPackName, cardCode: 'OP12-028'),
      'OP12-028-WP',
    );
    expect(
      inferLigaLookupCode(cardName: winnerPackName, cardCode: 'OP12-028-WP'),
      'OP12-028-WP',
    );

    final selected = LigaOnePieceService.selectBestRemoteRow(
      [
        {
          'card_code': 'OP12-028',
          'card_name': 'Kouzuki Hiyori',
          'edition_code': 'OP-12',
          'minimum_price': 0.25,
        },
        {
          'card_code': 'OP12-028-WP',
          'card_name': winnerPackName,
          'edition_code': 'PC-01',
          'image_url': 'https://liga.example/op12-028-wp.jpg',
          'minimum_price': 28.49,
        },
      ],
      cardName: winnerPackName,
      lookupCode: 'OP12-028-WP',
      imageUrl: '',
    );

    expect(selected?['card_code'], 'OP12-028-WP');
    expect(selected?['minimum_price'], 28.49);
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

  test('Manga consulta MA e a chave base, mas nunca Alternate Art', () {
    expect(
      inferLigaLookupCodes(
        cardName: 'Tony Tony.Chopper (Alternate Art) (Manga)',
        cardCode: 'EB01-006',
      ),
      <String>['EB01-006-MA', 'EB01-006'],
    );

    final selected = LigaOnePieceService.selectBestRemoteRow(
      [
        {
          'card_code': 'EB01-006-AA',
          'card_name': 'Tony Tony.Chopper (Alternate Art)',
          'edition_code': 'EB01',
          'minimum_price': 499.99,
        },
      ],
      cardName: 'Tony Tony.Chopper (Alternate Art) (Manga)',
      lookupCode: 'EB01-006-MA',
      imageUrl: '',
    );

    expect(selected, isNull);
  });

  test('Manga ambiguo entre duas edicoes exige revisao', () {
    final selected = LigaOnePieceService.selectBestRemoteRow(
      [
        {
          'card_code': 'EB01-006-MA',
          'edition_code': 'EB01',
          'image_url': 'https://liga.example/manga-eb01.png',
          'minimum_price': 13000,
        },
        {
          'card_code': 'EB01-006-MA',
          'edition_code': 'PRB01',
          'image_url': 'https://liga.example/manga-prb01.png',
          'minimum_price': 5700,
        },
      ],
      cardName: 'Tony Tony.Chopper (Alternate Art) (Manga)',
      lookupCode: 'EB01-006-MA',
      imageUrl: '',
    );

    expect(selected, isNull);
  });

  test('imagem exata resolve Manga entre duas edicoes', () {
    final selected = LigaOnePieceService.selectBestRemoteRow(
      [
        {
          'card_code': 'EB01-006-MA',
          'edition_code': 'EB01',
          'image_url': 'https://liga.example/manga-eb01.png',
          'minimum_price': 13000,
        },
        {
          'card_code': 'EB01-006-MA',
          'edition_code': 'PRB01',
          'image_url': 'https://liga.example/manga-prb01.png',
          'minimum_price': 5700,
        },
      ],
      cardName: 'Tony Tony.Chopper (Alternate Art) (Manga)',
      lookupCode: 'EB01-006-MA',
      imageUrl: 'https://catalog.example/manga-eb01.png',
    );

    expect(selected?['edition_code'], 'EB01');
    expect(selected?['minimum_price'], 13000);
  });

  test('Treasure Cup usa somente a variante TC', () {
    expect(
      inferLigaLookupCodes(
        cardName: 'Tony Tony.Chopper (Treasure Cup 2024)',
        cardCode: 'EB01-006',
      ),
      <String>['EB01-006-TC', 'EB01-006'],
    );
  });

  test('SPR e reconhecida como variante especial SP', () {
    expect(
      inferLigaLookupCode(cardName: 'Belo Betty (SPR)', cardCode: 'OP05-002'),
      'OP05-002-SP',
    );
  });

  test('3rd Anniversary usa a variante 3A e nunca a carta comum', () {
    const anniversaryName =
        'Bartholomew Kuma (Japanese Version 3rd Anniversary Set)';

    expect(
      inferLigaLookupCode(cardName: anniversaryName, cardCode: 'OP12-119'),
      'OP12-119-3A',
    );
    expect(
      inferLigaLookupCodes(cardName: anniversaryName, cardCode: 'OP12-119'),
      <String>['OP12-119-3A', 'OP12-119'],
    );

    final selected = LigaOnePieceService.selectBestRemoteRow(
      [
        {
          'card_code': 'OP12-119',
          'card_name': 'Bartholomew Kuma',
          'edition_code': 'OP-12',
          'minimum_price': 97.43,
        },
        {
          'card_code': 'OP12-119-3A',
          'card_name': anniversaryName,
          'edition_code': 'PC-01',
          'minimum_price': 359.90,
        },
      ],
      cardName: anniversaryName,
      lookupCode: 'OP12-119-3A',
      imageUrl: '',
    );

    expect(selected?['card_code'], 'OP12-119-3A');
    expect(selected?['minimum_price'], 359.90);
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

  test(
    'arte alternativa exata vence variante parallel sem imagem idêntica',
    () {
      final selected = LigaOnePieceService.selectBestRemoteRow(
        [
          {
            'card_code': 'OP09-093-AA',
            'card_name': 'Marshall.D.Teach (093) (Alternate Art)',
            'edition_code': 'OP-09',
            'image_url': 'https://liga.example/alternate.jpg',
            'minimum_price': 229.99,
          },
          {
            'card_code': 'OP09-093-P',
            'card_name': 'Marshall.D.Teach (093) (Parallel)',
            'edition_code': 'OP-09',
            'image_url': 'https://liga.example/parallel.jpg',
            'minimum_price': 3999.99,
          },
        ],
        cardName: 'Marshall.D.Teach (093) (Alternate Art)',
        lookupCode: 'OP09-093-AA',
        imageUrl: 'https://api.example/OP09-093_p1.jpg',
      );

      expect(selected?['card_code'], 'OP09-093-AA');
      expect(selected?['minimum_price'], 229.99);
    },
  );

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
