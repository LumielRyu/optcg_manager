import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public branding and products entry live on the TCG selector', () {
    final selector = File(
      'lib/features/tcg/tcg_selector_screen.dart',
    ).readAsStringSync();
    final onePieceHome = File(
      'lib/features/home/home_screen.dart',
    ).readAsStringSync();
    final products = File(
      'lib/features/products/products_screen.dart',
    ).readAsStringSync();

    expect(selector, contains("title: const Text('TCG BH')"));
    expect(selector, contains('PRODUTOS PERSONALIZADOS'));
    expect(selector, contains("context.go('/products')"));
    expect(onePieceHome, isNot(contains("route: '/products'")));
    expect(products, contains("context.go('/home')"));
  });

  test('pricing rollout plan covers every supported card game', () {
    final plan = File('docs/multi-tcg-liga-pricing-plan.md').readAsStringSync();

    for (final game in [
      'One Piece',
      'Pokemon',
      'Digimon',
      'Magic',
      'Riftbound',
      'Yu-Gi-Oh',
    ]) {
      expect(plan, contains(game));
    }
    expect(plan, contains('tcg_card_price_cache'));
    expect(plan, contains('00:00, 08:00 e 16:00'));
  });

  test('every TCG library returns to its own hub', () {
    const expectedParents = <String, String>{
      'pokemon/pokemon_library_screen.dart': '/pokemon',
      'digimon/digimon_library_screen.dart': '/digimon',
      'magic/magic_library_screen.dart': '/magic',
      'riftbound/riftbound_library_screen.dart': '/riftbound',
      'yugioh/yugioh_library_screen.dart': '/yugioh',
      'library/one_piece_library_screen.dart': '/home/one-piece',
    };

    for (final entry in expectedParents.entries) {
      final source = File('lib/features/${entry.key}').readAsStringSync();

      expect(
        source,
        contains("destinationRoute: '${entry.value}'"),
        reason: '${entry.key} deve voltar para ${entry.value}',
      );
    }
  });

  test('shared navigation button has no implicit One Piece fallback', () {
    final source = File(
      'lib/core/widgets/home_navigation_button.dart',
    ).readAsStringSync();

    expect(source, contains('required this.destinationRoute'));
    expect(source, contains('context.go(destinationRoute)'));
    expect(source, isNot(contains("'/home/one-piece'")));
    expect(source, isNot(contains('context.canPop()')));
  });
}
