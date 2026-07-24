import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/widgets/async_load_error_view.dart';

void main() {
  testWidgets('shows a safe error message and retries', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncLoadErrorView(
            title: 'Não foi possível carregar',
            message: 'Tente novamente em instantes.',
            referenceId: 'ABC123',
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Código do erro: ABC123'), findsOneWidget);
    expect(find.textContaining('PostgrestException'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    expect(retryCount, 1);
  });
}
