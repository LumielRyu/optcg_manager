import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../data/repositories/auth_repository.dart';

class TcgSelectorScreen extends ConsumerWidget {
  const TcgSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TCG Manager'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontalPadding = width < 600 ? 16.0 : 24.0;
          final cardsPerRow = width >= 1280
              ? 3
              : width >= 760
              ? 2
              : 1;
          final contentWidth = width < 1320 ? width : 1320.0;
          final availableWidth = contentWidth - (horizontalPadding * 2);
          final totalSpacing = 18.0 * (cardsPerRow - 1);
          final cardWidth = (availableWidth - totalSpacing) / cardsPerRow;

          return SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.tertiaryContainer,
                            colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escolha seu TCG',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Entre no universo que quiser explorar agora. One Piece continua com colecao, vendas e marketplace; os demais TCGs entram com hubs e bibliotecas conectadas a APIs publicas.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _TcgChoiceCard(
                            title: 'One Piece',
                            subtitle:
                                'Colecao, vendas, marketplace e biblioteca oficial do One Piece Card Game.',
                            accent: const Color(0xFF0D5C63),
                            chipLabel: 'Fluxo completo',
                            icon: Icons.waves_outlined,
                            onTap: () => context.go('/home/one-piece'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _TcgChoiceCard(
                            title: 'Pokemon',
                            subtitle:
                                'Biblioteca inicial com busca em tempo real usando a Pokemon TCG API.',
                            accent: const Color(0xFFD62828),
                            chipLabel: 'Nova biblioteca',
                            icon: Icons.catching_pokemon,
                            onTap: () => context.go('/pokemon'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _TcgChoiceCard(
                            title: 'Yu-Gi-Oh',
                            subtitle:
                                'Biblioteca inicial conectada ao YGOPRODeck para pesquisar cartas e detalhes.',
                            accent: const Color(0xFF4A4E9B),
                            chipLabel: 'Nova biblioteca',
                            icon: Icons.auto_awesome_outlined,
                            onTap: () => context.go('/yugioh'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _TcgChoiceCard(
                            title: 'Digimon',
                            subtitle:
                                'Biblioteca inicial com busca em tempo real usando a Heroicc Digimon API.',
                            accent: const Color(0xFF0F766E),
                            chipLabel: 'Nova biblioteca',
                            icon: Icons.memory_outlined,
                            onTap: () => context.go('/digimon'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _TcgChoiceCard(
                            title: 'Magic',
                            subtitle:
                                'Biblioteca inicial conectada ao Scryfall para pesquisar cartas e metadados.',
                            accent: const Color(0xFFB45309),
                            chipLabel: 'Nova biblioteca',
                            icon: Icons.auto_fix_high_outlined,
                            onTap: () => context.go('/magic'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _TcgChoiceCard(
                            title: 'Riftbound',
                            subtitle:
                                'Biblioteca inicial com listagem e busca aproximada de cartas via Riftcodex.',
                            accent: const Color(0xFF2563EB),
                            chipLabel: 'Nova biblioteca',
                            icon: Icons.bolt_outlined,
                            onTap: () => context.go('/riftbound'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TcgChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String chipLabel;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _TcgChoiceCard({
    required this.title,
    required this.subtitle,
    required this.chipLabel,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
