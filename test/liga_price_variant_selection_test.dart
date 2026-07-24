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
}
