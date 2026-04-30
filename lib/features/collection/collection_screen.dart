import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/collection_types.dart';
import '../../core/providers/collection_view_mode_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../core/widgets/catalog_dropdown_field.dart';
import '../../core/widgets/catalog_search_field.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/catalog_list_card.dart';
import '../../core/widgets/dashboard_header_panel.dart';
import '../../core/widgets/summary_stat_card.dart';
import '../../data/models/card_record.dart';
import '../../data/services/translation_service.dart';
import '../../core/widgets/primary_bottom_navigation.dart';
import 'collection_controller.dart';
import 'deck_details_dialog.dart';
import 'manual_add_dialog.dart';
import '../../core/widgets/home_navigation_button.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String _selectedLibrary = CollectionTypes.owned;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedType = 'Todos';
  String _selectedSet = 'Todas';
  String _selectedRarity = 'Todas';
  String _selectedColor = 'Todas';
  String _selectedAttribute = 'Todos';
  String _selectedSort = 'C\u00F3digo';
  bool _favoritesOnly = false;
  String? _selectedDeckFilter;

  static const List<String> _collectionLibraries = [
    CollectionTypes.owned,
    CollectionTypes.deck,
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(collectionControllerProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final viewMode = ref.watch(collectionViewModeProvider);

    final libraryItems = allItems.where((card) {
      return card.collectionType == _selectedLibrary;
    }).toList();

    final filteredItems = libraryItems.where((card) {
      final matchesQuery =
          _query.isEmpty ||
          card.name.toLowerCase().contains(_query) ||
          card.cardCode.toLowerCase().contains(_query) ||
          card.setName.toLowerCase().contains(_query) ||
          (card.deckName?.toLowerCase().contains(_query) ?? false);
      final matchesType =
          _selectedType == 'Todos' || card.type == _selectedType;
      final matchesSet =
          _selectedSet == 'Todas' || card.setName == _selectedSet;
      final matchesRarity =
          _selectedRarity == 'Todas' || card.rarity == _selectedRarity;
      final matchesColor =
          _selectedColor == 'Todas' || card.color == _selectedColor;
      final matchesAttribute =
          _selectedAttribute == 'Todos' || card.attribute == _selectedAttribute;
      final matchesFavorites = !_favoritesOnly || card.isFavorite;
      final matchesDeck =
          _selectedLibrary != CollectionTypes.deck ||
          _selectedDeckFilter == null ||
          (card.deckName ?? '').trim() == _selectedDeckFilter;

      return matchesQuery &&
          matchesType &&
          matchesSet &&
          matchesRarity &&
          matchesColor &&
          matchesAttribute &&
          matchesFavorites &&
          matchesDeck;
    }).toList()..sort(_sortCollectionItems);

    final totalUnique = _selectedLibrary == CollectionTypes.deck
        ? _countUniqueDecks(filteredItems)
        : _countUniqueCards(filteredItems);

    final totalCards = filteredItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: const Row(
          children: [
            HomeNavigationButton(),
            SizedBox(width: 8),
            Text('Minha cole\u00E7\u00E3o'),
          ],
        ),
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
            tooltip: 'Importar por c\u00F3digo',
            onPressed: () => context.push('/code-import'),
            icon: const Icon(Icons.content_paste_outlined),
          ),
          IconButton(
            tooltip: 'Adicionar carta',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => const ManualAddDialog(),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeaderSection(
              selectedLibrary: _selectedLibrary,
              libraryOptions: _collectionLibraries,
              onLibraryChanged: (value) {
                setState(() {
                  _selectedLibrary = value;
                });
              },
              totalUnique: totalUnique,
              totalCards: totalCards,
              searchController: _searchController,
              favoritesOnly: _favoritesOnly,
              activeFilterCount: _activeFilterCount(),
              viewMode: viewMode,
              onViewModeChanged: (mode) {
                ref.read(collectionViewModeProvider.notifier).setMode(mode);
              },
              isCollapsed: false,
              onToggleCollapsed: () {},
              onFavoritesOnlyChanged: () {
                setState(() {
                  _favoritesOnly = !_favoritesOnly;
                });
              },
              onOpenFilters: () {
                _openFiltersPanel(context, libraryItems);
              },
            ),
            _selectedLibrary == CollectionTypes.deck
                ? _DeckLibraryView(
                    items: filteredItems,
                    onOpenDeck: (deckName, deckItems) {
                      showDialog(
                        context: context,
                        builder: (_) => DeckDetailsDialog(
                          deckName: deckName,
                          items: deckItems,
                        ),
                      );
                    },
                  )
                : _StandardLibraryView(
                    items: filteredItems,
                    viewMode: viewMode,
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const ManualAddDialog(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/collection',
      ),
    );
  }

  int _countUniqueCards(List<CardRecord> items) {
    final codes = items.map((e) => e.cardCode).toSet();
    return codes.length;
  }

  int _countUniqueDecks(List<CardRecord> items) {
    final decks = items
        .map((e) => (e.deckName ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    return decks.length;
  }

  List<String> _buildOptions(
    Iterable<String> values, {
    String initialValue = '',
  }) {
    final options = {
      ...values.map((value) => value.trim()).where((value) => value.isNotEmpty),
    }.toList()..sort();
    if (initialValue.isEmpty) return options;
    return <String>[initialValue, ...options];
  }

  int _activeFilterCount() {
    var count = 0;
    if (_query.isNotEmpty) count++;
    if (_favoritesOnly) count++;
    if (_selectedType != 'Todos') count++;
    if (_selectedSet != 'Todas') count++;
    if (_selectedRarity != 'Todas') count++;
    if (_selectedColor != 'Todas') count++;
    if (_selectedAttribute != 'Todos') count++;
    if (_selectedDeckFilter != null) count++;
    return count;
  }

  Future<void> _openFiltersPanel(
    BuildContext context,
    List<CardRecord> libraryItems,
  ) async {
    final types = _buildOptions(
      libraryItems.map((card) => card.type),
      initialValue: 'Todos',
    );
    final sets = _buildOptions(
      libraryItems.map((card) => card.setName),
      initialValue: 'Todas',
    );
    final rarities = _buildOptions(
      libraryItems.map((card) => card.rarity),
      initialValue: 'Todas',
    );
    final colors = _buildOptions(
      libraryItems.map((card) => card.color),
      initialValue: 'Todas',
    );
    final attributes = _buildOptions(
      libraryItems.map((card) => card.attribute),
      initialValue: 'Todos',
    );
    final deckNames = _buildOptions(
      libraryItems.map((card) => card.deckName ?? ''),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros da cole\u00E7\u00E3o',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_activeFilterCount() > 0)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _favoritesOnly = false;
                          _selectedType = 'Todos';
                          _selectedSet = 'Todas';
                          _selectedRarity = 'Todas';
                          _selectedColor = 'Todas';
                          _selectedAttribute = 'Todos';
                          _selectedSort = 'C\u00F3digo';
                          _selectedDeckFilter = null;
                          _searchController.clear();
                          _query = '';
                        });
                      },
                      child: const Text('Limpar tudo'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Favoritas'),
                    selected: _favoritesOnly,
                    onSelected: (_) {
                      setState(() {
                        _favoritesOnly = !_favoritesOnly;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CollectionDropdown(
                label: 'Tipo',
                value: _selectedType,
                options: types,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _CollectionDropdown(
                label: 'Edi\u00E7\u00E3o',
                value: _selectedSet,
                options: sets,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedSet = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _CollectionDropdown(
                label: 'Raridade',
                value: _selectedRarity,
                options: rarities,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedRarity = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _CollectionDropdown(
                label: 'Cor',
                value: _selectedColor,
                options: colors,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedColor = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _CollectionDropdown(
                label: 'Atributo',
                value: _selectedAttribute,
                options: attributes,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedAttribute = value;
                  });
                },
              ),
              if (_selectedLibrary == CollectionTypes.deck) ...[
                const SizedBox(height: 12),
                _CollectionDropdown(
                  label: 'Deck',
                  value: _selectedDeckFilter,
                  options: deckNames,
                  onChanged: (value) {
                    setState(() {
                      _selectedDeckFilter = value;
                    });
                  },
                  allowEmpty: true,
                  emptyLabel: 'Todos os decks',
                ),
              ],
              const SizedBox(height: 12),
              _CollectionDropdown(
                label: 'Ordenar por',
                value: _selectedSort,
                options: const [
                  'C\u00F3digo',
                  'Nome',
                  'Quantidade',
                  'Set',
                  'Raridade',
                  'Cor',
                  'Mais recentes',
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedSort = value;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  int _sortCollectionItems(CardRecord a, CardRecord b) {
    switch (_selectedSort) {
      case 'Nome':
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'Quantidade':
        return b.quantity.compareTo(a.quantity);
      case 'Set':
        return a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
      case 'Raridade':
        return a.rarity.toLowerCase().compareTo(b.rarity.toLowerCase());
      case 'Cor':
        return a.color.toLowerCase().compareTo(b.color.toLowerCase());
      case 'Mais recentes':
        return b.dateAddedUtc.compareTo(a.dateAddedUtc);
      case 'C\u00F3digo':
      default:
        return a.cardCode.compareTo(b.cardCode);
    }
  }
}

class _HeaderSection extends StatelessWidget {
  final String selectedLibrary;
  final List<String> libraryOptions;
  final ValueChanged<String> onLibraryChanged;
  final int totalUnique;
  final int totalCards;
  final TextEditingController searchController;
  final bool favoritesOnly;
  final int activeFilterCount;
  final CollectionViewMode viewMode;
  final ValueChanged<CollectionViewMode> onViewModeChanged;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onFavoritesOnlyChanged;
  final VoidCallback onOpenFilters;

  const _HeaderSection({
    required this.selectedLibrary,
    required this.libraryOptions,
    required this.onLibraryChanged,
    required this.totalUnique,
    required this.totalCards,
    required this.searchController,
    required this.favoritesOnly,
    required this.activeFilterCount,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onFavoritesOnlyChanged,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    final segmentedControl = SegmentedButton<CollectionViewMode>(
      segments: const [
        ButtonSegment(
          value: CollectionViewMode.grid,
          icon: Icon(Icons.grid_view_outlined),
          label: Text('Grade'),
        ),
        ButtonSegment(
          value: CollectionViewMode.list,
          icon: Icon(Icons.view_list_outlined),
          label: Text('Lista'),
        ),
      ],
      selected: {viewMode},
      onSelectionChanged: (selection) {
        onViewModeChanged(selection.first);
      },
    );

    return DashboardHeaderPanel(
      top: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: libraryOptions.map((type) {
                final selected = selectedLibrary == type;

                return ChoiceChip(
                  label: Text(CollectionTypes.label(type)),
                  selected: selected,
                  onSelected: (_) => onLibraryChanged(type),
                );
              }).toList(),
            ),
          ),
          if (selectedLibrary != CollectionTypes.deck) ...[
            const SizedBox(width: 12),
            segmentedControl,
          ],
        ],
      ),
      stats: Row(
        children: [
          Expanded(
            child: SummaryStatCard(
              label: selectedLibrary == CollectionTypes.deck
                  ? 'Decks'
                  : 'Cartas \u00FAnicas',
              value: '$totalUnique',
              icon: selectedLibrary == CollectionTypes.deck
                  ? Icons.dashboard_customize_outlined
                  : Icons.style_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryStatCard(
              label: 'Total geral',
              value: '$totalUnique',
              icon: Icons.format_list_numbered,
            ),
          ),
        ],
      ),
      search: CatalogSearchField(
        controller: searchController,
        hintText: selectedLibrary == CollectionTypes.deck
            ? 'Buscar por deck, carta ou set'
            : 'Buscar por nome, c\u00F3digo ou set',
      ),
    );
  }
}

class _CollectionDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool allowEmpty;
  final String emptyLabel;

  const _CollectionDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allowEmpty = false,
    this.emptyLabel = 'Todos',
  });

  @override
  Widget build(BuildContext context) {
    return CatalogDropdownField<String>(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
      allowEmpty: allowEmpty,
      emptyLabel: emptyLabel,
    );
  }
}

class _StandardLibraryView extends StatelessWidget {
  final List<CardRecord> items;
  final CollectionViewMode viewMode;

  const _StandardLibraryView({required this.items, required this.viewMode});

  static const double _cardMaxWidth = 220;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.53;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        title: 'Nenhuma carta encontrada.',
        subtitle: 'Adicione cartas ou ajuste sua busca.',
      );
    }

    final itemsSignature = items
        .map((item) => '${item.id}-${item.cardCode}-${item.imageUrl}')
        .join('|');

    if (viewMode == CollectionViewMode.list) {
      return ListView.separated(
        key: ValueKey('collection-list-$itemsSignature'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];

          return CatalogListCard(
            key: ValueKey('list-card-${item.id}-${item.cardCode}'),
            title: item.name,
            code: item.cardCode,
            metadata: [
              'Set: ${item.setName.isEmpty ? '-' : item.setName}',
              'Quantidade: ${item.quantity}x',
            ],
            image: _CollectionCardImage(
              key: ValueKey(
                'list-image-${item.id}-${item.cardCode}-${item.imageUrl}',
              ),
              imageUrl: item.imageUrl,
              cardCode: item.cardCode,
              fit: BoxFit.contain,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) =>
                    _CardDetailsDialog(card: item, sourceRecords: [item]),
              );
            },
          );
        },
      );
    }

    return GridView.builder(
      key: ValueKey('collection-grid-$itemsSignature'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _cardMaxWidth,
        crossAxisSpacing: _cardSpacing,
        mainAxisSpacing: _cardSpacing,
        childAspectRatio: _gridAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return RepaintBoundary(
          child: CatalogGridCard(
            key: ValueKey('grid-card-${item.id}-${item.cardCode}'),
            code: item.cardCode,
            title: item.name,
            metadata: ['Quantidade: ${item.quantity}x'],
            image: _CollectionCardImage(
              key: ValueKey(
                'grid-image-${item.id}-${item.cardCode}-${item.imageUrl}',
              ),
              imageUrl: item.imageUrl,
              cardCode: item.cardCode,
              fit: BoxFit.contain,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) =>
                    _CardDetailsDialog(card: item, sourceRecords: [item]),
              );
            },
          ),
        );
      },
    );
  }
}

class _DeckLibraryView extends StatelessWidget {
  final List<CardRecord> items;
  final void Function(String deckName, List<CardRecord> deckItems) onOpenDeck;

  const _DeckLibraryView({required this.items, required this.onOpenDeck});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        title: 'Nenhum deck encontrado.',
        subtitle: 'Adicione cartas em um deck para visualizar aqui.',
      );
    }

    final grouped = <String, List<CardRecord>>{};

    for (final item in items) {
      final name = (item.deckName ?? 'Sem nome').trim();
      grouped.putIfAbsent(name, () => []).add(item);
    }

    final decks = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: decks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final deck = decks[index];
        final totalCards = deck.value.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.dashboard_customize_outlined),
            ),
            title: Text(deck.key),
            subtitle: Text(
              '${deck.value.length} cartas únicas • $totalCards cartas no total',
            ),
            onTap: () => onOpenDeck(deck.key, deck.value),
          ),
        );
      },
    );
  }
}

class _CollectionCardImage extends StatelessWidget {
  final String imageUrl;
  final String cardCode;
  final BoxFit fit;

  const _CollectionCardImage({
    super.key,
    required this.imageUrl,
    required this.cardCode,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final directUrl = imageUrl.trim();

    if (directUrl.isEmpty) {
      return const _ImagePlaceholder();
    }

    return Image.network(
      directUrl,
      key: ValueKey('collection-image-$cardCode-$directUrl'),
      fit: fit,
      gaplessPlayback: false,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) {
        return const _ImagePlaceholder();
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CardDetailsDialog extends ConsumerStatefulWidget {
  final CardRecord card;
  final List<CardRecord> sourceRecords;

  const _CardDetailsDialog({required this.card, required this.sourceRecords});

  @override
  ConsumerState<_CardDetailsDialog> createState() => _CardDetailsDialogState();
}

class _CardDetailsDialogState extends ConsumerState<_CardDetailsDialog> {
  final TranslationService _translationService = TranslationService();

  bool _isTranslating = false;
  String? _translatedText;
  bool _showTranslated = false;

  Future<void> _translateText() async {
    if (widget.card.text.trim().isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final translated = await _translationService.translateToPortuguese(
        widget.card.text,
      );

      setState(() {
        _translatedText = translated;
        _showTranslated = true;
      });
    } catch (_) {
      setState(() {
        _translatedText =
            'Não foi possível traduzir o texto da carta.';
        _showTranslated = true;
      });
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  void _openImagePreview() {
    final card = widget.card;

    if (card.imageUrl.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.network(
                    card.imageUrl,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (_, _, _) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 60,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: SafeArea(
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                right: 20,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${card.name} - ${card.cardCode}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeQuantity(int delta) async {
    if (widget.sourceRecords.isEmpty) return;

    final base = widget.sourceRecords.first;
    final currentTotal = widget.sourceRecords.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final newTotal = currentTotal + delta;

    if (newTotal <= 0) {
      for (final item in widget.sourceRecords) {
        await ref.read(collectionControllerProvider.notifier).delete(item.id);
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (widget.sourceRecords.length > 1) {
      for (int i = 1; i < widget.sourceRecords.length; i++) {
        await ref
            .read(collectionControllerProvider.notifier)
            .delete(widget.sourceRecords[i].id);
      }
    }

    await ref
        .read(collectionControllerProvider.notifier)
        .update(base.copyWith(quantity: newTotal));

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _removeGroup() async {
    for (final item in widget.sourceRecords) {
      await ref.read(collectionControllerProvider.notifier).delete(item.id);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 860),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      card.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(card.cardCode, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Center(
                      child: InkWell(
                        onTap: _openImagePreview,
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 320,
                          child: AspectRatio(
                            aspectRatio: 63 / 88,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: _CollectionCardImage(
                                      imageUrl: card.imageUrl,
                                      cardCode: card.cardCode,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toque na imagem para ampliar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Quantidade', '${card.quantity}x'),
                    _infoRow('Set', card.setName),
                    _infoRow('Raridade', card.rarity),
                    _infoRow('Cor', card.color),
                    _infoRow('Tipo', card.type),
                    _infoRow('Atributo', card.attribute),
                    _infoRow(
                      'Biblioteca',
                      CollectionTypes.label(card.collectionType),
                    ),
                    if (card.deckName != null &&
                        card.deckName!.trim().isNotEmpty)
                      _infoRow('Deck', card.deckName!),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _changeQuantity(-1),
                            icon: const Icon(Icons.remove),
                            label: const Text('-1'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _changeQuantity(1),
                            icon: const Icon(Icons.add),
                            label: const Text('+1'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _removeGroup,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remover grupo'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Texto da carta',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(card.text.trim().isEmpty ? 'Sem texto.' : card.text),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isTranslating ? null : _translateText,
                      icon: _isTranslating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.translate),
                      label: Text(
                        _isTranslating
                            ? 'Traduzindo...'
                            : (_showTranslated
                                  ? 'Traduzir novamente'
                                  : 'Traduzir texto'),
                      ),
                    ),
                    if (_showTranslated) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Texto traduzido',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (_translatedText == null ||
                                _translatedText!.trim().isEmpty)
                            ? 'Sem tradução disponível.'
                            : _translatedText!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final safeValue = value.trim().isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(safeValue)),
        ],
      ),
    );
  }
}
