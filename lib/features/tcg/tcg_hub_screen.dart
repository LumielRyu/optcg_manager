import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_page_shell.dart';
import '../../core/widgets/home_navigation_button.dart';

class TcgHubScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sourceLabel;
  final Color accent;
  final IconData heroIcon;
  final String libraryRoute;
  final String? collectionRoute;
  final List<String> highlights;

  const TcgHubScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.accent,
    required this.heroIcon,
    required this.libraryRoute,
    this.collectionRoute,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(
          destinationRoute: '/home',
          showHomeIcon: true,
        ),
        title: Text(title),
      ),
      body: AppPageShell(
        maxWidth: 1200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeroPanel(
              eyebrow: 'TCG selecionado',
              title: title,
              subtitle: subtitle,
              icon: heroIcon,
              accent: accent,
              visualAsset: 'assets/editorial/scanner_card_stack.png',
              badges: [
                AppBadge(
                  label: sourceLabel,
                  icon: Icons.cloud_outlined,
                  color: accent,
                ),
                for (final item in highlights)
                  AppBadge(
                    label: item,
                    icon: Icons.check_circle_outline,
                    color: accent,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const AppSectionHeading(
              icon: Icons.apps_outlined,
              title: 'Recursos do jogo',
              subtitle:
                  'Abra um modulo disponivel ou acompanhe o que esta chegando.',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final cardWidth = isWide
                    ? (constraints.maxWidth - 24) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _HubFeatureCard(
                        title: 'Biblioteca',
                        description:
                            'Pesquisar cartas, abrir imagens e explorar metadados do TCG selecionado.',
                        icon: Icons.auto_stories_outlined,
                        accent: accent,
                        buttonLabel: 'Abrir biblioteca',
                        onTap: () => context.go(libraryRoute),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _HubFeatureCard(
                        title: 'Colecao',
                        description: collectionRoute == null
                            ? 'Fluxos de colecao e gerenciamento ficam na proxima fase dessa expansao.'
                            : 'Cadastre suas cartas, controle quantidades e acompanhe o valor estimado pela Liga.',
                        icon: Icons.collections_bookmark_outlined,
                        accent: collectionRoute == null
                            ? const Color(0xFF7A7A7A)
                            : accent,
                        buttonLabel: collectionRoute == null
                            ? 'Em breve'
                            : 'Abrir coleção',
                        onTap: collectionRoute == null
                            ? null
                            : () => context.go(collectionRoute!),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HubFeatureCard(
                        title: 'Vendas',
                        description:
                            'Os modulos de vitrine e venda vao entrar depois que a base dessas bibliotecas estiver estabilizada.',
                        icon: Icons.storefront_outlined,
                        accent: Color(0xFF7A7A7A),
                        buttonLabel: 'Em breve',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HubFeatureCard(
                        title: 'Marketplace',
                        description:
                            'Marketplace dedicado para esse TCG tambem fica reservado para a etapa seguinte.',
                        icon: Icons.public_outlined,
                        accent: Color(0xFF7A7A7A),
                        buttonLabel: 'Em breve',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HubFeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String buttonLabel;
  final VoidCallback? onTap;

  const _HubFeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.buttonLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppHoverLift(
      accent: accent,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 238),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.18),
                        Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(description),
                const SizedBox(height: 18),
                if (onTap == null)
                  OutlinedButton(onPressed: null, child: Text(buttonLabel))
                else
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(buttonLabel),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
