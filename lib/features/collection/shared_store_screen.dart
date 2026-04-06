import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController _searchController = TextEditingController();
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

  Future<void> _copyStoreLink() async {
    final link = _buildPublicStoreLink();

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link da vitrine copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(marketplaceRepositoryProvider);
    final theme = Theme.of(context);

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
        future: repo.getPublicListingsByUser(widget.userId),
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
                                      onPressed: () =>
                                          _searchController.clear(),
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
                              maxCrossAxisExtent: 220,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.58,
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.35),
                                    padding: const EdgeInsets.all(8),
                                    child: _SharedStoreResolvedCardImage(
                                      key: ValueKey(
                                        'shared-store-image-${item.id}-${item.cardCode}-${item.imageUrl}',
                                      ),
                                      imageUrl: item.imageUrl,
                                      cardCode: item.cardCode,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    10,
                                    10,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (item.setName.trim().isNotEmpty)
                                        Text(
                                          item.setName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: item.isSold
                                                  ? Colors.grey.shade300
                                                  : item.isReserved
                                                      ? Colors.amber.shade100
                                                      : theme.colorScheme
                                                          .secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.statusLabel,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.conditionLabel,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Quantidade: ${item.quantity}x',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .tertiaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.formattedPrice,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                                                          'NÃ£o foi possÃ­vel abrir o WhatsApp.',
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
                                      if (item.hasNotes)
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
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
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
