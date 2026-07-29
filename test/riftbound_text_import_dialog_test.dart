import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optcg_manager/data/services/riftbound_tcg_service.dart';
import 'package:optcg_manager/features/riftbound/riftbound_text_list_import_dialog.dart';

Map<String, dynamic> _card({
  required String id,
  required String name,
  required String riftboundId,
  required int number,
}) {
  return {
    'id': id,
    'name': name,
    'riftbound_id': riftboundId,
    'collector_number': number,
    'set': {'set_id': 'UNL', 'label': 'Unleashed'},
    'media': {'image_url': ''},
    'classification': {'rarity': 'Common', 'type': 'Gear'},
  };
}

void main() {
  testWidgets('analisa a lista e permite revisar as impressões', (
    tester,
  ) async {
    final service = RiftboundTcgService(
      MockClient((request) async {
        final query = request.url.queryParameters['fuzzy'] ?? '';
        final card = query.contains('Charm')
            ? _card(
                id: 'charm',
                name: 'Charm',
                riftboundId: 'unl-001-219',
                number: 1,
              )
            : _card(
                id: 'yi',
                name: 'Master Yi - Tempered',
                riftboundId: 'unl-113-219',
                number: 113,
              );
        return http.Response(
          jsonEncode({
            'items': [card],
            'page': 1,
            'size': 100,
            'total': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [riftboundTcgServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: Scaffold(
            body: RiftboundTextListImportDialog(
              target: RiftboundTextImportTarget.collection,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Champion:\n1 Master Yi, Tempered\nMainDeck:\n3 Charm',
    );
    await tester.tap(find.text('Analisar lista'));
    await tester.pumpAndSettle();

    expect(find.text('4 cartas'), findsOneWidget);
    expect(find.text('1× Master Yi, Tempered'), findsOneWidget);
    expect(find.text('3× Charm'), findsOneWidget);
    expect(find.text('Adicionar à coleção'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
  });
}
