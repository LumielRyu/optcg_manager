import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
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
      final result = await ref.read(yugiohTcgServiceProvider).searchCards(
            query: _query,
            page: targetPage,
            pageSize: _pageSize,
          );

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
                        _YugiohStatChip(
                          label: 'Pagina',
                          value: '$_page',
                        ),
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                        webHtmlElementStrategy:
                            WebHtmlElementStrategy.prefer,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      onTap: () => _openCardSheet(context, card),
                    );
                  },
                  childCount: _cards.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
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
      builder: (context) => _YugiohCardDetailsSheet(card: card),
    );
  }
}

class _YugiohStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _YugiohStatChip({
    required this.label,
    required this.value,
  });

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

  const _YugiohCardDetailsSheet({required this.card});

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
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                  ),
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

  const _YgoDetailChip({
    required this.label,
    required this.value,
  });

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
