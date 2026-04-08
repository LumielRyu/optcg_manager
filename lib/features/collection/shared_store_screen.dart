import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/share_link_helper.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/summary_stat_card.dart';
import '../../data/models/marketplace_listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/op_api_service.dart';

class SharedStoreScreen extends ConsumerStatefulWidget {
  final String userId;

  const SharedStoreScreen({super.key, required this.userId});

  @override
  ConsumerState<SharedStoreScreen> createState() => _SharedStoreScreenState();
}

class _SharedStoreScreenState extends ConsumerState<SharedStoreScreen> {
  static const double _cardSpacing = 12;
  static const double _contentMaxWidth = 1480;

  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _cartQuantities = {};
  String _query = '';
  late Future<List<MarketplaceListing>> _listingsFuture;
  List<MarketplaceListing> _cachedSourceItems = const [];
  List<MarketplaceListing> _cachedVisibleItems = const [];
  String _cachedQuery = '';
  String _cachedSellerName = '';
  int _cachedTotalCards = 0;

  @override
  void initState() {
    super.initState();
    _listingsFuture = _loadListings();
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

  Future<List<MarketplaceListing>> _loadListings() {
    return ref
        .read(marketplaceRepositoryProvider)
        .getPublicListingsByUser(widget.userId);
  }

  void _updateVisibleItems(List<MarketplaceListing> allItems) {
    final sourceChanged = !identical(_cachedSourceItems, allItems);
    final queryChanged = _cachedQuery != _query;

    if (!sourceChanged && !queryChanged) {
      return;
    }

    _cachedSourceItems = allItems;
    _cachedQuery = _query;
    _cachedSellerName = allItems
        .map((item) => item.sellerName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    _cachedTotalCards = allItems.fold<int>(0, (sum, item) => sum + item.quantity);
    _cachedVisibleItems = allItems.where((item) {
      if (_query.isEmpty) return true;

      return item.name.toLowerCase().contains(_query) ||
          item.cardCode.toLowerCase().contains(_query) ||
          item.setName.toLowerCase().contains(_query);
    }).toList(growable: false);
  }

  String _buildPublicStoreLink() {
    final base = Uri.base;
    final origin = '${base.scheme}://${base.authority}';
    final usesHashRouting = base.hasFragment && base.fragment.startsWith('/');

    if (usesHashRouting) {
      return '$origin/#/shared/store/${widget.userId}';
    }

    return '$origin/shared/store/${widget.userId}';
  }

  Future<void> _showShareLinkDialog(String link) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Link da vitrine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Não foi possível copiar automaticamente neste navegador. Use o link abaixo:',
              ),
              const SizedBox(height: 12),
              SelectableText(link),
            ],
          ),
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

  Future<void> _copyStoreLink() async {
    final link = _buildPublicStoreLink();

    try {
      final action = await shareOrCopyText(
        link,
        subject: 'Vitrine do OPTCG Manager',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'shared'
                ? 'Link da vitrine aberto para compartilhamento.'
                : 'Link da vitrine copiado.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _showShareLinkDialog(link);
    }
  }

  void _setCartQuantity(MarketplaceListing item, int quantity) {
    final safeQuantity = quantity.clamp(0, item.quantity);
    setState(() {
      if (safeQuantity <= 0) {
        _cartQuantities.remove(item.id);
      } else {
        _cartQuantities[item.id] = safeQuantity;
      }
    });
  }

  int _selectedQuantityFor(MarketplaceListing item) {
    return _cartQuantities[item.id] ?? 0;
  }

  double _gridMaxExtentFor(double width) {
    if (width >= 1400) return 280;
    if (width >= 1100) return 260;
    if (width >= 800) return 240;
    return 220;
  }

  double _gridAspectRatioFor(double width) {
    if (width >= 1400) return 0.5;
    if (width >= 1100) return 0.48;
    if (width >= 800) return 0.46;
    return 0.42;
  }

  String _formatCents(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    final whole = reais.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < whole.length; i++) {
      final indexFromEnd = whole.length - i;
      buffer.write(whole[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$centavos';
  }

  String _buildInterestMessage(List<MarketplaceListing> selectedItems) {
    final sellerName = selectedItems
        .map((item) => item.sellerName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    final lines = <String>[
      sellerName.isNotEmpty
          ? 'Oi $sellerName, eu gostaria de reservar essas cartas:'
          : 'Oi, eu gostaria de reservar essas cartas:',
      '',
    ];

    var totalCards = 0;
    var totalPrice = 0;

    for (final item in selectedItems) {
      final quantity = _selectedQuantityFor(item);
      if (quantity <= 0) continue;

      totalCards += quantity;
      totalPrice += (item.priceInCents ?? 0) * quantity;

      final extras = item.notes.trim().isNotEmpty
          ? ' - Extra: ${item.notes.trim()}'
          : '';

      lines.add('${quantity}x ${item.name} - ${item.formattedPrice}$extras');
    }

    lines.add('');
    lines.add('Total: ${_formatCents(totalPrice)}');
    lines.add('Total de cards: $totalCards');

    return lines.join('\n');
  }

  Future<void> _sendInterestViaWhatsApp(
    List<MarketplaceListing> selectedItems,
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
          content: Text('Esta vitrine não possui um WhatsApp configurado.'),
        ),
      );
      return;
    }

    final message = _buildInterestMessage(selectedItems);
    final uri = Uri.parse(
      'https://wa.me/${contactItem.normalizedWhatsAppNumber}?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<List<MarketplaceListing>>(
        future: _listingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar a vitrine:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allItems = snapshot.data ?? const <MarketplaceListing>[];
          _updateVisibleItems(allItems);
          final sellerName = _cachedSellerName;
          final items = _cachedVisibleItems;
          final totalCards = _cachedTotalCards;
          final selectedItems = allItems
              .where((item) => (_cartQuantities[item.id] ?? 0) > 0)
              .toList(growable: false);
          final selectedCount = selectedItems.fold<int>(
            0,
            (sum, item) => sum + _selectedQuantityFor(item),
          );
          final screenWidth = MediaQuery.sizeOf(context).width;
          final isCompactLayout = screenWidth < 760;

          return Column(
            children: [
              AppBar(
                title: Text(
                  sellerName.isNotEmpty
                      ? 'Vitrine de $sellerName'
                      : 'Marketplace • Cartas à venda',
                ),
                actions: [
                  IconButton(
                    tooltip: 'Copiar link',
                    onPressed: _copyStoreLink,
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
                          sellerName.isNotEmpty
                              ? 'Vitrine publica de $sellerName'
                              : 'Vitrine publica',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sellerName.isNotEmpty
                              ? 'Veja todas as cartas disponiveis para venda por $sellerName.'
                              : 'Veja todas as cartas disponiveis para venda deste usuario.',
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
                              label: 'Carrinho',
                              value: '$selectedCount',
                              icon: Icons.shopping_cart_outlined,
                              minWidth: 180,
                              surfaceAlpha: 0.92,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isCompactLayout) ...[
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por nome, codigo ou set',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      onPressed: () =>
                                          _searchController.clear(),
                                      icon: const Icon(Icons.close),
                                    )
                                  : null,
                              filled: true,
                              fillColor: theme.colorScheme.surface.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _copyStoreLink,
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copiar link'),
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar por nome, codigo ou set',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon:
                                        _searchController.text.isNotEmpty
                                        ? IconButton(
                                            onPressed: () =>
                                                _searchController.clear(),
                                            icon: const Icon(Icons.close),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: theme.colorScheme.surface
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _copyStoreLink,
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
                            'Nenhuma carta encontrada nesta vitrine.',
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

                              return CatalogGridCard(
                                key: ValueKey(
                                  'shared-store-card-${item.id}-${item.cardCode}-${item.imageUrl}',
                                ),
                                code: item.cardCode,
                                title: item.name,
                                metadata: [
                                  item.formattedPrice,
                                  '${item.statusLabel} - ${item.conditionLabel}',
                                  'Quantidade: ${item.quantity}x',
                                  if (item.setName.trim().isNotEmpty)
                                    item.setName,
                                ],
                                maxMetadataItems: 3,
                                image: _SharedStoreZoomableCardImage(
                                  key: ValueKey(
                                    'shared-store-image-${item.id}-${item.cardCode}-${item.imageUrl}',
                                  ),
                                  imageUrl: item.imageUrl,
                                  cardCode: item.cardCode,
                                  title: item.name,
                                  fit: BoxFit.contain,
                                ),
                                footer: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (item.hasWhatsAppContact)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton.filledTonal(
                                          tooltip: 'Abrir WhatsApp',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            final uri = Uri.parse(
                                              item.whatsappUrl,
                                            );
                                            final launched = await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                            if (!launched && context.mounted) {
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Nao foi possivel abrir o WhatsApp.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.chat_outlined),
                                        ),
                                      ),
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
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Remover',
                                          visualDensity: VisualDensity.compact,
                                          onPressed:
                                              _selectedQuantityFor(item) <= 0
                                              ? null
                                              : () => _setCartQuantity(
                                                  item,
                                                  _selectedQuantityFor(item) -
                                                      1,
                                                ),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            _selectedQuantityFor(item) <= 0
                                                ? 'Adicionar ao carrinho'
                                                : 'No carrinho: ${_selectedQuantityFor(item)}x',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Adicionar',
                                          visualDensity: VisualDensity.compact,
                                          onPressed:
                                              item.isActive &&
                                                  _selectedQuantityFor(item) <
                                                      item.quantity
                                              ? () => _setCartQuantity(
                                                  item,
                                                  _selectedQuantityFor(item) +
                                                      1,
                                                )
                                              : null,
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
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
      bottomNavigationBar: FutureBuilder<List<MarketplaceListing>>(
        future: _listingsFuture,
        builder: (context, snapshot) {
          final allItems = snapshot.data ?? const <MarketplaceListing>[];
          final selectedItems = allItems
              .where((item) => (_cartQuantities[item.id] ?? 0) > 0)
              .toList(growable: false);

          if (selectedItems.isEmpty) {
            return const SizedBox.shrink();
          }

          final selectedCount = selectedItems.fold<int>(
            0,
            (sum, item) => sum + _selectedQuantityFor(item),
          );
          final selectedTotal = selectedItems.fold<int>(
            0,
            (sum, item) =>
                sum + ((_selectedQuantityFor(item)) * (item.priceInCents ?? 0)),
          );

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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$selectedCount card(s) no carrinho',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text('Total: ${_formatCents(selectedTotal)}'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _sendInterestViaWhatsApp(selectedItems),
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const Text('Enviar interesse'),
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

class _SharedStoreResolvedCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final BoxFit fit;

  const _SharedStoreResolvedCardImage({
    required this.imageUrl,
    required this.cardCode,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directUrl = imageUrl.trim();

    if (directUrl.isNotEmpty) {
      return Image.network(
        directUrl,
        key: ValueKey('shared-direct-image-$cardCode-$directUrl'),
        fit: fit,
        gaplessPlayback: false,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) {
          return _SharedStoreResolvedCardImageFromApi(
            key: ValueKey('shared-fallback-api-$cardCode'),
            cardCode: cardCode,
            fit: fit,
          );
        },
      );
    }

    return _SharedStoreResolvedCardImageFromApi(
      key: ValueKey('shared-api-image-$cardCode'),
      cardCode: cardCode,
      fit: fit,
    );
  }
}

class _SharedStoreResolvedCardImageFromApi extends ConsumerWidget {
  final String cardCode;
  final BoxFit fit;

  const _SharedStoreResolvedCardImageFromApi({
    super.key,
    required this.cardCode,
    required this.fit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      key: ValueKey('shared-future-image-$cardCode'),
      future: api.findCardByCode(cardCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final resolvedUrl = snapshot.data?.image.trim() ?? '';

        if (resolvedUrl.isEmpty) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined),
            ),
          );
        }

        return Image.network(
          resolvedUrl,
          key: ValueKey('shared-resolved-image-$cardCode-$resolvedUrl'),
          fit: fit,
          gaplessPlayback: false,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, _, _) {
            return Container(
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        );
      },
    );
  }
}

class _SharedStoreZoomableCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final String title;
  final BoxFit fit;

  const _SharedStoreZoomableCardImage({
    super.key,
    required this.imageUrl,
    required this.cardCode,
    required this.title,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directUrl = imageUrl.trim();

    if (directUrl.isNotEmpty) {
      return _buildTapWrapper(
        context,
        _SharedStoreResolvedCardImage(
          imageUrl: directUrl,
          cardCode: cardCode,
          fit: fit,
        ),
        directUrl,
      );
    }

    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      future: api.findCardByCode(cardCode),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data?.image.trim() ?? '';

        return _buildTapWrapper(
          context,
          _SharedStoreResolvedCardImage(
            imageUrl: imageUrl,
            cardCode: cardCode,
            fit: fit,
          ),
          resolvedUrl,
        );
      },
    );
  }

  Widget _buildTapWrapper(
    BuildContext context,
    Widget child,
    String resolvedUrl,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: resolvedUrl.trim().isEmpty
            ? null
            : () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.92),
                  builder: (_) => _SharedStoreCardImageFullscreenDialog(
                    imageUrl: resolvedUrl,
                    title: title,
                    cardCode: cardCode,
                  ),
                );
              },
        child: child,
      ),
    );
  }
}

class _SharedStoreCardImageFullscreenDialog extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String cardCode;

  const _SharedStoreCardImageFullscreenDialog({
    required this.imageUrl,
    required this.title,
    required this.cardCode,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              panEnabled: true,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, _, _) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 56,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cardCode,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
