import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/collection_folder.dart';
import 'package:optcg_manager/features/collection/move_to_folder_dialog.dart';

void main() {
  final folders = [
    CollectionFolder(
      id: 'origin-folder',
      userId: 'user',
      gameSlug: 'one-piece',
      name: 'Origem',
      createdAt: DateTime.utc(2026),
    ),
    CollectionFolder(
      id: 'destination-folder',
      userId: 'user',
      gameSlug: 'one-piece',
      name: 'Destino',
      createdAt: DateTime.utc(2026),
    ),
  ];

  testWidgets('allows choosing how many available cards move to a folder', (
    tester,
  ) async {
    MoveToFolderResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<MoveToFolderResult>(
                  context: context,
                  builder: (_) => MoveToFolderDialog(
                    folders: folders,
                    currentFolderId: 'origin-folder',
                    availableQuantity: 5,
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('5 cartas disponíveis'), findsOneWidget);
    expect(find.text('5 de 5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('move-folder-decrease')));
    await tester.tap(find.byKey(const Key('move-folder-decrease')));
    await tester.pump();
    expect(find.text('3 de 5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('move-folder-destination')));
    await tester.pumpAndSettle();
    expect(find.text('Origem (atual)'), findsOneWidget);
    await tester.tap(find.text('Destino').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-folder-confirm')));
    await tester.pumpAndSettle();

    expect(result?.folderId, 'destination-folder');
    expect(result?.quantity, 3);
  });

  testWidgets('supports moving the selected quantity out of folders', (
    tester,
  ) async {
    MoveToFolderResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<MoveToFolderResult>(
                  context: context,
                  builder: (_) => MoveToFolderDialog(
                    folders: folders,
                    currentFolderId: 'origin-folder',
                    availableQuantity: 2,
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-folder-decrease')));
    await tester.tap(find.byKey(const Key('move-folder-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem pasta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-folder-confirm')));
    await tester.pumpAndSettle();

    expect(result?.folderId, isNull);
    expect(result?.quantity, 1);
  });
}
