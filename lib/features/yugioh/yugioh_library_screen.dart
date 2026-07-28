import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tcg/tcg_collection_drafts.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../core/widgets/tcg_collection_add_button.dart';
import '../../core/widgets/tcg_liga_price.dart';
import '../../core/widgets/tcg_wanted_add_button.dart';
import '../../data/models/yugioh_card.dart';
import '../../data/services/yugioh_tcg_service.dart';

class YugiohLibraryScreen extends ConsumerStatefulWidget {
  const YugiohLibraryScreen({super.key});

  @override
  ConsumerState<YugiohLibraryScreen> createState() =>
      _YugiohLibraryScreenState();
}

class _YugiohLibraryScreenState extends ConsumerState<YugiohLibraryScreen> {
  static const int _pageSize = 60;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<YugiohCard> _cards = const [];
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
          .read(yugiohTcgServiceProvider)
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

  Future<void> _selectPrintingAndAdd(YugiohCard card) async {
    if (card.printings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A fonte do catálogo ainda não informou edições para esta carta.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TcgLigaPriceScope(
        lookupCodes: card.printings.map((printing) => printing.ligaLookupCode),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    children: [
                      Text(
                        'Escolha a edição',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    itemCount: card.printings.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final printing = card.printings[index];
                      return ListTile(
                        title: Text(printing.setName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                printing.setCode,
                                printing.rarity,
                              ].where((value) => value.isNotEmpty).join(' • '),
                            ),
                            const SizedBox(height: 4),
                            TcgLigaPriceLabel(
                              lookupCode: printing.ligaLookupCode,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TcgCollectionAddButton(
                              draft: card.collectionDraftFor(printing),
                              gameLabel: 'Yu-Gi-Oh',
                              collectionRoute: '/yugioh/collection',
                              compact: true,
                            ),
                            TcgWantedAddButton(
                              draft: card.collectionDraftFor(printing),
                              gameLabel: 'Yu-Gi-Oh',
                              wantedRoute: '/yugioh/wanted',
                              compact: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(destinationRoute: '/yugioh'),
        title: const Text('Biblioteca Yu-Gi-Oh'),
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
                      'YGOPRODeck',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pesquise por nome e navegue pelas cartas mais recentes quando a busca estiver vazia.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Ex.: Blue-Eyes, Dark Magician, Kuriboh',
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
                        _YugiohStatChip(
                          label: 'Resultados',
                          value: '$_totalCount',
                        ),
                        _YugiohStatChip(
                          label: 'Carregadas',
                          value: '${_cards.length}',
                        ),
                        _YugiohStatChip(label: 'Pagina', value: '$_page'),
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
                    code: card.id == 0 ? '-' : '${card.id}',
                    title: card.name,
                    metadata: [
                      card.type.isEmpty ? '-' : card.type,
                      card.attribute.isEmpty ? '-' : card.attribute,
                      card.archetype.isEmpty ? '-' : card.archetype,
                    ],
                    image: Image.network(
                      card.imageUrl,
                      fit: BoxFit.contain,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    trailingActions: [
                      IconButton(
                        tooltip: 'Escolher edição e adicionar à coleção',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _selectPrintingAndAdd(card),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                    footer: Text(
                      card.printings.isEmpty
                          ? 'Edição não informada'
                          : '${card.printings.length} edições disponíveis',
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

  Future<void> _openCardSheet(BuildContext context, YugiohCard card) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _YugiohCardDetailsSheet(
        card: card,
        onChoosePrinting: () => _selectPrintingAndAdd(card),
      ),
    );
  }
}

class _YugiohStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _YugiohStatChip({required this.label, required this.value});

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

class _YugiohCardDetailsSheet extends StatelessWidget {
  final YugiohCard card;
  final VoidCallback onChoosePrinting;

  const _YugiohCardDetailsSheet({
    required this.card,
    required this.onChoosePrinting,
  });

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
                  card.largeImageUrl,
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
              card.type,
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
                _YgoDetailChip(label: 'Atributo', value: card.attribute),
                _YgoDetailChip(label: 'Race', value: card.race),
                _YgoDetailChip(label: 'Arquetipo', value: card.archetype),
                _YgoDetailChip(
                  label: 'Nivel',
                  value: card.level == 0 ? '' : '${card.level}',
                ),
                _YgoDetailChip(
                  label: 'ATK / DEF',
                  value: card.attack == 0 && card.defense == 0
                      ? ''
                      : '${card.attack} / ${card.defense}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onChoosePrinting,
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('Escolher edição e adicionar'),
            ),
            if (card.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Texto da carta',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(card.description),
            ],
          ],
        ),
      ),
    );
  }
}

class _YgoDetailChip extends StatelessWidget {
  final String label;
  final String value;

  const _YgoDetailChip({required this.label, required this.value});

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
