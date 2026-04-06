import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/collection_types.dart';
import '../../core/providers/collection_view_mode_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../data/models/card_record.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/services/op_api_service.dart';
import '../../data/services/translation_service.dart';
import '../collection/collection_controller.dart';
import '../collection/manual_add_dialog.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isSharingBusy = false;

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

  String _buildPublicStoreLink(String userId) {
    final base = Uri.base;
    final origin = '${base.scheme}://${base.authority}';
    final usesHashRouting = base.hasFragment && base.fragment.startsWith('/');

    if (usesHashRouting) {
      return '$origin/#/shared/store/$userId';
    }

    return '$origin/shared/store/$userId';
  }

  Future<void> _copyStoreLink() async {
    setState(() {
      _isSharingBusy = true;
    });

    try {
      final repo = ref.read(collectionRepositoryProvider);
      await repo.enablePublicStoreSharingForUser();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final link = _buildPublicStoreLink(user.id);

      await Clipboard.setData(ClipboardData(text: link));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link da vitrine copiado:\n$link'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao copiar link: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingBusy = false;
        });
      }
    }
  }

  Future<void> _disableStoreLink() async {
    setState(() {
      _isSharingBusy = true;
    });

    try {
      await ref.read(collectionRepositoryProvider).disableSaleSharingForUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vitrine pública desativada.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao desativar vitrine: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(collectionControllerProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final viewMode = ref.watch(collectionViewModeProvider);

    final saleItems = allItems.where((card) {
      return card.collectionType == CollectionTypes.forSale;
    }).toList();

    final filteredItems = saleItems.where((card) {
      if (_query.isEmpty) return true;

      return card.name.toLowerCase().contains(_query) ||
          card.cardCode.toLowerCase().contains(_query) ||
          card.setName.toLowerCase().contains(_query);
    }).toList();

    final totalUnique = filteredItems.map((e) => e.cardCode).toSet().length;
    final totalCards = filteredItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartas à venda'),
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
          _SalesHeaderSection(
            totalUnique: totalUnique,
            totalCards: totalCards,
            searchController: _searchController,
            viewMode: viewMode,
            isSharingBusy: _isSharingBusy,
            onViewModeChanged: (mode) {
              ref.read(collectionViewModeProvider.notifier).setMode(mode);
            },
            onCopyLink: _copyStoreLink,
            onDisableLink: _disableStoreLink,
          ),
          Expanded(
            child: _SalesLibraryView(
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
}

class _SalesHeaderSection extends StatelessWidget {
  final int totalUnique;
  final int totalCards;
  final TextEditingController searchController;
  final CollectionViewMode viewMode;
  final ValueChanged<CollectionViewMode> onViewModeChanged;
  final VoidCallback onCopyLink;
  final VoidCallback onDisableLink;
  final bool isSharingBusy;

  const _SalesHeaderSection({
    required this.totalUnique,
    required this.totalCards,
    required this.searchController,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onCopyLink,
    required this.onDisableLink,
    required this.isSharingBusy,
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SalesStatCard(
                      label: 'Cartas únicas',
                      value: '$totalUnique',
                      icon: Icons.style_outlined,
                    ),
                    _SalesStatCard(
                      label: 'Total geral',
                      value: '$totalCards',
                      icon: Icons.format_list_numbered,
                    ),
                  ],
                ),
              ),
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
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, código ou set',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () => searchController.clear(),
                            icon: const Icon(Icons.close),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isSharingBusy ? null : onCopyLink,
                icon: isSharingBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.copy_outlined),
                label: const Text('Copiar link'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: isSharingBusy ? null : onDisableLink,
                icon: const Icon(Icons.link_off),
                label: const Text('Desativar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SalesStatCard({
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
        mainAxisSize: MainAxisSize.min,
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

class _SalesLibraryView extends ConsumerWidget {
  final List<CardRecord> items;
  final CollectionViewMode viewMode;

  const _SalesLibraryView({
    super.key,
    required this.items,
    required this.viewMode,
  });

  static const double _cardMaxWidth = 210;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _SalesEmptyState(
        title: 'Nenhuma carta à venda encontrada.',
        subtitle: 'Adicione cartas na biblioteca de vendas para visualizar aqui.',
      );
    }

    final itemsSignature = items
        .map((item) => '${item.id}-${item.cardCode}-${item.imageUrl}')
        .join('|');

    if (viewMode == CollectionViewMode.list) {
      return ListView.separated(
        key: ValueKey('sales-list-$itemsSignature'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];

          return Card(
            key: ValueKey('sales-list-card-${item.id}-${item.cardCode}'),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => _SalesCardDetailsDialog(
                    card: item,
                    sourceRecords: [item],
                  ),
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
                        child: _SalesResolvedCardImage(
                          key: ValueKey(
                            'sales-list-image-${item.id}-${item.cardCode}-${item.imageUrl}',
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
                          Text('Set: ${item.setName.isEmpty ? '-' : item.setName}'),
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
      key: ValueKey('sales-grid-$itemsSignature'),
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

        return InkWell(
          key: ValueKey('sales-grid-card-${item.id}-${item.cardCode}'),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => _SalesCardDetailsDialog(
                card: item,
                sourceRecords: [item],
              ),
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
                      child: _SalesResolvedCardImage(
                        key: ValueKey(
                          'sales-grid-image-${item.id}-${item.cardCode}-${item.imageUrl}',
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
        );
      },
    );
  }
}

class _SalesResolvedCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final BoxFit fit;
  final double? height;

  const _SalesResolvedCardImage({
    super.key,
    required this.imageUrl,
    required this.cardCode,
    this.fit = BoxFit.contain,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directUrl = imageUrl.trim();

    if (directUrl.isNotEmpty) {
      return Image.network(
        directUrl,
        key: ValueKey('sales-direct-image-$cardCode-$directUrl'),
        height: height,
        fit: fit,
        gaplessPlayback: false,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) {
          return _SalesResolvedCardImageFromApi(
            key: ValueKey('sales-fallback-api-$cardCode'),
            cardCode: cardCode,
            fit: fit,
            height: height,
          );
        },
      );
    }

    return _SalesResolvedCardImageFromApi(
      key: ValueKey('sales-api-image-$cardCode'),
      cardCode: cardCode,
      fit: fit,
      height: height,
    );
  }
}

class _SalesResolvedCardImageFromApi extends ConsumerWidget {
  final String cardCode;
  final BoxFit fit;
  final double? height;

  const _SalesResolvedCardImageFromApi({
    super.key,
    required this.cardCode,
    required this.fit,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      key: ValueKey('sales-future-image-$cardCode'),
      future: api.findCardByCode(cardCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final resolvedUrl = snapshot.data?.image.trim() ?? '';

        if (resolvedUrl.isEmpty) {
          return SizedBox(
            height: height,
            child: Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined),
              ),
            ),
          );
        }

        return Image.network(
          resolvedUrl,
          key: ValueKey('sales-resolved-image-$cardCode-$resolvedUrl'),
          height: height,
          fit: fit,
          gaplessPlayback: false,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, __, ___) {
            return SizedBox(
              height: height,
              child: Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SalesEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SalesEmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 60,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesCardDetailsDialog extends ConsumerStatefulWidget {
  final CardRecord card;
  final List<CardRecord> sourceRecords;

  const _SalesCardDetailsDialog({
    required this.card,
    required this.sourceRecords,
  });

  @override
  ConsumerState<_SalesCardDetailsDialog> createState() =>
      _SalesCardDetailsDialogState();
}

class _SalesCardDetailsDialogState
    extends ConsumerState<_SalesCardDetailsDialog> {
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
      final translated =
          await _translationService.translateToPortuguese(widget.card.text);

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

  Future<void> _changeQuantity(int delta) async {
    if (widget.sourceRecords.isEmpty) return;

    final base = widget.sourceRecords.first;
    final currentTotal =
        widget.sourceRecords.fold<int>(0, (sum, item) => sum + item.quantity);
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
        await ref.read(collectionControllerProvider.notifier).delete(
              widget.sourceRecords[i].id,
            );
      }
    }

    await ref.read(collectionControllerProvider.notifier).update(
          base.copyWith(quantity: newTotal),
        );

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
        constraints: const BoxConstraints(
          maxWidth: 560,
          maxHeight: 860,
        ),
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
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.cardCode,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _SalesResolvedCardImage(
                        imageUrl: card.imageUrl,
                        cardCode: card.cardCode,
                        height: 320,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Quantidade', '${card.quantity}x'),
                    _infoRow('Set', card.setName),
                    _infoRow('Raridade', card.rarity),
                    _infoRow('Cor', card.color),
                    _infoRow('Tipo', card.type),
                    _infoRow('Atributo', card.attribute),
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