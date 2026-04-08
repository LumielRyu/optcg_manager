import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:optcg_manager/features/auth/auth_gate.dart';

void main() {
  testWidgets('Auth gate renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthGate(),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });
}
