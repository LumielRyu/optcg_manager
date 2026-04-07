import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../core/widgets/primary_bottom_navigation.dart';
import '../../data/repositories/auth_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OPTCG Manager'),
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
          final horizontalPadding = width < 600 ? 16.0 : 20.0;
          final availableWidth = width - (horizontalPadding * 2);
          final cardWidth = width >= 1280
              ? (availableWidth - 48) / 4
              : width >= 900
              ? (availableWidth - 16) / 2
              : (availableWidth - 16) / 2;

          return SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Bem-vindo ao OPTCG Manager',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Gerencie sua coleção, organize decks e publique sua vitrine de vendas em um só lugar.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: const _HomeFeatureCard(
                            icon: Icons.auto_stories_outlined,
                            title: 'Biblioteca One Piece',
                            subtitle:
                                'Consulte todas as cartas do jogo com imagem, código e filtros por cor, tipo e edição.',
                            buttonLabel: 'Abrir biblioteca',
                            route: '/library',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: const _HomeFeatureCard(
                            icon: Icons.collections_bookmark_outlined,
                            title: 'Abrir coleção',
                            subtitle:
                                'Acesse cartas obtidas e decks montados, além das ferramentas de importação.',
                            buttonLabel: 'Abrir coleção',
                            route: '/collection',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: const _HomeFeatureCard(
                            icon: Icons.storefront_outlined,
                            title: 'Cartas à venda',
                            subtitle:
                                'Gerencie sua área de vendas e copie o link da sua vitrine pública.',
                            buttonLabel: 'Abrir vendas',
                            route: '/sales',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: const _HomeFeatureCard(
                            icon: Icons.public_outlined,
                            title: 'Marketplace Global',
                            subtitle:
                                'Veja todas as cartas públicas à venda dentro da plataforma e fale direto no WhatsApp com o vendedor.',
                            buttonLabel: 'Abrir marketplace',
                            route: '/marketplace',
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
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/home',
      ),
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String route;

  const _HomeFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.45),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: theme.colorScheme.primary.withOpacity(0.05),
        highlightColor: Colors.transparent,
        hoverColor: theme.colorScheme.primary.withOpacity(0.04),
        onTap: () => context.go(route),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 22),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 210 : 240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: compact ? 24 : 32),
                SizedBox(height: compact ? 12 : 18),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 18 : null,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  subtitle,
                  maxLines: compact ? 5 : 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: compact ? 13 : null,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => context.go(route),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
