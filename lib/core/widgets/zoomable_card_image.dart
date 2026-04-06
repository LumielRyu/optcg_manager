import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/collection_types.dart';
import '../../core/providers/collection_view_mode_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../data/models/card_record.dart';
import '../../data/services/translation_service.dart';
import '../../features/collection/collection_controller.dart';
import '../../features/collection/deck_details_dialog.dart';
import '../../features/collection/manual_add_dialog.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String _selectedLibrary = CollectionTypes.owned;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

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
      if (_query.isEmpty) return true;

      return card.name.toLowerCase().contains(_query) ||
          card.cardCode.toLowerCase().contains(_query) ||
          card.setName.toLowerCase().contains(_query) ||
          (card.deckName?.toLowerCase().contains(_query) ?? false);
    }).toList();

    final totalUnique = _selectedLibrary == CollectionTypes.deck
        ? _countUniqueDecks(filteredItems)
        : _countUniqueCards(filteredItems);

    final totalCards = filteredItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha coleção'),
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
            tooltip: 'Importar por código',
            onPressed: () => context.push('/code-import'),
            icon: const Icon(Icons.content_paste_outlined),
          ),
          IconButton(
            tooltip: 'Importar por imagem',
            onPressed: () => context.push('/image-import'),
            icon: const Icon(Icons.image_outlined),
          ),
          IconButton(
            tooltip: 'Importar com câmera',
            onPressed: () => context.push('/camera-import'),
            icon: const Icon(Icons.camera_alt_outlined),
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
      body: Column(
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
            viewMode: viewMode,
            onViewModeChanged: (mode) {
              ref.read(collectionViewModeProvider.notifier).setMode(mode);
            },
          ),
          Expanded(
            child: _selectedLibrary == CollectionTypes.deck
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
          ),
        ],
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
}

class _HeaderSection extends StatelessWidget {
  final String selectedLibrary;
  final List<String> libraryOptions;
  final ValueChanged<String> onLibraryChanged;
  final int totalUnique;
  final int totalCards;
  final TextEditingController searchController;
  final CollectionViewMode viewMode;
  final ValueChanged<CollectionViewMode> onViewModeChanged;

  const _HeaderSection({
    required this.selectedLibrary,
    required this.libraryOptions,
    required this.onLibraryChanged,
    required this.totalUnique,
    required this.totalCards,
    required this.searchController,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
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
                SegmentedButton<CollectionViewMode>(
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
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: selectedLibrary == CollectionTypes.deck
                      ? 'Decks'
                      : 'Cartas únicas',
                  value: '$totalUnique',
                  icon: selectedLibrary == CollectionTypes.deck
                      ? Icons.dashboard_customize_outlined
                      : Icons.style_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Total geral',
                  value: '$totalCards',
                  icon: Icons.format_list_numbered,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: selectedLibrary == CollectionTypes.deck
                  ? 'Buscar por deck, carta ou set'
                  : 'Buscar por nome, código ou set',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () => searchController.clear(),
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandardLibraryView extends StatelessWidget {
  final List<CardRecord> items;
  final CollectionViewMode viewMode;

  const _StandardLibraryView({
    super.key,
    required this.items,
    required this.viewMode,
  });

  static const double _cardMaxWidth = 210;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.56;

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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];

          return Card(
            key: ValueKey('list-card-${item.id}-${item.cardCode}'),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      _CardDetailsDialog(card: item, sourceRecords: [item]),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 82,
                        height: 112,
                        child: _CollectionCardImage(
                          key: ValueKey(
                            'list-image-${item.id}-${item.cardCode}-${item.imageUrl}',
                          ),
                          imageUrl: item.imageUrl,
                          cardCode: item.cardCode,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(item.cardCode),
                          const SizedBox(height: 6),
                          Text(
                            'Set: ${item.setName.isEmpty ? '-' : item.setName}',
                          ),
                          const SizedBox(height: 6),
                          Text('Quantidade: ${item.quantity}x'),
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
    }

    return GridView.builder(
      key: ValueKey('collection-grid-$itemsSignature'),
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
          child: InkWell(
            key: ValueKey('grid-card-${item.id}-${item.cardCode}'),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) =>
                    _CardDetailsDialog(card: item, sourceRecords: [item]),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: _CollectionCardImage(
                          key: ValueKey(
                            'grid-image-${item.id}-${item.cardCode}-${item.imageUrl}',
                          ),
                          imageUrl: item.imageUrl,
                          cardCode: item.cardCode,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.cardCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quantidade: ${item.quantity}x',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: decks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
  final double? height;

  const _CollectionCardImage({
    super.key,
    required this.imageUrl,
    required this.cardCode,
    this.fit = BoxFit.contain,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final directUrl = imageUrl.trim();

    if (directUrl.isEmpty) {
      return _ImagePlaceholder(height: height);
    }

    return Image.network(
      directUrl,
      key: ValueKey('collection-image-$cardCode-$directUrl'),
      height: height,
      fit: fit,
      gaplessPlayback: false,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) {
        return _ImagePlaceholder(height: height);
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double? height;

  const _ImagePlaceholder({this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
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
      barrierColor: Colors.black.withOpacity(0.92),
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
                    errorBuilder: (_, __, ___) {
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
                      '${card.name} • ${card.cardCode}',
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
                                      color: Colors.black.withOpacity(0.55),
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
