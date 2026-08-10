import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/library/one_piece_library_screen.dart',
  ).readAsStringSync();

  test('One Piece library exposes every game color including blue', () {
    expect(source, contains("'Azul': 'Blue'"));
    expect(source, contains("'Multicolor': 'Multi'"));
    expect(source, contains('_LibraryColorFilterChip('));
    expect(source, contains('Icons.palette_outlined'));
    expect(
      source,
      contains("selectedLabel == 'Multicolor' && card.isMulticolor"),
    );
  });

  test('search query is not counted as an advanced filter', () {
    final start = source.indexOf('int _activeAdvancedFilterCount()');
    final end = source.indexOf('void _resetAdvancedFilters()', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final activeFilterFunction = source.substring(start, end);
    expect(activeFilterFunction, isNot(contains('_query')));
    expect(activeFilterFunction, isNot(contains('_favoritesOnly')));
  });

  test('filter dialog offers clear and results actions', () {
    expect(source, contains("label: const Text('Limpar')"));
    expect(source, contains("label: const Text('Ver resultados')"));
    expect(source, contains('Nenhum filtro adicional ativo'));
  });

  test(
    'library cards identify the printing edition without opening details',
    () {
      expect(source, contains("'Edição: \${card.setName}'"));
      expect(source, contains("'Edição não informada'"));
      expect(source, contains('maxMetadataItems: 3'));
    },
  );
}
