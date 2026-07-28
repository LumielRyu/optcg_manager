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
  final String? deckRoute;
  final String? salesRoute;
  final String? marketplaceRoute;
  final String? wantedRoute;
  final String? importRoute;
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
    this.deckRoute,
    this.salesRoute,
    this.marketplaceRoute,
    this.wantedRoute,
    this.importRoute,
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
                      child: _HubFeatureCard(
                        title: 'Decks',
                        description: deckRoute == null
                            ? 'O construtor de decks será disponibilizado em uma próxima fase.'
                            : 'Monte decks com sua coleção, organize zonas e valide a estrutura do formato.',
                        icon: Icons.dashboard_customize_outlined,
                        accent: deckRoute == null
                            ? const Color(0xFF7A7A7A)
                            : accent,
                        buttonLabel: deckRoute == null
                            ? 'Em breve'
                            : 'Abrir decks',
                        onTap: deckRoute == null
                            ? null
                            : () => context.go(deckRoute!),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _HubFeatureCard(
                        title: 'Vendas',
                        description: salesRoute == null
                            ? 'Os módulos de vitrine e venda serão disponibilizados em uma próxima etapa.'
                            : 'Importe cartas da coleção, defina condição e preço e publique anúncios por 7 dias.',
                        icon: Icons.storefront_outlined,
                        accent: salesRoute == null
                            ? const Color(0xFF7A7A7A)
                            : accent,
                        buttonLabel: salesRoute == null
                            ? 'Em breve'
                            : 'Gerenciar vendas',
                        onTap: salesRoute == null
                            ? null
                            : () => context.go(salesRoute!),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _HubFeatureCard(
                        title: 'Marketplace',
                        description: marketplaceRoute == null
                            ? 'O marketplace dedicado será disponibilizado em uma próxima etapa.'
                            : 'Veja somente anúncios ativos deste TCG e fale com o vendedor pelo WhatsApp.',
                        icon: Icons.public_outlined,
                        accent: marketplaceRoute == null
                            ? const Color(0xFF7A7A7A)
                            : accent,
                        buttonLabel: marketplaceRoute == null
                            ? 'Em breve'
                            : 'Abrir marketplace',
                        onTap: marketplaceRoute == null
                            ? null
                            : () => context.go(marketplaceRoute!),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _HubFeatureCard(
                        title: 'Procuradas',
                        description: wantedRoute == null
                            ? 'As listas de cartas procuradas serão disponibilizadas em uma próxima etapa.'
                            : 'Publique o que está procurando e receba ofertas da comunidade pelo WhatsApp.',
                        icon: Icons.favorite_outline,
                        accent: wantedRoute == null
                            ? const Color(0xFF7A7A7A)
                            : accent,
                        buttonLabel: wantedRoute == null
                            ? 'Em breve'
                            : 'Ver procuradas',
                        onTap: wantedRoute == null
                            ? null
                            : () => context.go(wantedRoute!),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _HubFeatureCard(
                        title: 'Importar e escanear',
                        description: importRoute == null
                            ? 'A importação assistida será disponibilizada em uma próxima etapa.'
                            : 'Fotografe uma carta ou pesquise por nome/código e confirme a impressão no catálogo.',
                        icon: Icons.document_scanner_outlined,
                        accent: importRoute == null
                            ? const Color(0xFF7A7A7A)
                            : accent,
                        buttonLabel: importRoute == null
                            ? 'Em breve'
                            : 'Abrir scanner',
                        onTap: importRoute == null
                            ? null
                            : () => context.go(importRoute!),
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
