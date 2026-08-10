import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visitante nao consulta tabela autenticada de variantes', () {
    final source = File(
      'lib/data/services/liga_one_piece_service.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf(
      'Future<Map<String, String>> _loadConfirmedMappings(',
    );
    final queryStart = source.indexOf('.from(_variantMappingTable)', methodStart);
    final guardStart = source.indexOf(
      'if (_supabase.auth.currentUser == null)',
      methodStart,
    );

    expect(methodStart, greaterThanOrEqualTo(0));
    expect(queryStart, greaterThan(methodStart));
    expect(guardStart, greaterThan(methodStart));
    expect(guardStart, lessThan(queryStart));
    expect(
      source.substring(guardStart, queryStart),
      contains('return const <String, String>{};'),
    );
  });
}
