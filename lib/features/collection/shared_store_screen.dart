import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/share_link_helper.dart';
import '../../data/models/marketplace_listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/op_api_service.dart';
import '../../core/widgets/home_navigation_button.dart';

class SharedStoreScreen extends ConsumerStatefulWidget {
  final String userId;

  const SharedStoreScreen({super.key, required this.userId});

  @override
  ConsumerState<SharedStoreScreen> createState() => _SharedStoreScreenState();
}

class _SharedStoreScreenState extends ConsumerState<SharedStoreScreen> {
  static const double _cardMaxWidth = 210;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.48;

  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _cartQuantities = {};
  String _query = '';

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
    final lines = <String>[
      'Oi, eu gostaria de reservar essas cartas:',
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

      lines.add(
        '${quantity}x ${item.name} - ${item.formattedPrice}$extras',
      );
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

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o WhatsApp.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(marketplaceRepositoryProvider);
    final theme = Theme.of(context);
    final listingsFuture = repo.getPublicListingsByUser(widget.userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace • Cartas à venda'),
        actions: [
          IconButton(
            tooltip: 'Copiar link',
            onPressed: _copyStoreLink,
            icon: const Icon(Icons.link_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<MarketplaceListing>>(
        future: listingsFuture,
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

          final allItems = snapshot.data ?? [];
          final items = allItems.where((item) {
            if (_query.isEmpty) return true;

            return item.name.toLowerCase().contains(_query) ||
                item.cardCode.toLowerCase().contains(_query) ||
                item.setName.toLowerCase().contains(_query);
          }).toList();

          final totalCards = allItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final selectedItems = allItems
              .where((item) => (_cartQuantities[item.id] ?? 0) > 0)
              .toList(growable: false);
          final selectedCount = selectedItems.fold<int>(
            0,
            (sum, item) => sum + _selectedQuantityFor(item),
          );
          final selectedTotal = selectedItems.fold<int>(
            0,
            (sum, item) =>
                sum + ((_selectedQuantityFor(item)) * (item.priceInCents ?? 0)),
          );

          return Column(
            children: [
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vitrine pública',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Veja todas as cartas disponíveis para venda deste usuário.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MarketStatCard(
                          title: 'Cartas únicas',
                          value:
                              '${allItems.map((item) => item.cardCode).toSet().length}',
                          icon: Icons.style_outlined,
                        ),
                        _MarketStatCard(
                          title: 'Quantidade total',
                          value: '$totalCards',
                          icon: Icons.inventory_2_outlined,
                        ),
                        _MarketStatCard(
                          title: 'Carrinho',
                          value: '$selectedCount',
                          icon: Icons.shopping_cart_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por nome, código ou set',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      onPressed: () => _searchController.clear(),
                                      icon: const Icon(Icons.close),
                                    )
                                  : null,
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(
                                0.9,
                              ),
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
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: _cardMaxWidth,
                              crossAxisSpacing: _cardSpacing,
                              mainAxisSpacing: _cardSpacing,
                              childAspectRatio: _gridAspectRatio,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];

                          return Card(
                            key: ValueKey(
                              'shared-store-card-${item.id}-${item.cardCode}',
                            ),
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
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: _SharedStoreZoomableCardImage(
                                        key: ValueKey(
                                          'shared-store-image-${item.id}-${item.cardCode}-${item.imageUrl}',
                                        ),
                                        imageUrl: item.imageUrl,
                                        cardCode: item.cardCode,
                                        title: item.name,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
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
                                      const SizedBox(height: 6),
                                      Text(
                                        item.statusLabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.conditionLabel,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.formattedPrice,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (item.setName.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          item.setName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                      if (item.hasContactInfo) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.contactInfo,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Copiar contato',
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: item.contactInfo,
                                                  ),
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Contato copiado.',
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.copy_outlined,
                                              ),
                                            ),
                                            if (item.hasWhatsAppContact)
                                              IconButton(
                                                tooltip: 'Abrir WhatsApp',
                                                onPressed: () async {
                                                  final uri = Uri.parse(
                                                    item.whatsappUrl,
                                                  );
                                                  final launched =
                                                      await launchUrl(
                                                    uri,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                  if (!launched &&
                                                      context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Não foi possível abrir o WhatsApp.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.open_in_new,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                      if (item.hasNotes) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          item.notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'Remover',
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
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Adicionar',
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<MarketplaceListing>>(
        future: listingsFuture,
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
                color: theme.colorScheme.surface.withOpacity(0.98),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
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

class _MarketStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MarketStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.92),
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
              Text(title),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharedStoreResolvedCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final BoxFit fit;
  final double? height;

  const _SharedStoreResolvedCardImage({
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
        key: ValueKey('shared-direct-image-$cardCode-$directUrl'),
        height: height,
        fit: fit,
        gaplessPlayback: false,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) {
          return _SharedStoreResolvedCardImageFromApi(
            key: ValueKey('shared-fallback-api-$cardCode'),
            cardCode: cardCode,
            fit: fit,
            height: height,
          );
        },
      );
    }

    return _SharedStoreResolvedCardImageFromApi(
      key: ValueKey('shared-api-image-$cardCode'),
      cardCode: cardCode,
      fit: fit,
      height: height,
    );
  }
}

class _SharedStoreResolvedCardImageFromApi extends ConsumerWidget {
  final String cardCode;
  final BoxFit fit;
  final double? height;

  const _SharedStoreResolvedCardImageFromApi({
    super.key,
    required this.cardCode,
    required this.fit,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      key: ValueKey('shared-future-image-$cardCode'),
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
          key: ValueKey('shared-resolved-image-$cardCode-$resolvedUrl'),
          height: height,
          fit: fit,
          gaplessPlayback: false,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, __, ___) {
            return SizedBox(
              height: height,
              child: Container(
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
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
  final double? height;

  const _SharedStoreZoomableCardImage({
    super.key,
    required this.imageUrl,
    required this.cardCode,
    required this.title,
    this.fit = BoxFit.contain,
    this.height,
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
          height: height,
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
            height: height,
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
                  barrierColor: Colors.black.withOpacity(0.92),
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
                  errorBuilder: (_, __, ___) {
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
