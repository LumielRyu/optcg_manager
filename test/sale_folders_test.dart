import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/sale_folder.dart';
import 'package:optcg_manager/data/models/tcg_marketplace_listing.dart';
import 'package:optcg_manager/features/sales/widgets/sale_folders_section.dart';

void main() {
  test('sale folder parses Supabase payload', () {
    final folder = SaleFolder.fromJson({
      'id': 'folder-1',
      'user_id': 'user-1',
      'game_slug': 'pokemon',
      'name': 'Deck antigo',
      'created_at': '2026-08-09T12:00:00Z',
    });

    expect(folder.id, 'folder-1');
    expect(folder.gameSlug, 'pokemon');
    expect(folder.name, 'Deck antigo');
    expect(folder.createdAt, DateTime.utc(2026, 8, 9, 12));
  });

  test('TCG listing preserves its sales folder', () {
    final listing = TcgMarketplaceListing.fromRow({
      'id': 'listing-1',
      'user_id': 'user-1',
      'game_slug': 'riftbound',
      'catalog_card_id': 'card-1',
      'variant_id': 'variant-1',
      'card_code': 'RB-001',
      'name': 'Carta',
      'quantity': 2,
      'sale_folder_id': 'folder-2',
    });

    expect(listing.saleFolderId, 'folder-2');
  });

  testWidgets('sales folders expose counts, value and selection', (
    tester,
  ) async {
    String? selected;
    var created = false;
    var openedShowcase = false;
    final folder = SaleFolder(
      id: 'folder-1',
      userId: 'user-1',
      gameSlug: 'one-piece',
      name: 'Promocionais',
      createdAt: DateTime.utc(2026, 8, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaleFoldersSection(
            folders: [folder],
            selectedFolderId: saleAllFolders,
            loading: false,
            allMetrics: const SaleFolderMetrics(
              uniqueListings: 3,
              totalCards: 7,
              totalValueInCents: 12345,
            ),
            unfiledMetrics: SaleFolderMetrics.empty,
            folderMetrics: const {
              'folder-1': SaleFolderMetrics(
                uniqueListings: 1,
                totalCards: 2,
                totalValueInCents: 8000,
              ),
            },
            onSelect: (value) => selected = value,
            onCreate: () => created = true,
            onShowcase: () => openedShowcase = true,
            onRename: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Pastas de vendas'), findsOneWidget);
    expect(find.text('3 anuncios • 7 cartas'), findsOneWidget);
    expect(find.text(r'Valor anunciado: R$ 123,45'), findsOneWidget);

    await tester.tap(find.text('Promocionais'));
    expect(selected, 'folder-1');
    await tester.tap(find.text('Nova pasta'));
    expect(created, isTrue);
    await tester.tap(find.text('Modo para print'));
    expect(openedShowcase, isTrue);
  });
}
