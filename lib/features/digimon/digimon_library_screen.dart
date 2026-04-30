import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/digimon_card.dart';
import '../../data/services/digimon_tcg_service.dart';

class DigimonLibraryScreen extends ConsumerStatefulWidget {
  const DigimonLibraryScreen({super.key});

  @override
  ConsumerState<DigimonLibraryScreen> createState() =>
      _DigimonLibraryScreenState();
}

class _DigimonLibraryScreenState extends ConsumerState<DigimonLibraryScreen> {
  static const int _pageSize = 60;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<DigimonCard> _cards = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _query = '';
  String? _errorMessage;
  int _page = 1;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchCards(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final nextQuery = _searchController.text.trim();
      if (nextQuery == _query) return;
      _query = nextQuery;
      _fetchCards(reset: true);
    });
  }

  Future<void> _fetchCards({required bool reset}) async {
    final targetPage = reset ? 1 : _page + 1;

    setState(() {
      if (reset) {
        _loading = true;
        _errorMessage = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await ref
          .read(digimonTcgServiceProvider)
          .searchCards(query: _query, page: targetPage, pageSize: _pageSize);

      if (!mounted) return;
      setState(() {
        _cards = reset ? result.cards : [..._cards, ...result.cards];
        _page = result.page;
        _hasMore = result.hasMore;
        _totalCount = result.totalCount;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(),
        title: const Text('Biblioteca Digimon'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => _fetchCards(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heroicc Digimon API',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Busque por nome, numero, efeito ou outros termos livres. Quando a busca estiver vazia, mostramos a base geral de Digimon.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Ex.: Agumon, BT14, blocker',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DigimonStatChip(
                          label: 'Resultados',
                          value: '$_totalCount',
                        ),
                        _DigimonStatChip(
                          label: 'Carregadas',
                          value: '${_cards.length}',
                        ),
                        _DigimonStatChip(label: 'Pagina', value: '$_page'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erro ao carregar cartas:\n$_errorMessage',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else if (_cards.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma carta encontrada para a busca atual.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final card = _cards[index];
                  return CatalogGridCard(
                    code: card.number.isEmpty ? card.id : card.number,
                    title: card.name,
                    metadata: [
                      card.setName.isEmpty ? '-' : card.setName,
                      card.category.isEmpty ? '-' : card.category,
                      card.rarity.isEmpty ? '-' : card.rarity,
                    ],
                    image: Image.network(
                      card.imageUrl,
                      fit: BoxFit.contain,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    onTap: () => _openCardSheet(context, card),
                  );
                }, childCount: _cards.length),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.53,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator()
                      : _hasMore
                      ? FilledButton.icon(
                          onPressed: () => _fetchCards(reset: false),
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Carregar mais'),
                        )
                      : const Text('Fim dos resultados carregados.'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCardSheet(BuildContext context, DigimonCard card) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DigimonCardDetailsSheet(card: card),
    );
  }
}

class _DigimonStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _DigimonStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DigimonCardDetailsSheet extends StatelessWidget {
  final DigimonCard card;

  const _DigimonCardDetailsSheet({required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                height: 320,
                child: Image.network(
                  card.imageUrl,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              card.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (card.number.isNotEmpty) '#${card.number}',
                if (card.setName.isNotEmpty) card.setName,
              ].join(' - '),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DigimonDetailChip(label: 'Categoria', value: card.category),
                _DigimonDetailChip(label: 'Atributo', value: card.attribute),
                _DigimonDetailChip(label: 'Tipo', value: card.type),
                _DigimonDetailChip(label: 'Forma', value: card.form),
                _DigimonDetailChip(
                  label: 'Cores',
                  value: card.colors.join(', '),
                ),
                _DigimonDetailChip(
                  label: 'Nivel',
                  value: card.level == 0 ? '' : '${card.level}',
                ),
                _DigimonDetailChip(
                  label: 'Play Cost',
                  value: card.playCost == 0 ? '' : '${card.playCost}',
                ),
                _DigimonDetailChip(
                  label: 'DP',
                  value: card.dp == 0 ? '' : '${card.dp}',
                ),
                _DigimonDetailChip(label: 'Raridade', value: card.rarity),
              ],
            ),
            if (card.effect.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Efeito',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(card.effect),
            ],
            if (card.inheritedEffect.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Inherited Effect',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(card.inheritedEffect),
            ],
            if (card.securityEffect.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Security Effect',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(card.securityEffect),
            ],
          ],
        ),
      ),
    );
  }
}

class _DigimonDetailChip extends StatelessWidget {
  final String label;
  final String value;

  const _DigimonDetailChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? '-' : value.trim();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            safeValue,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
