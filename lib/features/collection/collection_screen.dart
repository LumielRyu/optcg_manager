import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/collection_types.dart';
import '../../core/providers/collection_view_mode_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/widgets/catalog_dropdown_field.dart';
import '../../core/widgets/catalog_search_field.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/catalog_list_card.dart';
import '../../core/widgets/liga_price_display.dart';
import '../../core/widgets/dashboard_header_panel.dart';
import '../../core/widgets/summary_stat_card.dart';
import '../../data/models/card_record.dart';
import '../../data/models/collection_folder.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/services/translation_service.dart';
import '../../core/widgets/primary_bottom_navigation.dart';
import 'collection_controller.dart';
import 'collection_sale_import.dart';
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
  List<CollectionFolder> _folders = const [];
  String _selectedFolder = _allFolders;
  bool _foldersLoading = true;

  static const String _allFolders = '__all__';
  static const String _unfiledFolder = '__unfiled__';

  static const List<String> _collectionLibraries = [
    CollectionTypes.owned,
    CollectionTypes.deck,
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadFolders);
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

    final unfilteredLibraryItems = allItems.where((card) {
      return card.collectionType == _selectedLibrary;
    }).toList();
    final libraryItems = unfilteredLibraryItems.where((card) {
      if (_selectedLibrary != CollectionTypes.owned ||
          _selectedFolder == _allFolders) {
        return true;
      }
      if (_selectedFolder == _unfiledFolder) {
        return (card.folderId ?? '').isEmpty;
      }
      return card.folderId == _selectedFolder;
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
    final destination = _selectedLibrary == CollectionTypes.deck
        ? CollectionTypes.deck
        : CollectionTypes.owned;
    final header = _HeaderSection(
      selectedLibrary: _selectedLibrary,
      libraryOptions: _collectionLibraries,
      onLibraryChanged: (value) {
        setState(() {
          _selectedLibrary = value;
        });
      },
      totalUnique: totalUnique,
      totalCards: totalCards,
      valuationItems: libraryItems
          .map(
            (card) => LigaPriceCollectionItemReference(
              cardName: card.name,
              cardCode: card.cardCode,
              imageUrl: card.imageUrl,
              quantity: card.quantity,
            ),
          )
          .toList(growable: false),
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
    );
    final collectionContent = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (_selectedLibrary == CollectionTypes.owned)
          SliverToBoxAdapter(
            child: _CollectionFoldersSection(
              folders: _folders,
              items: unfilteredLibraryItems,
              selectedFolder: _selectedFolder,
              loading: _foldersLoading,
              onSelected: (value) {
                setState(() => _selectedFolder = value);
              },
              onCreate: _createFolder,
              onRename: _renameFolder,
              onDelete: _deleteFolder,
            ),
          ),
        if (_selectedLibrary == CollectionTypes.deck)
          _VirtualizedDeckLibraryView(
            items: filteredItems,
            onOpenDeck: (deckName, deckItems) {
              showDialog(
                context: context,
                builder: (_) =>
                    DeckDetailsDialog(deckName: deckName, items: deckItems),
              );
            },
          )
        else
          _VirtualizedStandardLibraryView(
            items: filteredItems,
            viewMode: viewMode,
            folders: _folders,
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: const Row(
          children: [
            HomeNavigationButton(destinationRoute: '/home/one-piece'),
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
            tooltip: 'Ajuda',
            onPressed: () => context.go('/help'),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: _selectedLibrary == CollectionTypes.deck
          ? collectionContent
          : LigaPriceScope(
              cards: unfilteredLibraryItems
                  .map(
                    (card) => LigaPriceCardReference(
                      cardName: card.name,
                      cardCode: card.cardCode,
                      imageUrl: card.imageUrl,
                    ),
                  )
                  .toList(growable: false),
              child: collectionContent,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCardsSheet(destination),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Adicionar cartas'),
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/collection',
      ),
    );
  }

  void _openCameraImport(String destination) {
    if (!requireSignedIn(context)) {
      return;
    }

    context.push('/camera-import?destination=$destination');
  }

  void _openCodeImport(String destination) {
    if (!requireSignedIn(context)) {
      return;
    }

    context.push('/code-import?destination=$destination');
  }

  Future<void> _openManualAddDialog() async {
    if (!requireSignedIn(context)) {
      return;
    }

    final initialFolderId =
        _selectedFolder != _allFolders && _selectedFolder != _unfiledFolder
        ? _selectedFolder
        : null;
    await showDialog(
      context: context,
      builder: (_) =>
          ManualAddDialog(folders: _folders, initialFolderId: initialFolderId),
    );
  }

  Future<void> _openAddCardsSheet(String destination) async {
    if (!requireSignedIn(context)) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adicionar cartas',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha o jeito mais rápido para registrar cartas na ${CollectionTypes.label(destination).toLowerCase()}.',
              ),
              const SizedBox(height: 16),
              _AddMethodTile(
                icon: Icons.local_library_outlined,
                title: 'Importar carta pela biblioteca',
                subtitle:
                    'Digite o código, confira a imagem e escolha a versão da carta.',
                highlighted: true,
                onTap: () {
                  Navigator.of(context).pop();
                  _openManualAddDialog();
                },
              ),
              const SizedBox(height: 10),
              _AddMethodTile(
                icon: Icons.content_paste_outlined,
                title: 'Adicionar por código',
                subtitle: 'Cole um ou mais códigos ou uma lista completa.',
                onTap: () {
                  Navigator.of(context).pop();
                  _openCodeImport(destination);
                },
              ),
              const SizedBox(height: 10),
              _AddMethodTile(
                icon: Icons.center_focus_strong_outlined,
                title: 'Escanear com câmera • Beta',
                subtitle:
                    'Reconheça cartas com a câmera. O resultado ainda pode exigir revisão.',
                onTap: () {
                  Navigator.of(context).pop();
                  _openCameraImport(destination);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await ref
          .read(collectionRepositoryProvider)
          .listFolders();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _foldersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _foldersLoading = false);
    }
  }

  Future<String?> _askFolderName({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nome da pasta',
            hintText: 'Ex.: Coleção principal',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _createFolder() async {
    final name = await _askFolderName(title: 'Nova pasta');
    if (name == null || !mounted) return;
    try {
      final folder = await ref
          .read(collectionRepositoryProvider)
          .createFolder(name);
      await _loadFolders();
      if (!mounted) return;
      setState(() => _selectedFolder = folder.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível criar a pasta. Verifique se o nome já existe.',
          ),
        ),
      );
    }
  }

  Future<void> _renameFolder(CollectionFolder folder) async {
    final name = await _askFolderName(
      title: 'Renomear pasta',
      initialValue: folder.name,
    );
    if (name == null || !mounted) return;
    try {
      await ref
          .read(collectionRepositoryProvider)
          .renameFolder(folder.id, name);
      await _loadFolders();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível renomear a pasta.')),
      );
    }
  }

  Future<void> _deleteFolder(CollectionFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir pasta?'),
        content: Text(
          'As cartas de “${folder.name}” não serão excluídas. '
          'Elas voltarão para “Sem pasta”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir pasta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(collectionRepositoryProvider).deleteFolder(folder.id);
    await ref.read(collectionControllerProvider.notifier).load();
    if (!mounted) return;
    setState(() {
      if (_selectedFolder == folder.id) {
        _selectedFolder = _unfiledFolder;
      }
    });
    await _loadFolders();
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
  final List<LigaPriceCollectionItemReference> valuationItems;
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
    required this.valuationItems,
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
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minha coleção One Piece',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gerencie cartas, decks e pastas em um só painel.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
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
        ],
      ),
      stats: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final cards = [
            SummaryStatCard(
              label: selectedLibrary == CollectionTypes.deck
                  ? 'Decks'
                  : 'Cartas únicas',
              value: '$totalUnique',
              icon: selectedLibrary == CollectionTypes.deck
                  ? Icons.dashboard_customize_outlined
                  : Icons.style_outlined,
            ),
            SummaryStatCard(
              label: 'Total geral',
              value: '$totalCards',
              icon: Icons.format_list_numbered,
            ),
            if (selectedLibrary == CollectionTypes.owned)
              LigaCollectionValueCard(items: valuationItems),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final card in cards) ...[
                  card,
                  if (card != cards.last) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Row(
            children: [
              for (final card in cards) ...[
                Expanded(child: card),
                if (card != cards.last) const SizedBox(width: 12),
              ],
            ],
          );
        },
      ),
      search: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogSearchField(
            controller: searchController,
            hintText: selectedLibrary == CollectionTypes.deck
                ? 'Buscar por deck, carta ou set'
                : 'Buscar por nome, código ou set',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (selectedLibrary != CollectionTypes.deck) segmentedControl,
              FilterChip(
                label: const Text('Favoritas'),
                selected: favoritesOnly,
                onSelected: (_) => onFavoritesOnlyChanged(),
                avatar: const Icon(Icons.star_outline, size: 18),
              ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 18),
                label: Text(
                  activeFilterCount == 0
                      ? 'Filtros'
                      : 'Filtros ($activeFilterCount)',
                ),
                onPressed: onOpenFilters,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionFoldersSection extends StatelessWidget {
  final List<CollectionFolder> folders;
  final List<CardRecord> items;
  final String selectedFolder;
  final bool loading;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreate;
  final ValueChanged<CollectionFolder> onRename;
  final ValueChanged<CollectionFolder> onDelete;

  const _CollectionFoldersSection({
    required this.folders,
    required this.items,
    required this.selectedFolder,
    required this.loading,
    required this.onSelected,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final unfiled = items
        .where((item) => (item.folderId ?? '').isEmpty)
        .toList(growable: false);
    final entries = <({String id, String name, List<CardRecord> items})>[
      (id: '__all__', name: 'Todas as cartas', items: items),
      (id: '__unfiled__', name: 'Sem pasta', items: unfiled),
      for (final folder in folders)
        (
          id: folder.id,
          name: folder.name,
          items: items
              .where((item) => item.folderId == folder.id)
              .toList(growable: false),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pastas da coleção',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Separe suas cartas e acompanhe o valor de cada pasta.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onCreate,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Nova pasta'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const LinearProgressIndicator()
          else
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final folder = folders.cast<CollectionFolder?>().firstWhere(
                    (candidate) => candidate?.id == entry.id,
                    orElse: () => null,
                  );
                  final total = entry.items.fold<int>(
                    0,
                    (sum, item) => sum + item.quantity,
                  );
                  final selected = selectedFolder == entry.id;
                  return SizedBox(
                    width: 246,
                    child: Card(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelected(entry.id),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    entry.id == '__all__'
                                        ? Icons.collections_bookmark_outlined
                                        : entry.id == '__unfiled__'
                                        ? Icons.folder_off_outlined
                                        : Icons.folder_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (folder != null)
                                    PopupMenuButton<String>(
                                      tooltip: 'Opções da pasta',
                                      onSelected: (action) {
                                        if (action == 'rename') {
                                          onRename(folder);
                                        } else if (action == 'delete') {
                                          onDelete(folder);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: Text('Renomear'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Excluir'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '${entry.items.length} cartas diferentes • '
                                '$total no total',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              LigaCollectionValueText(
                                items: entry.items
                                    .map(
                                      (card) =>
                                          LigaPriceCollectionItemReference(
                                            cardName: card.name,
                                            cardCode: card.cardCode,
                                            imageUrl: card.imageUrl,
                                            quantity: card.quantity,
                                          ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
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

class _AddMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  const _AddMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: highlighted
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: highlighted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: highlighted
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

Future<int?> _showSaleQuantityDialog(
  BuildContext context, {
  required CardRecord card,
  required int maximum,
}) async {
  final quantityController = TextEditingController(text: '1');
  String? errorText;

  final quantity = await showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final value = int.tryParse(quantityController.text.trim());
            if (value == null || value <= 0 || value > maximum) {
              setDialogState(
                () => errorText = 'Informe um valor entre 1 e $maximum.',
              );
              return;
            }
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: const Text('Adicionar às vendas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.name} • ${card.cardCode}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'Quantidade',
                    helperText: 'Disponível para venda: $maximum',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(onPressed: submit, child: const Text('Adicionar')),
            ],
          );
        },
      );
    },
  );

  quantityController.dispose();
  return quantity;
}

Future<bool> _importCardToSales(
  BuildContext context,
  WidgetRef ref,
  CardRecord card,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(collectionRepositoryProvider);
  final existingSale = repository.findByCodeAndCollection(
    cardCode: card.cardCode,
    collectionType: CollectionTypes.forSale,
    imageUrl: card.imageUrl,
  );
  final available = availableQuantityForSale(
    source: card,
    existingSale: existingSale,
  );

  if (available <= 0) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Todas as cópias desta carta já estão em Cartas à venda.',
        ),
      ),
    );
    return false;
  }

  final quantity = await _showSaleQuantityDialog(
    context,
    card: card,
    maximum: available,
  );
  if (quantity == null || !context.mounted) return false;

  try {
    final saleRecord = buildSaleImportRecord(
      source: card,
      existingSale: existingSale,
      quantity: quantity,
      now: DateTime.now().toUtc(),
      generatedId: 'sale-import-${DateTime.now().microsecondsSinceEpoch}',
    );
    final controller = ref.read(collectionControllerProvider.notifier);
    if (existingSale == null) {
      await controller.add(saleRecord);
    } else {
      await controller.update(saleRecord);
    }

    if (!context.mounted) return true;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          quantity == 1
              ? 'Carta adicionada a Cartas à venda.'
              : '$quantity cartas adicionadas a Cartas à venda.',
        ),
        action: SnackBarAction(
          label: 'ABRIR VENDAS',
          onPressed: () => context.go('/sales'),
        ),
      ),
    );
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível adicionar a carta às vendas. Tente novamente.',
        ),
      ),
    );
    return false;
  }
}

class _VirtualizedStandardLibraryView extends ConsumerWidget {
  final List<CardRecord> items;
  final CollectionViewMode viewMode;
  final List<CollectionFolder> folders;

  const _VirtualizedStandardLibraryView({
    required this.items,
    required this.viewMode,
    required this.folders,
  });

  static const double _cardMaxWidth = 220;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.53;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          title: 'Nenhuma carta encontrada.',
          subtitle: 'Adicione cartas ou ajuste sua busca.',
        ),
      );
    }

    if (viewMode == CollectionViewMode.list) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index.isOdd) return const SizedBox(height: 10);
            return _buildListCard(context, ref, items[index ~/ 2]);
          }, childCount: (items.length * 2) - 1),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _cardMaxWidth,
          crossAxisSpacing: _cardSpacing,
          mainAxisSpacing: _cardSpacing,
          childAspectRatio: _gridAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGridCard(context, ref, items[index]),
          childCount: items.length,
          addRepaintBoundaries: false,
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context, WidgetRef ref, CardRecord item) {
    return CatalogListCard(
      key: ValueKey('list-card-${item.id}-${item.cardCode}'),
      title: item.name,
      code: item.cardCode,
      metadata: [
        'Set: ${item.setName.isEmpty ? '-' : item.setName}',
        'Quantidade: ${item.quantity}x',
        'Pasta: ${_folderName(item)}',
      ],
      trailing: SizedBox(
        width: 155,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            LigaPriceLabel(
              cardName: item.name,
              cardCode: item.cardCode,
              imageUrl: item.imageUrl,
            ),
            IconButton(
              tooltip: 'Adicionar \u00e0s vendas',
              onPressed: () => _importCardToSales(context, ref, item),
              icon: const Icon(Icons.add_shopping_cart_outlined),
            ),
          ],
        ),
      ),
      image: _CollectionCardImage(
        key: ValueKey(
          'list-image-${item.id}-${item.cardCode}-${item.imageUrl}',
        ),
        imageUrl: item.imageUrl,
        cardCode: item.cardCode,
      ),
      onTap: () => _openCardDetails(context, item),
    );
  }

  Widget _buildGridCard(BuildContext context, WidgetRef ref, CardRecord item) {
    return CatalogGridCard(
      key: ValueKey('grid-card-${item.id}-${item.cardCode}'),
      code: item.cardCode,
      title: item.name,
      metadata: [
        'Quantidade: ${item.quantity}x',
        'Pasta: ${_folderName(item)}',
      ],
      trailingActions: [
        IconButton(
          tooltip: 'Adicionar \u00e0s vendas',
          visualDensity: VisualDensity.compact,
          onPressed: () => _importCardToSales(context, ref, item),
          icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
        ),
      ],
      footer: LigaPriceLabel(
        cardName: item.name,
        cardCode: item.cardCode,
        imageUrl: item.imageUrl,
      ),
      image: _CollectionCardImage(
        key: ValueKey(
          'grid-image-${item.id}-${item.cardCode}-${item.imageUrl}',
        ),
        imageUrl: item.imageUrl,
        cardCode: item.cardCode,
      ),
      onTap: () => _openCardDetails(context, item),
    );
  }

  void _openCardDetails(BuildContext context, CardRecord item) {
    showDialog(
      context: context,
      builder: (_) => _CardDetailsDialog(
        card: item,
        sourceRecords: [item],
        folders: folders,
      ),
    );
  }

  String _folderName(CardRecord item) {
    final folderId = item.folderId;
    if (folderId == null || folderId.isEmpty) return 'Sem pasta';
    for (final folder in folders) {
      if (folder.id == folderId) return folder.name;
    }
    return 'Sem pasta';
  }
}

class _VirtualizedDeckLibraryView extends StatelessWidget {
  final List<CardRecord> items;
  final void Function(String deckName, List<CardRecord> deckItems) onOpenDeck;

  const _VirtualizedDeckLibraryView({
    required this.items,
    required this.onOpenDeck,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          title: 'Nenhum deck encontrado.',
          subtitle: 'Adicione cartas em um deck para visualizar aqui.',
        ),
      );
    }

    final grouped = <String, List<CardRecord>>{};
    for (final item in items) {
      final name = (item.deckName ?? 'Sem nome').trim();
      grouped.putIfAbsent(name, () => []).add(item);
    }
    final decks = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index.isOdd) return const SizedBox(height: 10);
          final deck = decks[index ~/ 2];
          final totalCards = deck.value.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final uniqueCards = deck.value
              .map((item) => item.cardCode.trim().toUpperCase())
              .where((code) => code.isNotEmpty)
              .toSet()
              .length;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.dashboard_customize_outlined),
              ),
              title: Text(deck.key),
              subtitle: Text(
                '$uniqueCards cartas diferentes \u2022 '
                '$totalCards cartas no total',
              ),
              onTap: () => onOpenDeck(deck.key, deck.value),
            ),
          );
        }, childCount: (decks.length * 2) - 1),
      ),
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

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth = MediaQuery.sizeOf(context).width < 600 ? 180.0 : 240.0;
    final decodeWidth = (logicalWidth * devicePixelRatio).round().clamp(
      180,
      720,
    );

    return Image.network(
      directUrl,
      key: ValueKey('collection-image-$cardCode-$directUrl'),
      fit: fit,
      gaplessPlayback: false,
      cacheWidth: decodeWidth,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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
  final List<CollectionFolder> folders;

  const _CardDetailsDialog({
    required this.card,
    required this.sourceRecords,
    this.folders = const [],
  });

  @override
  ConsumerState<_CardDetailsDialog> createState() => _CardDetailsDialogState();
}

class _CardDetailsDialogState extends ConsumerState<_CardDetailsDialog> {
  final TranslationService _translationService = TranslationService();

  bool _isTranslating = false;
  String? _translatedText;
  bool _showTranslated = false;
  bool _isAddingToSales = false;
  bool _isMovingToFolder = false;

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
        _translatedText = 'Não foi possível traduzir o texto da carta.';
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

  Future<void> _addToSales() async {
    setState(() => _isAddingToSales = true);
    try {
      await _importCardToSales(context, ref, widget.card);
    } finally {
      if (mounted) setState(() => _isAddingToSales = false);
    }
  }

  Future<void> _moveToFolder() async {
    const unfiled = '__unfiled__';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Mover para pasta'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(unfiled),
            child: const ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('Sem pasta'),
            ),
          ),
          for (final folder in widget.folders)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(folder.id),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
              ),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _isMovingToFolder = true);
    try {
      final repository = ref.read(collectionRepositoryProvider);
      final folderId = selected == unfiled ? null : selected;
      for (final item in widget.sourceRecords) {
        await repository.moveItemToFolder(item.id, folderId);
      }
      await ref.read(collectionControllerProvider.notifier).load();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isMovingToFolder = false);
    }
  }

  String _currentFolderName() {
    final folderId = widget.card.folderId;
    if (folderId == null || folderId.isEmpty) return 'Sem pasta';
    for (final folder in widget.folders) {
      if (folder.id == folderId) return folder.name;
    }
    return 'Sem pasta';
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
                    if (card.collectionType == CollectionTypes.owned)
                      _infoRow('Pasta', _currentFolderName()),
                    if (card.deckName != null &&
                        card.deckName!.trim().isNotEmpty)
                      _infoRow('Deck', card.deckName!),
                    const SizedBox(height: 16),
                    LigaPriceDetailsPanel(
                      cardName: card.name,
                      cardCode: card.cardCode,
                      imageUrl: card.imageUrl,
                    ),
                    const SizedBox(height: 16),
                    if (card.collectionType == CollectionTypes.owned) ...[
                      OutlinedButton.icon(
                        onPressed: _isMovingToFolder ? null : _moveToFolder,
                        icon: _isMovingToFolder
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.drive_file_move_outline),
                        label: const Text('Mover para pasta'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.icon(
                      onPressed: _isAddingToSales ? null : _addToSales,
                      icon: _isAddingToSales
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Adicionar às vendas'),
                    ),
                    const SizedBox(height: 8),
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
