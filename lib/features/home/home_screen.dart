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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
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
                Expanded(
                  child: GridView.count(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 1080 ? 3 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio:
                        MediaQuery.of(context).size.width > 1080 ? 1.38 : 1.2,
                    children: [
                      _HomeFeatureCard(
                        icon: Icons.auto_stories_outlined,
                        title: 'Biblioteca One Piece',
                        subtitle:
                            'Consulte todas as cartas do jogo com imagem, código e filtros por cor, tipo e edição.',
                        buttonLabel: 'Abrir biblioteca',
                        onPressed: () => context.go('/library'),
                      ),
                      _HomeFeatureCard(
                        icon: Icons.collections_bookmark_outlined,
                        title: 'Abrir coleção',
                        subtitle:
                            'Acesse cartas obtidas e decks montados, além das ferramentas de importação.',
                        buttonLabel: 'Abrir coleção',
                        onPressed: () => context.go('/collection'),
                      ),
                      _HomeFeatureCard(
                        icon: Icons.storefront_outlined,
                        title: 'Cartas à venda',
                        subtitle:
                            'Gerencie sua área de vendas e copie o link da sua vitrine pública.',
                        buttonLabel: 'Abrir vendas',
                        onPressed: () => context.go('/sales'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
  final VoidCallback onPressed;

  const _HomeFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 18),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle),
              const Spacer(),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward),
                label: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
