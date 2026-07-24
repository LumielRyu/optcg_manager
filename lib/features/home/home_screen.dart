import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/utils/admin_access.dart';
import '../../core/widgets/accessible_action_surface.dart';
import '../../core/widgets/app_page_shell.dart';
import '../../core/widgets/primary_bottom_navigation.dart';
import '../../data/repositories/auth_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    ref.watch(authStateProvider);
    final isLoggedIn = ref.watch(currentUserProvider) != null;
    final isAdmin = isApplicationAdmin(ref.watch(currentUserProvider));

    return Scaffold(
      appBar: AppBar(
        title: const Text('One Piece'),
        actions: [
          IconButton(
            tooltip: 'Trocar TCG',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.swap_horiz_outlined),
          ),
          IconButton(
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Ajuda',
            onPressed: () => context.go('/help'),
            icon: const Icon(Icons.help_outline),
          ),
          if (isLoggedIn)
            IconButton(
              tooltip: 'Sair',
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
              },
              icon: const Icon(Icons.logout),
            )
          else ...[
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Entrar'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: () => context.go('/register'),
                child: const Text('Cadastrar'),
              ),
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontalPadding = width < 600 ? 16.0 : 20.0;
          final contentWidth = width < 1200 ? width : 1200.0;
          final availableWidth = contentWidth - (horizontalPadding * 2);
          final cardsPerRow = width >= 1280
              ? 4
              : width >= 720
              ? 2
              : 1;
          final totalSpacing = 16.0 * (cardsPerRow - 1);
          final cardWidth = (availableWidth - totalSpacing) / cardsPerRow;

          return AppPageShell(
            maxWidth: 1200,
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppHeroPanel(
                  eyebrow: 'OPTCG BH',
                  title: 'Hub One Piece',
                  subtitle:
                      'Controle colecao, vendas, cartas procuradas e biblioteca em uma interface mais rapida para a comunidade de BH.',
                  icon: Icons.waves_outlined,
                  visualAsset: 'assets/editorial/marketplace_hero.png',
                  badges: const [
                    AppBadge(
                      label: 'Marketplace local',
                      icon: Icons.storefront_outlined,
                    ),
                    AppBadge(
                      label: 'Colecao e decks',
                      icon: Icons.collections_bookmark_outlined,
                    ),
                    AppBadge(
                      label: 'Scanner e biblioteca',
                      icon: Icons.center_focus_strong_outlined,
                    ),
                  ],
                  action: FilledButton.icon(
                    onPressed: () => context.go('/marketplace'),
                    icon: const Icon(Icons.public_outlined),
                    label: const Text('Marketplace'),
                  ),
                ),
                const SizedBox(height: 24),
                const AppSectionHeading(
                  icon: Icons.grid_view_rounded,
                  title: 'Escolha seu proximo passo',
                  subtitle:
                      'Acesse rapidamente os recursos principais da plataforma.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: const _HomeFeatureCard(
                        icon: Icons.auto_stories_outlined,
                        title: 'Biblioteca One Piece',
                        subtitle:
                            'Consulte todas as cartas do jogo com imagem, codigo e filtros por cor, tipo e edicao.',
                        buttonLabel: 'Abrir biblioteca',
                        route: '/library',
                      ),
                    ),
                    if (isAdmin)
                      SizedBox(
                        width: cardWidth,
                        child: const _HomeFeatureCard(
                          icon: Icons.monitor_heart_outlined,
                          title: 'Monitor de precos',
                          subtitle:
                              'Confira todas as edicoes da Liga, cobertura dos precos e horario da ultima atualizacao.',
                          buttonLabel: 'Abrir administracao',
                          route: '/admin/liga-prices',
                          requiresAuth: true,
                        ),
                      ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HomeFeatureCard(
                        icon: Icons.collections_bookmark_outlined,
                        title: 'Abrir colecao',
                        subtitle:
                            'Acesse cartas obtidas e decks montados, alem das ferramentas de importacao.',
                        buttonLabel: 'Abrir colecao',
                        route: '/collection',
                        requiresAuth: true,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HomeFeatureCard(
                        icon: Icons.storefront_outlined,
                        title: 'Cartas a venda',
                        subtitle:
                            'Gerencie sua area de vendas e copie o link da sua vitrine publica.',
                        buttonLabel: 'Abrir vendas',
                        route: '/sales',
                        requiresAuth: true,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HomeFeatureCard(
                        icon: Icons.public_outlined,
                        title: 'Marketplace Global',
                        subtitle:
                            'Veja todas as cartas publicas a venda na plataforma e fale direto no WhatsApp com o vendedor.',
                        buttonLabel: 'Abrir marketplace',
                        route: '/marketplace',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HomeFeatureCard(
                        icon: Icons.travel_explore_outlined,
                        title: 'Cartas procuradas',
                        subtitle:
                            'Cadastre cartas que voce procura e veja buscas de outros usuarios para oferecer pelo WhatsApp.',
                        buttonLabel: 'Abrir buscas',
                        route: '/wanted',
                        requiresAuth: true,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HomeFeatureCard(
                        icon: Icons.help_outline,
                        title: 'Ajuda',
                        subtitle:
                            'Veja como usar colecao, scanner, vendas, biblioteca, semanais e importacoes.',
                        buttonLabel: 'Abrir ajuda',
                        route: '/help',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _HomeFeatureCard(
                        icon: Icons.center_focus_strong_outlined,
                        title: 'Reconhecimento por imagem',
                        subtitle:
                            'Identifique cartas por foto usando camera, galeria ou uma imagem de exemplo.',
                        buttonLabel: 'Testar scanner',
                        route: '/card-scan-test',
                        requiresAuth: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/home/one-piece',
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
  final bool requiresAuth;

  const _HomeFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.route,
    this.requiresAuth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.of(context).size.width < 600;
    void openFeature() {
      if (requiresAuth && !requireSignedIn(context)) return;
      context.go(route);
    }

    return AppHoverLift(
      scale: 1.01,
      child: AccessibleActionSurface(
        label: title,
        hint: '$buttonLabel. $subtitle',
        onTap: openFeature,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 132 : 150),
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.2),
                theme.colorScheme.primary.withValues(alpha: 0.035),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: compact ? 24 : 28,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 16 : null,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      buttonLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                color: theme.colorScheme.primary.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
