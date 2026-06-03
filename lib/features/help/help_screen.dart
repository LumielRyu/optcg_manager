import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/home_navigation_button.dart';
import '../../core/widgets/primary_bottom_navigation.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuda e documentacao'),
        actions: const [HomeNavigationButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Central de ajuda',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Veja o que da para fazer no site e qual caminho usar para cada tarefa.',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => context.go('/collection'),
                              icon: const Icon(Icons.collections_bookmark),
                              label: const Text('Abrir colecao'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/camera-import'),
                              icon: const Icon(
                                Icons.center_focus_strong_outlined,
                              ),
                              label: const Text('Escanear carta'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HelpSection(
                    icon: Icons.collections_bookmark_outlined,
                    title: 'Colecao',
                    children: const [
                      'Use a pagina Colecao para ver suas cartas obtidas e seus decks.',
                      'A busca encontra cartas por nome, codigo, set e nome do deck.',
                      'Use filtros para separar por tipo, set, raridade, cor, atributo e favoritas.',
                      'Alterne entre grade e lista quando quiser uma visualizacao mais compacta.',
                      'Toque em uma carta para abrir detalhes, ajustar quantidade, remover ou ver a imagem ampliada.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.center_focus_strong_outlined,
                    title: 'Adicionar cartas por camera',
                    children: const [
                      'Na Colecao, toque em Escanear ou no botao Adicionar cartas > Escanear com camera.',
                      'Aponte para a carta inteira, com boa luz e bordas visiveis.',
                      'Depois da foto, o app abre a revisao para confirmar a carta antes de adicionar.',
                      'Este recurso ainda esta em Beta: algumas cartas podem exigir nova foto ou revisao manual.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.image_search_outlined,
                    title: 'Importar por imagem',
                    children: const [
                      'Use uma foto salva na galeria para tentar reconhecer a carta automaticamente.',
                      'A tela mostra os candidatos encontrados e permite revisar antes de importar.',
                      'Se o reconhecimento falhar, use o codigo manual na mesma tela.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.content_paste_outlined,
                    title: 'Importar por codigo',
                    children: const [
                      'Cole codigos de cartas, um por linha, como 1xOP12-027.',
                      'Tambem da para digitar um unico codigo e escolher a quantidade.',
                      'Antes de adicionar, confira os candidatos encontrados pelo sistema.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.auto_stories_outlined,
                    title: 'Biblioteca One Piece',
                    children: const [
                      'Consulte a base de cartas do One Piece Card Game.',
                      'Filtre e pesquise por nome, codigo, cor, tipo, set e raridade.',
                      'Abra os detalhes da carta para ver imagem, texto e informacoes principais.',
                      'Use a comparacao para analisar varias cartas lado a lado.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'Decks',
                    children: const [
                      'Na Colecao, escolha a aba Decks para ver seus decks cadastrados.',
                      'Ao importar cartas para deck, informe o nome do deck.',
                      'O app evita que um deck ultrapasse o limite configurado no fluxo de importacao.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.storefront_outlined,
                    title: 'Vendas e marketplace',
                    children: const [
                      'Use Vendas para separar cartas que deseja anunciar.',
                      'A vitrine publica pode ser compartilhada com outros jogadores.',
                      'No Marketplace Global, veja cartas anunciadas por outros usuarios e fale pelo WhatsApp.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.emoji_events_outlined,
                    title: 'Semanais',
                    children: const [
                      'A pagina de semanais mostra eventos abertos, participacoes, pontuacao e ranking mensal.',
                      'Jogadores podem entrar em semanais abertos e escolher o deck usado.',
                      'Administradores podem gerenciar partidas, rodadas e resultados.',
                    ],
                  ),
                  _HelpSection(
                    icon: Icons.tips_and_updates_outlined,
                    title: 'Dicas para melhor reconhecimento',
                    children: const [
                      'Use fundo limpo e boa iluminacao.',
                      'Evite reflexos fortes em sleeves brilhantes.',
                      'Mantenha a carta inteira dentro do quadro.',
                      'Se o auto scan tiver dificuldade, use Escanear agora ou a importacao por imagem.',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(currentRoute: '/help'),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> children;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
