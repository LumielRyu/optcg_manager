import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/core/widgets/accessible_action_surface.dart';
import 'package:optcg_manager/core/widgets/app_page_shell.dart';

void main() {
  testWidgets('action surface exposes one named button and supports keyboard', (
    tester,
  ) async {
    var activations = 0;
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessibleActionSurface(
            label: 'Abrir Pokemon',
            hint: 'Abre o hub do jogo',
            onTap: () => activations++,
            child: const SizedBox(width: 220, height: 100),
          ),
        ),
      ),
    );

    final action = find.semantics.byLabel('Abrir Pokemon');
    expect(action, findsOne);
    final node = action.evaluate().single;
    final flags = node.getSemanticsData().flagsCollection;
    expect(node.hint, 'Abre o hub do jogo');
    expect(flags.isButton, isTrue);
    expect(flags.isEnabled, Tristate.isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, 1);
    semanticsHandle.dispose();
  });

  testWidgets('page shell removes entrance animation when motion is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            disableAnimations: true,
          ),
          child: const Scaffold(body: AppPageShell(child: Text('Conteudo'))),
        ),
      ),
    );

    final animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(animation.duration, Duration.zero);
  });

  testWidgets('hero remains usable on a narrow screen with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 760),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: AppHeroPanel(
                eyebrow: 'OPTCG BH',
                title: 'Escolha seu card game',
                subtitle: 'Conteudo adaptado para telas menores.',
                icon: Icons.style_outlined,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Escolha seu card game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
