import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../core/widgets/accessible_action_surface.dart';
import '../../core/widgets/app_page_shell.dart';
import '../../core/widgets/legal_footer.dart';
import '../../core/widgets/monetization_slot.dart';
import '../../data/repositories/auth_repository.dart';

class TcgSelectorScreen extends ConsumerWidget {
  const TcgSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    ref.watch(authStateProvider);
    final isLoggedIn = ref.watch(currentUserProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TCG BH'),
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
          if (isLoggedIn) ...[
            IconButton(
              tooltip: 'Perfil',
              onPressed: () => context.push('/profile'),
              icon: const Icon(Icons.account_circle_outlined),
            ),
            IconButton(
              tooltip: 'Sair',
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
              },
              icon: const Icon(Icons.logout),
            ),
          ] else ...[
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

          return AppPageShell(
            maxWidth: 1320,
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppHeroPanel(
                  eyebrow: 'TCG BH',
                  title: 'Escolha seu card game',
                  subtitle:
                      'Entre no jogo que deseja explorar. Cada hub concentra sua biblioteca e recursos da comunidade; os torneios da loja ficam reunidos nos Semanais STOP TCG.',
                  icon: Icons.style_outlined,
                  visualAsset: 'assets/editorial/scanner_card_stack.png',
                  badges: [
                    AppBadge(
                      label: '6 card games',
                      icon: Icons.dashboard_customize_outlined,
                    ),
                    AppBadge(
                      label: 'Bibliotecas conectadas',
                      icon: Icons.auto_stories_outlined,
                    ),
                    AppBadge(
                      label: 'Semanais e ranking',
                      icon: Icons.emoji_events_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _StopWeekliesBanner(onTap: () => context.go('/weeklies')),
                const SizedBox(height: 24),
                _CustomProductsBanner(onTap: () => context.go('/products')),
                const SizedBox(height: 24),
                const AppSectionHeading(
                  icon: Icons.explore_outlined,
                  title: 'Card games disponiveis',
                  subtitle:
                      'Abra um hub para acessar os recursos daquele jogo.',
                ),
                const SizedBox(height: 14),
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
                        accent: const Color(0xFF28D7E8),
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
                        accent: const Color(0xFFFF6B5A),
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
                        accent: const Color(0xFF9B8CFF),
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
                        accent: const Color(0xFF30D67A),
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
                        accent: const Color(0xFFF4B740),
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
                        accent: const Color(0xFF4F8CFF),
                        chipLabel: 'Nova biblioteca',
                        icon: Icons.bolt_outlined,
                        onTap: () => context.go('/riftbound'),
                      ),
                    ),
                  ],
                ),
                const MonetizationSlot(placement: 'home-after-game-list'),
                const SizedBox(height: 28),
                const LegalFooter(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CustomProductsBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomProductsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF28D7E8);

    return AppHoverLift(
      accent: accent,
      child: AccessibleActionSurface(
        label: 'Abrir Produtos personalizados',
        hint: 'Personalize acessórios para seus card games',
        onTap: onTap,
        focusColor: accent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF102D38).withValues(alpha: 0.98),
                accent.withValues(alpha: 0.14),
                const Color(0xFF7C3AED).withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent),
                ),
                child: const Icon(
                  Icons.view_in_ar_outlined,
                  color: accent,
                  size: 31,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUTOS PERSONALIZADOS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Acessórios produzidos em BH para todos os TCGs',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Personalize sua deck box peça por peça, visualize as cores e envie o pedido diretamente pelo WhatsApp.',
                    ),
                  ],
                ),
              ),
              ExcludeFocus(
                child: IgnorePointer(
                  child: FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Personalizar produto'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopWeekliesBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _StopWeekliesBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gold = Color(0xFFF4B740);
    return AppHoverLift(
      accent: gold,
      child: AccessibleActionSurface(
        label: 'Abrir Semanais STOP TCG',
        hint: 'Resultados e rankings de todos os jogos da loja',
        onTap: onTap,
        focusColor: gold,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF173541).withValues(alpha: 0.96),
                gold.withValues(alpha: 0.12),
                const Color(0xFF2A75BB).withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: gold.withValues(alpha: 0.52)),
          ),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: gold,
                  size: 31,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEMANAIS STOP TCG',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: gold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Resultados e rankings de todos os jogos da loja',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'One Piece e Pokemon ja estao disponiveis em uma area independente dos hubs de cada TCG.',
                    ),
                  ],
                ),
              ),
              ExcludeFocus(
                child: IgnorePointer(
                  child: FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Abrir semanais'),
                  ),
                ),
              ),
            ],
          ),
        ),
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

    return AppHoverLift(
      accent: accent,
      scale: 1.01,
      child: AccessibleActionSurface(
        label: '$title. $chipLabel',
        hint: 'Abrir $title. $subtitle',
        onTap: onTap,
        focusColor: accent,
        child: Container(
          constraints: const BoxConstraints(minHeight: 210),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.2),
                accent.withValues(alpha: 0.045),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: accent.withValues(alpha: 0.74), width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: accent.withValues(alpha: 0.85),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(subtitle, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
