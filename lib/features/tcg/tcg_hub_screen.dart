import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/home_navigation_button.dart';

class TcgHubScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sourceLabel;
  final Color accent;
  final IconData heroIcon;
  final String libraryRoute;
  final List<String> highlights;

  const TcgHubScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.accent,
    required this.heroIcon,
    required this.libraryRoute,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(),
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        theme.colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Icon(heroIcon, color: accent, size: 36),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _HubTag(
                                  label: sourceLabel,
                                  color: accent,
                                ),
                                for (final item in highlights)
                                  _HubTag(label: item, color: accent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                          child: const _HubFeatureCard(
                            title: 'Colecao',
                            description:
                                'Fluxos de colecao e gerenciamento ficam na proxima fase dessa expansao.',
                            icon: Icons.collections_bookmark_outlined,
                            accent: Color(0xFF7A7A7A),
                            buttonLabel: 'Em breve',
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
        ),
      ),
    );
  }
}

class _HubTag extends StatelessWidget {
  final String label;
  final Color color;

  const _HubTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(description),
            const SizedBox(height: 18),
            if (onTap == null)
              OutlinedButton(
                onPressed: null,
                child: Text(buttonLabel),
              )
            else
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward),
                label: Text(buttonLabel),
              ),
          ],
        ),
      ),
    );
  }
}
