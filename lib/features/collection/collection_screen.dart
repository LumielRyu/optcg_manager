import 'dart:async';

import 'package:flutter/gestures.dart';
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
import 'move_to_folder_dialog.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/translation_service.dart';
import '../../data/services/op_card_image_catalog.dart';
import '../../core/widgets/primary_bottom_navigation.dart';
import 'collection_controller.dart';
import 'collection_bulk_sale_import.dart';
import 'collection_sale_import.dart';
import 'collection_showcase_layout.dart';
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
  bool _bulkSaleBusy = false;

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
    final loadPhase = ref.watch(collectionLoadPhaseProvider);
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
        if (loadPhase == CollectionLoadPhase.details)
          const SliverToBoxAdapter(child: _CollectionDetailsLoadingBanner()),
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
              onSell: _addFolderToMarketplace,
              onShowcase: _openFolderShowcase,
              selling: _bulkSaleBusy,
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
      body: loadPhase == CollectionLoadPhase.initial && allItems.isEmpty
          ? const _CollectionInitialLoadingView()
          : _selectedLibrary == CollectionTypes.deck
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
      floatingActionButton:
          loadPhase == CollectionLoadPhase.initial && allItems.isEmpty
          ? null
          : FloatingActionButton.extended(
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

  Future<void> _openFolderShowcase(
    String folderName,
    List<CardRecord> items,
  ) async {
    if (items.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            CollectionShowcaseScreen(folderName: folderName, items: items),
      ),
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
    final folderItems = ref
        .read(collectionControllerProvider)
        .where(
          (item) =>
              item.collectionType == CollectionTypes.owned &&
              item.folderId == folder.id,
        )
        .toList(growable: false);
    final uniqueCards = folderItems.length;
    final totalCards = folderItems.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    final cardSummary = uniqueCards == 0
        ? 'A pasta est\u00e1 vazia.'
        : '$uniqueCards ${uniqueCards == 1 ? 'carta diferente' : 'cartas diferentes'} '
              '\u2022 $totalCards ${totalCards == 1 ? 'carta no total' : 'cartas no total'}';

    final mode = await showDialog<CollectionFolderDeletionMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir pasta?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pasta: ${folder.name}'),
              const SizedBox(height: 4),
              Text(cardSummary),
              const SizedBox(height: 16),
              const Text('O que deseja fazer com as cartas desta pasta?'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('delete-folder-move-to-unfiled'),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(CollectionFolderDeletionMode.moveCardsToUnfiled),
                icon: const Icon(Icons.drive_file_move_outline),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Enviar as cartas para Sem pasta'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('delete-folder-with-cards'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(CollectionFolderDeletionMode.deleteCards),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Excluir a pasta e todas as cartas'),
                ),
              ),
              if (uniqueCards > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Esta segunda op\u00e7\u00e3o remove permanentemente as cartas da cole\u00e7\u00e3o.',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(collectionRepositoryProvider)
          .deleteFolder(folder.id, mode: mode);
      await ref.read(collectionControllerProvider.notifier).load();
      if (!mounted) return;
      setState(() {
        if (_selectedFolder == folder.id) {
          _selectedFolder =
              mode == CollectionFolderDeletionMode.moveCardsToUnfiled
              ? _unfiledFolder
              : _allFolders;
        }
      });
      await _loadFolders();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mode == CollectionFolderDeletionMode.deleteCards
                ? 'Pasta e cartas exclu\u00eddas.'
                : 'Pasta exclu\u00edda. As cartas foram enviadas para Sem pasta.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('N\u00e3o foi poss\u00edvel excluir a pasta.'),
        ),
      );
    }
  }

  Future<void> _addFolderToMarketplace(
    String scopeName,
    List<CardRecord> sourceItems,
  ) async {
    if (_bulkSaleBusy || !requireSignedIn(context)) return;

    final currentItems = ref.read(collectionControllerProvider);
    final existingSales = currentItems
        .where((item) => item.collectionType == CollectionTypes.forSale)
        .toList(growable: false);
    final result = await _showBulkSaleDialog(
      context,
      scopeName: scopeName,
      sourceItems: sourceItems,
      existingSales: existingSales,
    );
    if (result == null || !mounted) return;

    setState(() => _bulkSaleBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final latestItems = ref.read(collectionControllerProvider);
      final latestSales = latestItems
          .where((item) => item.collectionType == CollectionTypes.forSale)
          .toList(growable: false);
      final timestamp = DateTime.now().toUtc();
      final plan = buildBulkSaleImportPlan(
        sources: sourceItems,
        existingSales: latestSales,
        quantityMode: result.quantityMode,
        now: timestamp,
        generatedId: (index) =>
            'bulk-sale-${timestamp.microsecondsSinceEpoch}-$index',
      );

      if (plan.records.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Todas as cópias selecionadas já estão à venda.'),
          ),
        );
        return;
      }

      final controller = ref.read(collectionControllerProvider.notifier);
      await controller.upsertMany(plan.records);

      Object? publicationError;
      if (result.publishNow) {
        final importedKeys = plan.records.map(saleVariantKey).toSet();
        final listingIds = ref
            .read(collectionControllerProvider)
            .where(
              (item) =>
                  item.collectionType == CollectionTypes.forSale &&
                  importedKeys.contains(saleVariantKey(item)),
            )
            .map((item) => item.id)
            .toList(growable: false);
        try {
          await ref
              .read(marketplaceRepositoryProvider)
              .enablePublicListingsByIds(listingIds);
        } catch (error) {
          publicationError = error;
        }
      }

      if (!mounted) return;
      final message = publicationError != null
          ? '${plan.totalQuantity} cópias foram adicionadas às vendas, '
                'mas não foram publicadas. Confira o WhatsApp do perfil e '
                'tente novamente em Cartas à venda.'
          : result.publishNow
          ? '${plan.totalQuantity} cópias de ${plan.addedVariantCount} cartas '
                'foram publicadas no marketplace por 7 dias.'
          : '${plan.totalQuantity} cópias de ${plan.addedVariantCount} cartas '
                'foram adicionadas às vendas.';
      _showSalesImportSnackBar(
        context: context,
        messenger: messenger,
        message: message,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível adicionar a pasta às vendas. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkSaleBusy = false);
    }
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

class _CollectionInitialLoadingView extends StatelessWidget {
  const _CollectionInitialLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              'Carregando sua cole\u00e7\u00e3o...',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Buscando suas cartas. Os detalhes e pre\u00e7os aparecem em seguida.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionDetailsLoadingBanner extends StatelessWidget {
  const _CollectionDetailsLoadingBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'Carregando detalhes das cartas',
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cartas carregadas. Atualizando imagens e detalhes...',
              ),
            ),
          ],
        ),
      ),
    );
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

class _CollectionFoldersSection extends StatefulWidget {
  final List<CollectionFolder> folders;
  final List<CardRecord> items;
  final String selectedFolder;
  final bool loading;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreate;
  final ValueChanged<CollectionFolder> onRename;
  final ValueChanged<CollectionFolder> onDelete;
  final Future<void> Function(String name, List<CardRecord> items) onSell;
  final Future<void> Function(String name, List<CardRecord> items) onShowcase;
  final bool selling;

  const _CollectionFoldersSection({
    required this.folders,
    required this.items,
    required this.selectedFolder,
    required this.loading,
    required this.onSelected,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.onSell,
    required this.onShowcase,
    required this.selling,
  });

  @override
  State<_CollectionFoldersSection> createState() =>
      _CollectionFoldersSectionState();
}

class _CollectionFoldersSectionState extends State<_CollectionFoldersSection> {
  final ScrollController _folderScrollController = ScrollController();
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _folderScrollController.addListener(_syncScrollControls);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollControls());
  }

  @override
  void didUpdateWidget(covariant _CollectionFoldersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folders.length != widget.folders.length) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncScrollControls(),
      );
    }
  }

  @override
  void dispose() {
    _folderScrollController
      ..removeListener(_syncScrollControls)
      ..dispose();
    super.dispose();
  }

  void _syncScrollControls() {
    if (!mounted || !_folderScrollController.hasClients) return;
    final position = _folderScrollController.position;
    final canScrollBack = position.pixels > position.minScrollExtent + 1;
    final canScrollForward = position.pixels < position.maxScrollExtent - 1;
    if (canScrollBack == _canScrollBack &&
        canScrollForward == _canScrollForward) {
      return;
    }
    setState(() {
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
  }

  Future<void> _scrollFolders(double direction) async {
    if (!_folderScrollController.hasClients) return;
    final position = _folderScrollController.position;
    final distance = (position.viewportDimension * 0.78).clamp(220.0, 620.0);
    final target = (position.pixels + distance * direction).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _folderScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleFolderPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_folderScrollController.hasClients) {
      return;
    }
    final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;
    final position = _folderScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _folderScrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollControls());
    final folders = widget.folders;
    final items = widget.items;
    final selectedFolder = widget.selectedFolder;
    final loading = widget.loading;
    final onSelected = widget.onSelected;
    final onCreate = widget.onCreate;
    final onRename = widget.onRename;
    final onDelete = widget.onDelete;
    final onSell = widget.onSell;
    final onShowcase = widget.onShowcase;
    final selling = widget.selling;
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
    final selectedEntry = entries.firstWhere(
      (entry) => entry.id == selectedFolder,
      orElse: () => entries.first,
    );

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
          else ...[
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('collection-folder-showcase'),
                    onPressed: selectedEntry.items.isEmpty
                        ? null
                        : () => onShowcase(
                            selectedEntry.name,
                            selectedEntry.items,
                          ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Modo para print'),
                  ),
                  FilledButton.icon(
                    onPressed: selling || selectedEntry.items.isEmpty
                        ? null
                        : () => onSell(selectedEntry.name, selectedEntry.items),
                    icon: selling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.storefront_outlined),
                    label: Text(
                      selectedEntry.id == '__all__'
                          ? 'Vender toda a coleção'
                          : 'Vender esta pasta',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              child: Listener(
                onPointerSignal: _handleFolderPointerSignal,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                    scrollbars: false,
                  ),
                  child: Scrollbar(
                    controller: _folderScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    child: ListView.separated(
                      key: const Key('collection-folders-strip'),
                      controller: _folderScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 14),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final folder = folders
                            .cast<CollectionFolder?>()
                            .firstWhere(
                              (candidate) => candidate?.id == entry.id,
                              orElse: () => null,
                            );
                        final total = entry.items.fold<int>(
                          0,
                          (sum, item) => sum + item.quantity,
                        );
                        final selected = selectedFolder == entry.id;
                        return SizedBox(
                          width: MediaQuery.sizeOf(context).width < 720
                              ? 205
                              : 238,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          entry.id == '__all__'
                                              ? Icons
                                                    .collections_bookmark_outlined
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
                ),
              ),
            ),
            if (_canScrollBack || _canScrollForward)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('collection-folders-scroll-back'),
                      tooltip: 'Ver pastas anteriores',
                      visualDensity: VisualDensity.compact,
                      onPressed: _canScrollBack
                          ? () => _scrollFolders(-1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Flexible(
                      child: Text(
                        'Deslize ou arraste para ver mais pastas',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('collection-folders-scroll-forward'),
                      tooltip: 'Ver próximas pastas',
                      visualDensity: VisualDensity.compact,
                      onPressed: _canScrollForward
                          ? () => _scrollFolders(1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
          ],
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

class _BulkSaleDialogResult {
  final BulkSaleQuantityMode quantityMode;
  final bool publishNow;

  const _BulkSaleDialogResult({
    required this.quantityMode,
    required this.publishNow,
  });
}

Future<_BulkSaleDialogResult?> _showBulkSaleDialog(
  BuildContext context, {
  required String scopeName,
  required List<CardRecord> sourceItems,
  required List<CardRecord> existingSales,
}) {
  var quantityMode = BulkSaleQuantityMode.allAvailable;
  var publishNow = true;

  return showDialog<_BulkSaleDialogResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = buildBulkSaleImportPlan(
            sources: sourceItems,
            existingSales: existingSales,
            quantityMode: quantityMode,
            now: DateTime.now().toUtc(),
            generatedId: (index) => 'preview-$index',
          );

          return AlertDialog(
            title: const Text('Colocar pasta à venda'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scopeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${preview.addedVariantCount} cartas diferentes • '
                      '${preview.totalQuantity} cópias disponíveis',
                    ),
                    if (preview.skippedVariantCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${preview.skippedVariantCount} cartas já possuem '
                        'todas as cópias em vendas.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Quantidade',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    RadioGroup<BulkSaleQuantityMode>(
                      groupValue: quantityMode,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => quantityMode = value);
                        }
                      },
                      child: const Column(
                        children: [
                          RadioListTile<BulkSaleQuantityMode>(
                            value: BulkSaleQuantityMode.allAvailable,
                            title: Text('Todas as cópias disponíveis'),
                          ),
                          RadioListTile<BulkSaleQuantityMode>(
                            value: BulkSaleQuantityMode.onePerVariant,
                            title: Text('Uma cópia de cada carta'),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: publishNow,
                      onChanged: (value) {
                        setDialogState(() => publishNow = value);
                      },
                      title: const Text('Publicar agora no marketplace'),
                      subtitle: const Text(
                        'Usa o WhatsApp do perfil e mantém os anúncios '
                        'visíveis por 7 dias.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preços já configurados serão preservados. Cartas novas '
                      'ficarão como “Sem preço” até você definir o valor '
                      'manual ou pela Liga em Cartas à venda.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: preview.records.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(
                        _BulkSaleDialogResult(
                          quantityMode: quantityMode,
                          publishNow: publishNow,
                        ),
                      ),
                icon: Icon(
                  publishNow
                      ? Icons.storefront_outlined
                      : Icons.inventory_2_outlined,
                ),
                label: Text(publishNow ? 'Publicar' : 'Adicionar às vendas'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<int?> _showSaleQuantityDialog(
  BuildContext context, {
  required CardRecord card,
  required int maximum,
  required int existingSaleQuantity,
}) async {
  final quantityController = TextEditingController(text: '1');
  String? errorText;
  final hasExistingSale = existingSaleQuantity > 0;

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
            title: Text(
              hasExistingSale
                  ? 'Carta já está nas vendas'
                  : 'Adicionar às vendas',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.name} • ${card.cardCode}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (hasExistingSale) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esta impressão já possui '
                            '$existingSaleQuantity carta(s) em Cartas à venda. '
                            'Deseja acrescentar mais cartas da coleção?',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'Quantidade',
                    helperText: hasExistingSale
                        ? 'Ainda disponível na coleção: $maximum'
                        : 'Disponível para venda: $maximum',
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
              FilledButton(
                onPressed: submit,
                child: Text(hasExistingSale ? 'Adicionar mais' : 'Adicionar'),
              ),
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
    final existingQuantity = existingSale?.quantity ?? 0;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          existingQuantity > 0
              ? 'Esta carta já possui $existingQuantity carta(s) em Cartas '
                    'à venda e todas as cópias da coleção já foram '
                    'anunciadas.'
              : 'Todas as cópias desta carta já estão em Cartas à venda.',
        ),
      ),
    );
    return false;
  }

  final quantity = await _showSaleQuantityDialog(
    context,
    card: card,
    maximum: available,
    existingSaleQuantity: existingSale?.quantity ?? 0,
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
    _showSalesImportSnackBar(
      context: context,
      messenger: messenger,
      message: existingSale == null
          ? quantity == 1
                ? 'Carta adicionada a Cartas à venda.'
                : '$quantity cartas adicionadas a Cartas à venda.'
          : '$quantity carta(s) adicionada(s). Agora existem '
                '${existingSale.quantity + quantity} carta(s) desta impressão '
                'em Cartas à venda.',
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

void _showSalesImportSnackBar({
  required BuildContext context,
  required ScaffoldMessengerState messenger,
  required String message,
}) {
  final router = GoRouter.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: 'ABRIR VENDAS',
          onPressed: () {
            messenger.removeCurrentSnackBar(
              reason: SnackBarClosedReason.action,
            );
            router.go('/sales');
          },
        ),
      ),
    );
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
        cardName: item.name,
        setName: item.setName,
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
        cardName: item.name,
        setName: item.setName,
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

class CollectionShowcaseScreen extends StatefulWidget {
  final String folderName;
  final List<CardRecord> items;

  const CollectionShowcaseScreen({
    super.key,
    required this.folderName,
    required this.items,
  });

  @override
  State<CollectionShowcaseScreen> createState() =>
      _CollectionShowcaseScreenState();
}

class _CollectionShowcaseScreenState extends State<CollectionShowcaseScreen> {
  static const double _cardAspectRatio = 0.714;
  bool _controlsVisible = true;

  late final List<CardRecord> _items = [...widget.items]
    ..sort((a, b) {
      final codeComparison = a.cardCode.toLowerCase().compareTo(
        b.cardCode.toLowerCase(),
      );
      if (codeComparison != 0) return codeComparison;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  @override
  Widget build(BuildContext context) {
    final totalCards = _items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: const Color(0xFF02070D),
      appBar: _controlsVisible
          ? AppBar(
              backgroundColor: const Color(0xFF07131C),
              foregroundColor: Colors.white,
              leading: IconButton(
                tooltip: 'Fechar modo para print',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
              title: const Text('Visualização para print'),
              actions: [
                IconButton(
                  key: const Key('collection-showcase-clean-view'),
                  tooltip: 'Ocultar controles para o print',
                  onPressed: () => setState(() => _controlsVisible = false),
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _controlsVisible
            ? null
            : () => setState(() => _controlsVisible = true),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CollectionShowcaseHeader(
                  folderName: widget.folderName,
                  uniqueCards: _items.length,
                  totalCards: totalCards,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final layout = calculateCollectionShowcaseLayout(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        itemCount: _items.length,
                        cardAspectRatio: _cardAspectRatio,
                      );
                      final rows = (_items.length / layout.columns).ceil();
                      final gridWidth =
                          (layout.cardWidth * layout.columns) +
                          (layout.spacing * (layout.columns - 1));
                      final gridHeight =
                          (layout.cardHeight * rows) +
                          (layout.spacing * (rows - 1));

                      return Center(
                        child: SizedBox(
                          width: gridWidth,
                          height: gridHeight,
                          child: GridView.builder(
                            key: const Key('collection-showcase-grid'),
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: layout.columns,
                                  crossAxisSpacing: layout.spacing,
                                  mainAxisSpacing: layout.spacing,
                                  childAspectRatio: _cardAspectRatio,
                                ),
                            itemCount: _items.length,
                            itemBuilder: (context, index) =>
                                _CollectionShowcaseCard(
                                  item: _items[index],
                                  cardWidth: layout.cardWidth,
                                ),
                          ),
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
}

class _CollectionShowcaseHeader extends StatelessWidget {
  final String folderName;
  final int uniqueCards;
  final int totalCards;

  const _CollectionShowcaseHeader({
    required this.folderName,
    required this.uniqueCards,
    required this.totalCards,
  });

  @override
  Widget build(BuildContext context) {
    const brand = _CollectionShowcaseBrand();
    final folder = Text(
      folderName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
    final totals = Text(
      '$uniqueCards diferentes • $totalCards cartas',
      style: const TextStyle(
        color: Color(0xFFB8D4DE),
        fontWeight: FontWeight.w700,
      ),
    );

    return Container(
      key: const Key('collection-showcase-header'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B202B),
        border: Border.all(
          color: const Color(0xFF13C8D8).withValues(alpha: .5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    brand,
                    const SizedBox(width: 10),
                    Expanded(child: folder),
                  ],
                ),
                const SizedBox(height: 5),
                totals,
              ],
            );
          }
          return Row(
            children: [
              brand,
              const SizedBox(width: 10),
              Expanded(child: folder),
              const SizedBox(width: 8),
              totals,
            ],
          );
        },
      ),
    );
  }
}

class _CollectionShowcaseBrand extends StatelessWidget {
  const _CollectionShowcaseBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF13C8D8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'TCG BH',
        style: TextStyle(
          color: Color(0xFF021116),
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
      ),
    );
  }
}

class _CollectionShowcaseCard extends StatelessWidget {
  final CardRecord item;
  final double cardWidth;

  const _CollectionShowcaseCard({required this.item, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    final compact = cardWidth < 72;
    return Semantics(
      key: ValueKey('collection-showcase-card-${item.id}'),
      label: '${item.name}, ${item.cardCode}, ${item.quantity} cópias',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 3 : 7),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF0B202B),
              child: _CollectionCardImage(
                imageUrl: item.imageUrl,
                cardCode: item.cardCode,
                cardName: item.name,
                setName: item.setName,
                fit: BoxFit.contain,
                logicalDecodeWidth: cardWidth,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 2 : 5,
                  vertical: compact ? 1 : 3,
                ),
                color: Colors.black.withValues(alpha: .78),
                child: Text(
                  item.cardCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 7 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              top: compact ? 2 : 5,
              right: compact ? 2 : 5,
              child: Container(
                key: ValueKey('collection-showcase-quantity-${item.id}'),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 3 : 6,
                  vertical: compact ? 1 : 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF13C8D8),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                child: Text(
                  '${item.quantity}x',
                  style: TextStyle(
                    color: const Color(0xFF021116),
                    fontSize: compact ? 8 : 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionCardImage extends StatefulWidget {
  final String imageUrl;
  final String cardCode;
  final String cardName;
  final String setName;
  final BoxFit fit;
  final double? logicalDecodeWidth;

  const _CollectionCardImage({
    super.key,
    required this.imageUrl,
    required this.cardCode,
    required this.cardName,
    required this.setName,
    this.fit = BoxFit.contain,
    this.logicalDecodeWidth,
  });

  @override
  State<_CollectionCardImage> createState() => _CollectionCardImageState();
}

class _CollectionCardImageState extends State<_CollectionCardImage> {
  static const List<Duration> _retryDelays = <Duration>[
    Duration(milliseconds: 800),
    Duration(seconds: 2),
  ];

  Timer? _retryTimer;
  int _attempt = 0;
  late Future<String> _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = _resolveUrl();
  }

  @override
  void didUpdateWidget(covariant _CollectionCardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cardCode != widget.cardCode ||
        oldWidget.cardName != widget.cardName ||
        oldWidget.setName != widget.setName ||
        oldWidget.logicalDecodeWidth != widget.logicalDecodeWidth) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
      _resolvedUrl = _resolveUrl();
    }
  }

  Future<String> _resolveUrl() => OpCardImageCatalog.resolve(
    cardCode: widget.cardCode,
    cardName: widget.cardName,
    setName: widget.setName,
    currentImageUrl: widget.imageUrl,
  );

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _attempt >= _retryDelays.length) return;
    _retryTimer = Timer(_retryDelays[_attempt], () {
      _retryTimer = null;
      if (!mounted) return;
      setState(() => _attempt++);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        return _buildNetworkImage(context, snapshot.data?.trim() ?? '');
      },
    );
  }

  Widget _buildNetworkImage(BuildContext context, String directUrl) {
    if (directUrl.isEmpty) {
      return const _ImagePlaceholder();
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth =
        widget.logicalDecodeWidth ??
        (MediaQuery.sizeOf(context).width < 600 ? 180.0 : 240.0);
    final decodeWidth = (logicalWidth * devicePixelRatio).round().clamp(
      80,
      720,
    );

    return Image.network(
      directUrl,
      key: ValueKey(
        'collection-image-${widget.cardCode}-$directUrl-attempt-$_attempt',
      ),
      fit: widget.fit,
      gaplessPlayback: false,
      cacheWidth: decodeWidth,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) {
        _scheduleRetry();
        return _ImagePlaceholder(
          label: _attempt < _retryDelays.length
              ? 'Tentando carregar imagem...'
              : 'Imagem indisponivel',
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String? label;

  const _ImagePlaceholder({this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined),
            if (label != null) ...[
              const SizedBox(height: 6),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
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
    final availableQuantity = widget.sourceRecords.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    if (availableQuantity <= 0) return;

    final currentFolderIds = widget.sourceRecords
        .map((item) => item.folderId?.trim() ?? '')
        .toSet();
    final currentFolderId = currentFolderIds.length == 1
        ? currentFolderIds.first
        : null;
    final selected = await showDialog<MoveToFolderResult>(
      context: context,
      builder: (_) => MoveToFolderDialog(
        folders: widget.folders,
        currentFolderId: currentFolderId,
        availableQuantity: availableQuantity,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _isMovingToFolder = true);
    try {
      final repository = ref.read(collectionRepositoryProvider);
      var remaining = selected.quantity;
      for (final item in widget.sourceRecords) {
        if (remaining <= 0) break;
        final quantity = remaining.clamp(1, item.quantity);
        await repository.moveItemQuantityToFolder(
          itemId: item.id,
          folderId: selected.folderId,
          quantity: quantity,
        );
        remaining -= quantity;
      }
      await ref.read(collectionControllerProvider.notifier).load();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível mover as cartas. Tente novamente.'),
          ),
        );
      }
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
                                      cardName: card.name,
                                      setName: card.setName,
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
