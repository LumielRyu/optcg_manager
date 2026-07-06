import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/share_link_helper.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/summary_stat_card.dart';
import '../../data/models/wanted_card_listing.dart';
import '../../data/repositories/wanted_cards_repository.dart';

class SharedWantedCardsScreen extends ConsumerStatefulWidget {
  final String userId;

  const SharedWantedCardsScreen({super.key, required this.userId});

  @override
  ConsumerState<SharedWantedCardsScreen> createState() =>
      _SharedWantedCardsScreenState();
}

class _SharedWantedCardsScreenState
    extends ConsumerState<SharedWantedCardsScreen> {
  static const double _cardSpacing = 12;
  static const double _contentMaxWidth = 1480;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedItemIds = {};
  String _query = '';
  late Future<List<WantedCardListing>> _wantedFuture;
  List<WantedCardListing> _cachedSourceItems = const [];
  List<WantedCardListing> _cachedVisibleItems = const [];
  String _cachedQuery = '';
  String _cachedSeekerName = '';
  int _cachedTotalCards = 0;

  @override
  void initState() {
    super.initState();
    _wantedFuture = _loadWantedCards();
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

  Future<List<WantedCardListing>> _loadWantedCards() {
    return ref
        .read(wantedCardsRepositoryProvider)
        .getPublicWantedCardsByUser(widget.userId);
  }

  void _updateVisibleItems(List<WantedCardListing> allItems) {
    final sourceChanged = !identical(_cachedSourceItems, allItems);
    final queryChanged = _cachedQuery != _query;

    if (!sourceChanged && !queryChanged) {
      return;
    }

    _cachedSourceItems = allItems;
    _cachedQuery = _query;
    _cachedSeekerName = allItems
        .map((item) => item.seekerName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    _cachedTotalCards = allItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    _cachedVisibleItems = allItems
        .where((item) {
          if (_query.isEmpty) return true;

          return item.name.toLowerCase().contains(_query) ||
              item.cardCode.toLowerCase().contains(_query) ||
              item.setName.toLowerCase().contains(_query);
        })
        .toList(growable: false);
  }

  String _buildPublicWantedLink() {
    final base = Uri.base;
    final origin = '${base.scheme}://${base.authority}';
    final usesHashRouting = base.hasFragment && base.fragment.startsWith('/');

    if (usesHashRouting) {
      return '$origin/#/shared/wanted/${widget.userId}';
    }

    return '$origin/shared/wanted/${widget.userId}';
  }

  Future<void> _copyWantedLink() async {
    final link = _buildPublicWantedLink();

    try {
      final action = await shareOrCopyText(
        link,
        subject: 'Cartas procuradas no OPTCG BH',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'shared'
                ? 'Link aberto para compartilhamento.'
                : 'Link copiado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Link das cartas procuradas'),
            content: SelectableText(link),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
    }
  }

  void _toggleSelection(WantedCardListing item) {
    setState(() {
      if (_selectedItemIds.contains(item.id)) {
        _selectedItemIds.remove(item.id);
      } else {
        _selectedItemIds.add(item.id);
      }
    });
  }

  String _buildOfferMessage(List<WantedCardListing> selectedItems) {
    final seekerName = selectedItems
        .map((item) => item.seekerName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    final lines = <String>[
      seekerName.isNotEmpty
          ? 'Oi $seekerName, eu tenho essas cartas:'
          : 'Oi, eu tenho essas cartas:',
      '',
    ];

    for (final item in selectedItems) {
      final notes = item.notes.trim().isNotEmpty
          ? ' - Observacao da busca: ${item.notes.trim()}'
          : '';
      lines.add('${item.quantity}x ${item.name} - ${item.cardCode}$notes');
    }

    return lines.join('\n');
  }

  Future<void> _sendOfferViaWhatsApp(
    List<WantedCardListing> selectedItems,
  ) async {
    if (selectedItems.isEmpty) return;

    final contactItem = selectedItems.firstWhere(
      (item) => item.hasWhatsAppContact,
      orElse: () => selectedItems.first,
    );

    if (!contactItem.hasWhatsAppContact) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta lista nao possui um WhatsApp configurado.'),
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://wa.me/${contactItem.normalizedWhatsAppNumber}?text=${Uri.encodeComponent(_buildOfferMessage(selectedItems))}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o WhatsApp.')),
      );
    }
  }

  double _gridMaxExtentFor(double width) {
    if (width >= 1400) return 280;
    if (width >= 1100) return 260;
    if (width >= 800) return 240;
    return 220;
  }

  double _gridAspectRatioFor(double width) {
    if (width >= 1400) return 0.54;
    if (width >= 1100) return 0.52;
    if (width >= 800) return 0.49;
    return 0.44;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<List<WantedCardListing>>(
        future: _wantedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar cartas procuradas:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allItems = snapshot.data ?? const <WantedCardListing>[];
          _updateVisibleItems(allItems);
          final seekerName = _cachedSeekerName;
          final items = _cachedVisibleItems;
          final totalCards = _cachedTotalCards;
          final selectedItems = allItems
              .where((item) => _selectedItemIds.contains(item.id))
              .toList(growable: false);
          final screenWidth = MediaQuery.sizeOf(context).width;
          final isCompactLayout = screenWidth < 760;

          return Column(
            children: [
              AppBar(
                title: Text(
                  seekerName.isNotEmpty
                      ? 'Procuradas por $seekerName'
                      : 'Cartas procuradas',
                ),
                actions: [
                  IconButton(
                    tooltip: 'Copiar link',
                    onPressed: _copyWantedLink,
                    icon: const Icon(Icons.link_outlined),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seekerName.isNotEmpty
                              ? 'Cartas que $seekerName esta procurando'
                              : 'Cartas procuradas',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selecione as cartas que voce tem e envie uma mensagem pelo WhatsApp.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SummaryStatCard(
                              label: 'Cartas unicas',
                              value:
                                  '${allItems.map((item) => item.cardCode).toSet().length}',
                              icon: Icons.style_outlined,
                              minWidth: 180,
                              surfaceAlpha: 0.92,
                            ),
                            SummaryStatCard(
                              label: 'Quantidade total',
                              value: '$totalCards',
                              icon: Icons.inventory_2_outlined,
                              minWidth: 180,
                              surfaceAlpha: 0.92,
                            ),
                            SummaryStatCard(
                              label: 'Selecionadas',
                              value: '${selectedItems.length}',
                              icon: Icons.check_circle_outline,
                              minWidth: 180,
                              surfaceAlpha: 0.92,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isCompactLayout) ...[
                          _SharedWantedSearchField(
                            controller: _searchController,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _copyWantedLink,
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copiar link'),
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _SharedWantedSearchField(
                                  controller: _searchController,
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _copyWantedLink,
                                icon: const Icon(Icons.copy_outlined),
                                label: const Text('Copiar link'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhuma carta procurada encontrada.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final contentWidth = constraints.maxWidth.clamp(
                            320.0,
                            _contentMaxWidth,
                          );
                          final horizontalInset =
                              constraints.maxWidth > _contentMaxWidth
                              ? (constraints.maxWidth - _contentMaxWidth) / 2
                              : 12.0;

                          return GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                              horizontalInset,
                              12,
                              horizontalInset,
                              18,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: _gridMaxExtentFor(
                                    contentWidth,
                                  ),
                                  crossAxisSpacing: _cardSpacing,
                                  mainAxisSpacing: _cardSpacing,
                                  childAspectRatio: _gridAspectRatioFor(
                                    contentWidth,
                                  ),
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final selected = _selectedItemIds.contains(
                                item.id,
                              );

                              return CatalogGridCard(
                                key: ValueKey(
                                  'shared-wanted-card-${item.id}-${item.cardCode}-${item.imageUrl}',
                                ),
                                code: item.cardCode,
                                title: item.name,
                                metadata: [
                                  'Procura: ${item.quantity}x',
                                  if (item.setName.trim().isNotEmpty)
                                    item.setName,
                                  item.statusLabel,
                                ],
                                maxMetadataItems: 3,
                                image: _SharedWantedCardImage(
                                  imageUrl: item.imageUrl,
                                  cardCode: item.cardCode,
                                ),
                                footer: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (item.hasNotes)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          item.notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _toggleSelection(item),
                                      icon: Icon(
                                        selected
                                            ? Icons.check_circle
                                            : Icons.add_circle_outline,
                                      ),
                                      label: Text(
                                        selected ? 'Selecionada' : 'Eu tenho',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<WantedCardListing>>(
        future: _wantedFuture,
        builder: (context, snapshot) {
          final allItems = snapshot.data ?? const <WantedCardListing>[];
          final selectedItems = allItems
              .where((item) => _selectedItemIds.contains(item.id))
              .toList(growable: false);

          if (selectedItems.isEmpty) {
            return const SizedBox.shrink();
          }

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.98),
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selectedItems.length} carta(s) selecionada(s)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _sendOfferViaWhatsApp(selectedItems),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Enviar WhatsApp'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SharedWantedSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SharedWantedSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Buscar por nome, codigo ou set',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surface.withValues(alpha: 0.9),
      ),
    );
  }
}

class _SharedWantedCardImage extends StatelessWidget {
  final String imageUrl;
  final String cardCode;

  const _SharedWantedCardImage({
    required this.imageUrl,
    required this.cardCode,
  });

  @override
  Widget build(BuildContext context) {
    final directUrl = imageUrl.trim();

    if (directUrl.isEmpty) {
      return Center(
        child: Text(
          cardCode,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }

    return Image.network(
      directUrl,
      fit: BoxFit.contain,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, _, _) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined),
              const SizedBox(height: 8),
              Text(cardCode),
            ],
          ),
        );
      },
    );
  }
}
