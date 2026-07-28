import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/accessible_action_surface.dart';
import '../../core/widgets/app_page_shell.dart';
import '../../core/widgets/home_navigation_button.dart';

class WeeklySelectorScreen extends StatelessWidget {
  const WeeklySelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(
          destinationRoute: '/home',
          showHomeIcon: true,
        ),
        title: const Text('Semanais STOP TCG'),
      ),
      body: AppPageShell(
        maxWidth: 1180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppHeroPanel(
              eyebrow: 'Comunidade STOP TCG',
              title: 'Uma casa para todos os semanais',
              subtitle:
                  'Acompanhe resultados, classificacoes e historico dos card games jogados na loja. Escolha o jogo para entrar na arena.',
              icon: Icons.emoji_events_outlined,
              accent: Color(0xFFF4B740),
              badges: [
                AppBadge(
                  label: 'One Piece Card Game',
                  icon: Icons.flag_outlined,
                  color: Color(0xFF28D7E8),
                ),
                AppBadge(
                  label: 'Pokemon TCG',
                  icon: Icons.catching_pokemon,
                  color: Color(0xFFFFCB05),
                ),
                AppBadge(
                  label: 'Historico da loja',
                  icon: Icons.history_outlined,
                ),
              ],
            ),
            const SizedBox(height: 26),
            const AppSectionHeading(
              icon: Icons.sports_esports_outlined,
              title: 'Escolha o semanal',
              subtitle:
                  'Cada jogo tem seu proprio formato, identidade e relatorio.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 800
                    ? (constraints.maxWidth - 18) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    SizedBox(
                      width: width,
                      child: _WeeklyGameCard(
                        title: 'One Piece Card Game',
                        subtitle:
                            'Resultados oficiais do Bandai TCG+, ranking mensal, decks, confrontos e historico da STOP TCG.',
                        eyebrow: 'Grand Line',
                        accent: const Color(0xFFE6A935),
                        secondary: const Color(0xFFD54C3F),
                        icon: Icons.flag_circle_outlined,
                        onTap: () => context.go('/weeklies/one-piece'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _WeeklyGameCard(
                        title: 'Pokemon TCG',
                        subtitle:
                            'Relatorios oficiais importados do TDF, com classificacao, rodadas, partidas e desempenho.',
                        eyebrow: 'Liga Pokemon',
                        accent: const Color(0xFFFFCB05),
                        secondary: const Color(0xFF2A75BB),
                        icon: Icons.catching_pokemon,
                        onTap: () => context.go('/weeklies/pokemon'),
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

class _WeeklyGameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String eyebrow;
  final Color accent;
  final Color secondary;
  final IconData icon;
  final VoidCallback onTap;

  const _WeeklyGameCard({
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    required this.accent,
    required this.secondary,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppHoverLift(
      accent: accent,
      child: AccessibleActionSurface(
        label: 'Abrir semanal de $title',
        hint: subtitle,
        onTap: onTap,
        focusColor: accent,
        child: Container(
          constraints: const BoxConstraints(minHeight: 270),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                secondary.withValues(alpha: 0.2),
                theme.colorScheme.surface.withValues(alpha: 0.92),
                accent.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.42)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.7)),
                    ),
                    child: Icon(icon, color: accent, size: 32),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: accent, size: 30),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                eyebrow.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
