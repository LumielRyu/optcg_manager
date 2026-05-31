import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/catalog_grid_card.dart';
import '../../data/models/op_card.dart';
import '../../data/repositories/library_preferences_repository.dart';
import '../../data/services/op_api_service.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../core/widgets/primary_bottom_navigation.dart';
import 'library_card_details_screen.dart';

class OnePieceLibraryScreen extends ConsumerStatefulWidget {
  const OnePieceLibraryScreen({super.key});

  @override
  ConsumerState<OnePieceLibraryScreen> createState() =>
      _OnePieceLibraryScreenState();
}

class _OnePieceLibraryScreenState extends ConsumerState<OnePieceLibraryScreen> {
  static const List<String> _quickTypeFilters = <String>[
    'Leader',
    'Character',
    'Event',
    'Stage',
    'DON!!',
  ];
  static const int _pageSize = 120;
  static const Map<String, String> _libraryColorFilters = <String, String>{
    'Preto': 'Black',
    'Roxo': 'Purple',
    'Vermelho': 'Red',
    'Amarelo': 'Yellow',
    'Verde': 'Green',
  };
  static const Map<String, String> _rarityLabels = <String, String>{
    'C': 'Common',
    'UC': 'Uncommon',
    'R': 'Rare',
    'SR': 'Super Rare',
    'SEC': 'Secret Rare',
    'L': 'Leader',
    'P': 'Promo',
    'SP': 'Special',
    'TR': 'Treasure Rare',
    'DON!!': 'DON!!',
  };

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final Future<List<OpCard>> _cardsFuture;
  Timer? _searchDebounce;
  String _query = '';
  String _selectedType = 'Todos';
  String _selectedSubtype = 'Todos';
  String _selectedSet = 'Todas';
  String _selectedRarity = 'Todas';
  String _selectedAttribute = 'Todos';
  String _selectedSort = 'Codigo';
  final Set<String> _selectedColors = <String>{};
  final Set<String> _favoriteCodes = <String>{};
  final Set<String> _compareCodes = <String>{};
  bool _favoritesOnly = false;
  bool _largeCards = false;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(libraryPreferencesRepositoryProvider);
    _cardsFuture = ref.read(opApiServiceProvider).loadAllCards();
    _favoriteCodes.addAll(prefs.loadFavoriteCodes());
    _compareCodes.addAll(prefs.loadCompareCodes());
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _query = _searchController.text.trim().toLowerCase();
          _visibleCount = _pageSize;
        });
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(opApiServiceProvider);
    final prefs = ref.read(libraryPreferencesRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(),
        title: const Text('Biblioteca One Piece'),
        actions: [
          IconButton(
            tooltip: _largeCards
                ? 'Usar visualizacao compacta'
                : 'Usar cartas maiores',
            onPressed: () {
              setState(() {
                _largeCards = !_largeCards;
              });
            },
            icon: Icon(
              _largeCards
                  ? Icons.view_module_outlined
                  : Icons.photo_size_select_large_outlined,
            ),
          ),
          IconButton(
            tooltip: _favoritesOnly
                ? 'Mostrar todas as cartas'
                : 'Mostrar apenas favoritas',
            onPressed: () {
              setState(() {
                _favoritesOnly = !_favoritesOnly;
                _visibleCount = _pageSize;
              });
            },
            icon: Icon(_favoritesOnly ? Icons.favorite : Icons.favorite_border),
          ),
          Stack(
            children: [
              IconButton(
                tooltip: 'Comparar cartas selecionadas',
                onPressed: _compareCodes.length >= 2
                    ? () => _openCompareScreen(context)
                    : null,
                icon: const Icon(Icons.compare_arrows_outlined),
              ),
              if (_compareCodes.isNotEmpty)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_compareCodes.length}',
                      style: TextStyle(
                        color: theme.colorScheme.onSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Filtros',
            onPressed: () => _openFiltersFromLibrary(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: FutureBuilder<List<OpCard>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LibraryLoadingView();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar a biblioteca:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allCards = (snapshot.data ?? const <OpCard>[])
              .where(_hasVisibleImage)
              .toList(growable: false);
          final filtered =
              allCards
                  .where((card) {
                    final normalizedCode = api.normalizeCode(card.code);
                    final matchesQuery =
                        _query.isEmpty ||
                        card.name.toLowerCase().contains(_query) ||
                        card.code.toLowerCase().contains(_query) ||
                        card.setName.toLowerCase().contains(_query) ||
                        card.rarity.toLowerCase().contains(_query) ||
                        card.attribute.toLowerCase().contains(_query) ||
                        card.type.toLowerCase().contains(_query) ||
                        card.subTypes.toLowerCase().contains(_query);
                    final matchesColor = _matchesSelectedColors(card.color);
                    final matchesType =
                        _selectedType == 'Todos' || card.type == _selectedType;
                    final matchesSubtype =
                        _selectedSubtype == 'Todos' ||
                        card.subTypes == _selectedSubtype;
                    final matchesSet =
                        _selectedSet == 'Todas' || card.setName == _selectedSet;
                    final matchesRarity =
                        _selectedRarity == 'Todas' ||
                        card.rarity == _selectedRarity;
                    final matchesAttribute =
                        _selectedAttribute == 'Todos' ||
                        card.attribute == _selectedAttribute;
                    final matchesFavorite =
                        !_favoritesOnly ||
                        _favoriteCodes.contains(normalizedCode);

                    return matchesQuery &&
                        matchesColor &&
                        matchesType &&
                        matchesSubtype &&
                        matchesSet &&
                        matchesRarity &&
                        matchesAttribute &&
                        matchesFavorite;
                  })
                  .toList(growable: false)
                ..sort(_compareCards);

          final visibleItems = filtered
              .take(_visibleCount)
              .toList(growable: false);
          final hasMore = visibleItems.length < filtered.length;
          final gridStateKey = [
            _query,
            _selectedType,
            _selectedSubtype,
            _selectedSet,
            _selectedRarity,
            _selectedAttribute,
            _selectedSort,
            _largeCards.toString(),
            _favoritesOnly.toString(),
            _selectedColors.join('|'),
            visibleItems
                .map((card) => '${card.code}-${card.name}-${card.image}')
                .join('|'),
          ].join('::');

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 600) {
                _loadMore(filtered.length);
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biblioteca Oficial',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Todas as cartas do One Piece Card Game em um só lugar.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          focusNode: _searchFocusNode,
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Buscar por nome, codigo, edicao, tipo ou raridade',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () => _searchController.clear(),
                                    icon: const Icon(Icons.close),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _LibraryStatCard(
                                label: 'Resultado',
                                value: '${filtered.length}',
                                icon: Icons.filter_alt_outlined,
                              ),
                              const SizedBox(width: 8),
                              _LibraryStatCard(
                                label: 'Favoritas',
                                value: '${_favoriteCodes.length}',
                                icon: Icons.favorite_outline,
                              ),
                              const SizedBox(width: 8),
                              _LibraryStatCard(
                                label: 'Comparando',
                                value: '${_compareCodes.length}',
                                icon: Icons.compare_arrows_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _LibraryFilterGroup(
                                label: 'Colecao',
                                children: [
                                  FilterChip(
                                    avatar: Icon(
                                      _favoritesOnly
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 16,
                                    ),
                                    label: const Text('Favoritas'),
                                    selected: _favoritesOnly,
                                    onSelected: (_) {
                                      setState(() {
                                        _favoritesOnly = !_favoritesOnly;
                                        _visibleCount = _pageSize;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const _LibraryToolbarDivider(),
                              _LibraryFilterGroup(
                                label: 'Categoria',
                                children: [
                                  for (final type in _quickTypeFilters)
                                    FilterChip(
                                      label: Text(type),
                                      selected: _selectedType == type,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedType = _selectedType == type
                                              ? 'Todos'
                                              : type;
                                          _visibleCount = _pageSize;
                                        });
                                      },
                                    ),
                                ],
                              ),
                              const _LibraryToolbarDivider(),
                              _LibraryFilterGroup(
                                label: 'Visual',
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _largeCards = !_largeCards;
                                      });
                                    },
                                    icon: Icon(
                                      _largeCards
                                          ? Icons.view_module_outlined
                                          : Icons
                                                .photo_size_select_large_outlined,
                                    ),
                                    label: Text(
                                      _largeCards
                                          ? 'Grade compacta'
                                          : 'Cartas maiores',
                                    ),
                                  ),
                                ],
                              ),
                              const _LibraryToolbarDivider(),
                              _LibraryFilterGroup(
                                label: 'Busca avancada',
                                children: [
                                  _AdvancedFiltersButton(
                                    activeCount: _activeFilterCount(),
                                    onPressed: () =>
                                        _openFiltersFromLibrary(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (visibleItems.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma carta encontrada com os filtros atuais.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final layout = _gridLayoutForWidth(
                          constraints.crossAxisExtent,
                        );

                        return SliverGrid(
                          key: ValueKey(
                            'library-grid-$gridStateKey-${layout.columns}',
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= visibleItems.length) {
                                return const Card(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                              }

                              final card = visibleItems[index];
                              final normalizedCode = api.normalizeCode(
                                card.code,
                              );
                              final isFavorite = _favoriteCodes.contains(
                                normalizedCode,
                              );
                              final isComparing = _compareCodes.contains(
                                normalizedCode,
                              );
                              final cardVariantKey =
                                  '${card.code}-${card.name}-${card.image}';

                              return CatalogGridCard(
                                key: ValueKey('library-card-$cardVariantKey'),
                                code: card.code,
                                title: card.name,
                                metadata: [
                                  card.type.isEmpty ? '-' : card.type,
                                  card.subTypes.isEmpty ? '-' : card.subTypes,
                                  card.color.isEmpty ? '-' : card.color,
                                ],
                                maxMetadataItems: layout.maxMetadataItems,
                                textScale: layout.textScale,
                                trailingActions: [
                                  IconButton(
                                    tooltip: isComparing
                                        ? 'Remover da comparacao'
                                        : 'Adicionar para comparar',
                                    onPressed: () {
                                      final next = prefs.toggleCompareCode(
                                        normalizedCode,
                                      );
                                      setState(() {
                                        _compareCodes
                                          ..clear()
                                          ..addAll(next);
                                      });
                                    },
                                    icon: Icon(
                                      isComparing
                                          ? Icons.compare_arrows
                                          : Icons.compare_arrows_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: isFavorite
                                        ? 'Remover dos favoritos'
                                        : 'Salvar nos favoritos',
                                    onPressed: () {
                                      final next = prefs.toggleFavoriteCode(
                                        normalizedCode,
                                      );
                                      setState(() {
                                        _favoriteCodes
                                          ..clear()
                                          ..addAll(next);
                                      });
                                    },
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                  ),
                                ],
                                image: Image.network(
                                  key: ValueKey(
                                    'library-image-$cardVariantKey',
                                  ),
                                  card.image,
                                  fit: BoxFit.contain,
                                  webHtmlElementStrategy:
                                      WebHtmlElementStrategy.prefer,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, _, _) {
                                    return const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    );
                                  },
                                ),
                                onTap: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (_) =>
                                        LibraryCardDetailsDialog(card: card),
                                  );
                                },
                              );
                            },
                            childCount: visibleItems.length + (hasMore ? 1 : 0),
                          ),
                          gridDelegate: layout.usesFixedColumns
                              ? SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: layout.columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: layout.childAspectRatio,
                                )
                              : SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: layout.maxCrossAxisExtent,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: layout.childAspectRatio,
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/library',
      ),
    );
  }

  Future<void> _openFiltersPanel({
    required BuildContext context,
    required List<String> types,
    required List<String> subtypes,
    required List<String> sets,
    required List<String> rarities,
    required List<String> attributes,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return DefaultTabController(
              length: 2,
              child: Dialog(
                insetPadding: const EdgeInsets.all(18),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 640,
                    maxHeight: 520,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Filtros da Biblioteca',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (_activeFilterCount() > 0)
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _resetFilters();
                                },
                                child: const Text('Limpar tudo'),
                              ),
                            IconButton(
                              tooltip: 'Fechar filtros',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const TabBar(
                        tabs: [
                          Tab(text: 'Cores'),
                          Tab(text: 'Avancado'),
                        ],
                      ),
                      SizedBox(
                        height: 390,
                        child: TabBarView(
                          children: [
                            _buildColorsTab(sheetSetState),
                            _buildAdvancedFiltersTab(
                              sheetSetState: sheetSetState,
                              types: types,
                              subtypes: subtypes,
                              sets: sets,
                              rarities: rarities,
                              attributes: attributes,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _setFilterState(StateSetter sheetSetState, VoidCallback update) {
    setState(update);
    sheetSetState(() {});
  }

  Future<void> _openFiltersFromLibrary(BuildContext context) async {
    _searchFocusNode.unfocus();
    final allCards = await _cardsFuture;
    final types = _buildOptions(
      allCards.map((card) => card.type),
      initialValue: 'Todos',
    );
    final subtypes = _buildOptions(
      allCards.map((card) => card.subTypes),
      initialValue: 'Todos',
    );
    final sets = _buildOptions(allCards.map((card) => card.setName));
    final rarities = _buildOptions(allCards.map((card) => card.rarity));
    final attributes = _buildOptions(
      allCards.map((card) => card.attribute),
      initialValue: 'Todos',
    );
    if (!context.mounted) return;
    _openFiltersPanel(
      context: context,
      types: types,
      subtypes: subtypes,
      sets: sets,
      rarities: rarities,
      attributes: attributes,
    );
  }

  Widget _buildColorsTab(StateSetter sheetSetState) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in _libraryColorFilters.keys)
              FilterChip(
                label: Text(color),
                selected: _selectedColors.contains(color),
                onSelected: (_) {
                  _setFilterState(sheetSetState, () {
                    if (_selectedColors.contains(color)) {
                      _selectedColors.remove(color);
                    } else {
                      _selectedColors.add(color);
                    }
                    _visibleCount = _pageSize;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedFiltersTab({
    required StateSetter sheetSetState,
    required List<String> types,
    required List<String> subtypes,
    required List<String> sets,
    required List<String> rarities,
    required List<String> attributes,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LibraryDropdown(
          label: 'Categoria',
          value: _selectedType,
          options: types,
          onChanged: (value) {
            if (value == null) return;
            _setFilterState(sheetSetState, () {
              _selectedType = value;
              _visibleCount = _pageSize;
            });
          },
        ),
        const SizedBox(height: 12),
        _LibraryDropdown(
          label: 'Tipo da carta',
          value: _selectedSubtype,
          options: subtypes,
          onChanged: (value) {
            if (value == null) return;
            _setFilterState(sheetSetState, () {
              _selectedSubtype = value;
              _visibleCount = _pageSize;
            });
          },
        ),
        const SizedBox(height: 12),
        _LibraryDropdown(
          label: 'Edicao',
          value: _selectedSet,
          options: <String>['Todas', ...sets],
          onChanged: (value) {
            if (value == null) return;
            _setFilterState(sheetSetState, () {
              _selectedSet = value;
              _visibleCount = _pageSize;
            });
          },
        ),
        const SizedBox(height: 12),
        _LibraryDropdown(
          label: 'Raridade',
          value: _selectedRarity,
          options: <String>['Todas', ...rarities],
          displayLabel: _rarityLabel,
          onChanged: (value) {
            if (value == null) return;
            _setFilterState(sheetSetState, () {
              _selectedRarity = value;
              _visibleCount = _pageSize;
            });
          },
        ),
        const SizedBox(height: 12),
        _LibraryDropdown(
          label: 'Atributo',
          value: _selectedAttribute,
          options: attributes,
          onChanged: (value) {
            if (value == null) return;
            _setFilterState(sheetSetState, () {
              _selectedAttribute = value;
              _visibleCount = _pageSize;
            });
          },
        ),
        const SizedBox(height: 12),
        _LibraryDropdown(
          label: 'Ordenar por',
          value: _selectedSort,
          options: const <String>[
            'Codigo',
            'Nome',
            'Set',
            'Raridade',
            'Categoria',
            'Tipo da carta',
            'Cor',
          ],
          onChanged: (value) {
            if (value == null) return;
            _setFilterState(sheetSetState, () {
              _selectedSort = value;
              _visibleCount = _pageSize;
            });
          },
        ),
      ],
    );
  }

  List<String> _buildOptions(
    Iterable<String> values, {
    String initialValue = '',
  }) {
    final options = {
      ...values.map((value) => value.trim()).where((value) => value.isNotEmpty),
    }.toList()..sort();
    if (initialValue.isEmpty) {
      return options;
    }
    return <String>[initialValue, ...options];
  }

  String _rarityLabel(String rarity) {
    if (rarity == 'Todas') return rarity;
    final label = _rarityLabels[rarity.trim().toUpperCase()];
    if (label == null || label == rarity) return rarity;
    return '$rarity - $label';
  }

  int _activeFilterCount() {
    var count = 0;
    if (_query.isNotEmpty) count++;
    if (_selectedColors.isNotEmpty) count++;
    if (_selectedType != 'Todos') count++;
    if (_selectedSubtype != 'Todos') count++;
    if (_selectedSet != 'Todas') count++;
    if (_selectedRarity != 'Todas') count++;
    if (_selectedAttribute != 'Todos') count++;
    if (_favoritesOnly) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _selectedColors.clear();
      _selectedType = 'Todos';
      _selectedSubtype = 'Todos';
      _selectedSet = 'Todas';
      _selectedRarity = 'Todas';
      _selectedAttribute = 'Todos';
      _selectedSort = 'Codigo';
      _favoritesOnly = false;
      _largeCards = false;
      _visibleCount = _pageSize;
    });
  }

  bool _matchesSelectedColors(String cardColor) {
    if (_selectedColors.isEmpty) return true;

    final normalizedCardColor = cardColor.trim().toLowerCase();
    if (normalizedCardColor.isEmpty) return false;

    for (final selectedLabel in _selectedColors) {
      final apiColor = _libraryColorFilters[selectedLabel];
      if (apiColor == null) continue;
      if (normalizedCardColor.contains(apiColor.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  void _loadMore(int totalCount) {
    if (_visibleCount >= totalCount) return;
    setState(() {
      final next = _visibleCount + _pageSize;
      _visibleCount = next > totalCount ? totalCount : next;
    });
  }

  int _compareCards(OpCard a, OpCard b) {
    switch (_selectedSort) {
      case 'Nome':
        return _compareThenCode(a.name, b.name, a.code, b.code);
      case 'Set':
        return _compareThenCode(a.setName, b.setName, a.code, b.code);
      case 'Raridade':
        return _compareThenCode(a.rarity, b.rarity, a.code, b.code);
      case 'Categoria':
        return _compareThenCode(a.type, b.type, a.code, b.code);
      case 'Tipo da carta':
        return _compareThenCode(a.subTypes, b.subTypes, a.code, b.code);
      case 'Cor':
        return _compareThenCode(a.color, b.color, a.code, b.code);
      case 'Codigo':
      default:
        return a.code.compareTo(b.code);
    }
  }

  int _compareThenCode(
    String left,
    String right,
    String leftCode,
    String rightCode,
  ) {
    final primary = left.toLowerCase().compareTo(right.toLowerCase());
    if (primary != 0) return primary;
    return leftCode.compareTo(rightCode);
  }

  void _openCompareScreen(BuildContext context) {
    final codes = _compareCodes.map(Uri.encodeComponent).join(',');
    context.push('/library/compare?codes=$codes');
  }

  bool _hasVisibleImage(OpCard card) {
    return card.image.trim().isNotEmpty;
  }

  _LibraryGridLayout _gridLayoutForWidth(double width) {
    if (!_largeCards) {
      return const _LibraryGridLayout(
        columns: 0,
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.53,
        maxMetadataItems: 2,
        textScale: 1,
        usesFixedColumns: false,
      );
    }

    return _LibraryGridLayout(
      columns: _largeGridColumns(width),
      maxCrossAxisExtent: 0,
      childAspectRatio: 0.60,
      maxMetadataItems: 2,
      textScale: 1.16,
      usesFixedColumns: true,
    );
  }

  int _largeGridColumns(double width) {
    if (width >= 1700) return 7;
    if (width >= 1180) return 6;
    if (width >= 880) return 4;
    if (width >= 620) return 3;
    if (width >= 390) return 2;
    return 1;
  }
}

class _LibraryGridLayout {
  final int columns;
  final double maxCrossAxisExtent;
  final double childAspectRatio;
  final int maxMetadataItems;
  final double textScale;
  final bool usesFixedColumns;

  const _LibraryGridLayout({
    required this.columns,
    required this.maxCrossAxisExtent,
    required this.childAspectRatio,
    required this.maxMetadataItems,
    required this.textScale,
    required this.usesFixedColumns,
  });
}

class _LibraryLoadingView extends StatelessWidget {
  const _LibraryLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _LibrarySkeletonBox(height: 200, radius: 24),
        SizedBox(height: 16),
        _LibrarySkeletonBox(height: 260, radius: 20),
        SizedBox(height: 12),
        _LibrarySkeletonBox(height: 260, radius: 20),
      ],
    );
  }
}

class _LibraryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _LibraryStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 126,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryFilterGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _LibraryFilterGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _LibraryToolbarDivider extends StatelessWidget {
  const _LibraryToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.8),
    );
  }
}

class _AdvancedFiltersButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onPressed;

  const _AdvancedFiltersButton({
    required this.activeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFilters = activeCount > 0;
    final foreground = hasActiveFilters
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.primary;
    final background = hasActiveFilters
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasActiveFilters
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                'Mais filtros',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final String Function(String option)? displayLabel;
  final ValueChanged<String?> onChanged;

  const _LibraryDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.displayLabel,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            displayLabel?.call(option) ?? option,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _LibrarySkeletonBox extends StatelessWidget {
  final double height;
  final double radius;

  const _LibrarySkeletonBox({required this.height, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
