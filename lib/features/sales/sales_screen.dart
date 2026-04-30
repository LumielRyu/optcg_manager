import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/collection_types.dart';
import '../../core/providers/collection_view_mode_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../core/widgets/catalog_search_field.dart';
import '../../core/widgets/dashboard_header_panel.dart';
import '../../core/widgets/store_share_actions.dart';
import '../../core/utils/share_link_helper.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/catalog_list_card.dart';
import '../../core/widgets/summary_stat_card.dart';
import '../../data/models/marketplace_listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/op_api_service.dart';
import '../../data/services/translation_service.dart';
import '../collection/manual_add_dialog.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../core/widgets/primary_bottom_navigation.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isSharingBusy = false;
  late Future<List<MarketplaceListing>> _listingsFuture;
  List<MarketplaceListing> _cachedSourceItems = const [];
  List<MarketplaceListing> _cachedFilteredItems = const [];
  String _cachedQuery = '';
  int _cachedTotalUnique = 0;
  int _cachedTotalCards = 0;
  int _cachedPricedItems = 0;

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
    return ref.read(marketplaceRepositoryProvider).getMyListings();
  }

  void _updateSalesDerivedData(List<MarketplaceListing> allItems) {
    final sourceChanged = !identical(_cachedSourceItems, allItems);
    final queryChanged = _cachedQuery != _query;

    if (!sourceChanged && !queryChanged) {
      return;
    }

    _cachedSourceItems = allItems;
    _cachedQuery = _query;
    _cachedFilteredItems = allItems.where((card) {
      if (_query.isEmpty) return true;

      return card.name.toLowerCase().contains(_query) ||
          card.cardCode.toLowerCase().contains(_query) ||
          card.setName.toLowerCase().contains(_query);
    }).toList(growable: false);
    _cachedTotalUnique = _cachedFilteredItems.map((e) => e.cardCode).toSet().length;
    _cachedTotalCards = _cachedFilteredItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    _cachedPricedItems = _cachedFilteredItems.where((item) => item.hasPrice).length;
  }

  void _reloadListings() {
    if (!mounted) return;
    setState(() {
      _listingsFuture = _loadListings();
    });
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
                'N\u00E3o foi poss\u00EDvel copiar automaticamente neste navegador. Use o link abaixo:',
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
    setState(() {
      _isSharingBusy = true;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      final repo = ref.read(marketplaceRepositoryProvider);
      await repo.enablePublicStoreSharingForUser();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Usu\u00E1rio n\u00E3o autenticado.');
      }

      final link = _buildPublicStoreLink(user.id);
      final action = await shareOrCopyText(
        link,
        subject: 'Vitrine do OPTCG Manager',
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            action == 'shared'
                ? 'Link da vitrine aberto para compartilhamento.'
                : 'Link da vitrine copiado:\n$link',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final user = Supabase.instance.client.auth.currentUser;
      final fallbackLink = user == null ? null : _buildPublicStoreLink(user.id);

      if (fallbackLink != null) {
        await _showShareLinkDialog(fallbackLink);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao copiar link: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharingBusy = false;
          _listingsFuture = _loadListings();
        });
      }
    }
  }

  Future<void> _disableStoreLink() async {
    setState(() {
      _isSharingBusy = true;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      await ref
          .read(marketplaceRepositoryProvider)
          .disablePublicStoreSharingForUser();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Vitrine p\u00FAblica desativada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao desativar vitrine: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSharingBusy = false;
          _listingsFuture = _loadListings();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final viewMode = ref.watch(collectionViewModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(),
        title: const Text('Cartas \u00E0 venda'),
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
            onPressed: () async {
              await context.push('/code-import?destination=forSale');
              _reloadListings();
            },
            icon: const Icon(Icons.content_paste_outlined),
          ),
          IconButton(
            tooltip: 'Adicionar carta',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => const ManualAddDialog(
                  initialDestination: CollectionTypes.forSale,
                ),
              );
              _reloadListings();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<MarketplaceListing>>(
        future: _listingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SalesLoadingView();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar vendas:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allItems = snapshot.data ?? const <MarketplaceListing>[];
          _updateSalesDerivedData(allItems);
          final filteredItems = _cachedFilteredItems;
          final totalUnique = _cachedTotalUnique;
          final totalCards = _cachedTotalCards;
          final pricedItems = _cachedPricedItems;

          return SingleChildScrollView(
            child: Column(
              children: [
                _SalesHeaderSection(
                  totalUnique: totalUnique,
                  totalCards: totalCards,
                  pricedItems: pricedItems,
                  searchController: _searchController,
                  viewMode: viewMode,
                  isSharingBusy: _isSharingBusy,
                  isCollapsed: false,
                  onViewModeChanged: (mode) {
                    ref.read(collectionViewModeProvider.notifier).setMode(mode);
                  },
                  onToggleCollapsed: () {},
                  onCopyLink: _copyStoreLink,
                  onDisableLink: _disableStoreLink,
                ),
                _SalesLibraryView(
                  items: filteredItems,
                  viewMode: viewMode,
                  onChanged: _reloadListings,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const ManualAddDialog(
              initialDestination: CollectionTypes.forSale,
            ),
          );
          _reloadListings();
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/sales',
      ),
    );
  }
}

class _SalesLoadingView extends StatelessWidget {
  const _SalesLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SalesSkeletonBox(height: 150, radius: 24),
        SizedBox(height: 16),
        _SalesSkeletonBox(height: 220, radius: 20),
        SizedBox(height: 12),
        _SalesSkeletonBox(height: 220, radius: 20),
      ],
    );
  }
}

class _SalesHeaderSection extends StatelessWidget {
  final int totalUnique;
  final int totalCards;
  final int pricedItems;
  final TextEditingController searchController;
  final CollectionViewMode viewMode;
  final ValueChanged<CollectionViewMode> onViewModeChanged;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onCopyLink;
  final VoidCallback onDisableLink;
  final bool isSharingBusy;

  const _SalesHeaderSection({
    required this.totalUnique,
    required this.totalCards,
    required this.pricedItems,
    required this.searchController,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onCopyLink,
    required this.onDisableLink,
    required this.isSharingBusy,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 760;
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
      stats: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SummaryStatCard(
                label: 'Cartas \u00FAnicas',
                value: '$totalUnique',
                icon: Icons.style_outlined,
              ),
              SummaryStatCard(
                label: 'Total geral',
                value: '$totalCards',
                icon: Icons.format_list_numbered,
              ),
              SummaryStatCard(
                label: 'Com pre\u00E7o',
                value: '$pricedItems',
                icon: Icons.sell_outlined,
              ),
              if (!isCompact) segmentedControl,
            ],
          ),
          if (isCompact) ...[
            const SizedBox(height: 12),
            Row(children: [Expanded(child: segmentedControl)]),
          ],
        ],
      ),
      search: isCompact
          ? Column(
              children: [
                CatalogSearchField(
                  controller: searchController,
                  hintText: 'Buscar por nome, c\u00F3digo ou set',
                ),
                const SizedBox(height: 10),
                StoreShareActions(
                  isBusy: isSharingBusy,
                  isCompact: true,
                  onCopyLink: onCopyLink,
                  onDisableLink: onDisableLink,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: CatalogSearchField(
                    controller: searchController,
                    hintText: 'Buscar por nome, c\u00F3digo ou set',
                  ),
                ),
                const SizedBox(width: 8),
                StoreShareActions(
                  isBusy: isSharingBusy,
                  isCompact: false,
                  onCopyLink: onCopyLink,
                  onDisableLink: onDisableLink,
                ),
              ],
            ),
    );
  }
}

class _SalesLibraryView extends ConsumerWidget {
  final List<MarketplaceListing> items;
  final CollectionViewMode viewMode;
  final VoidCallback onChanged;

  const _SalesLibraryView({
    required this.items,
    required this.viewMode,
    required this.onChanged,
  });

  static const double _cardMaxWidth = 220;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.53;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _SalesEmptyState(
        title: 'Nenhuma carta \u00E0 venda encontrada.',
        subtitle:
            'Adicione cartas na biblioteca de vendas para visualizar aqui.',
      );
    }

    final itemsSignature = items
        .map((item) => '${item.id}-${item.cardCode}-${item.imageUrl}')
        .join('|');

    if (viewMode == CollectionViewMode.list) {
      return ListView.separated(
        key: ValueKey('sales-list-$itemsSignature'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];

          return CatalogListCard(
            key: ValueKey('sales-list-card-${item.id}-${item.cardCode}'),
            title: item.name,
            code: item.cardCode,
            metadata: [
              if (item.hasSellerName) 'Vendedor: ${item.sellerName}',
              'Set: ${item.setName.isEmpty ? '-' : item.setName}',
              item.formattedPrice,
              'Status: ${item.statusLabel}',
              'Condição: ${item.conditionLabel}',
              'Quantidade: ${item.quantity}x',
              if (item.hasContactInfo) 'Contato configurado',
            ],
            image: _SalesResolvedCardImage(
              key: ValueKey(
                'sales-list-image-${item.id}-${item.cardCode}-${item.imageUrl}',
              ),
              imageUrl: item.imageUrl,
              cardCode: item.cardCode,
              fit: BoxFit.contain,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) =>
                    _SalesCardDetailsDialog(card: item, onChanged: onChanged),
              );
            },
          );
        },
      );
    }

    return GridView.builder(
      key: ValueKey('sales-grid-$itemsSignature'),
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

        return CatalogGridCard(
          key: ValueKey('sales-grid-card-${item.id}-${item.cardCode}'),
          code: item.cardCode,
          title: item.name,
          metadata: [
            if (item.hasSellerName) 'Vendedor: ${item.sellerName}',
            'Quantidade: ${item.quantity}x',
            item.statusLabel,
            item.conditionLabel,
            item.formattedPrice,
          ],
          footer: item.hasContactInfo
              ? const Text(
                  'Contato configurado',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                )
              : null,
          image: _SalesResolvedCardImage(
            key: ValueKey(
              'sales-grid-image-${item.id}-${item.cardCode}-${item.imageUrl}',
            ),
            imageUrl: item.imageUrl,
            cardCode: item.cardCode,
            fit: BoxFit.contain,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) =>
                  _SalesCardDetailsDialog(card: item, onChanged: onChanged),
            );
          },
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
        errorBuilder: (_, _, _) {
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
          errorBuilder: (_, _, _) {
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

class _SalesZoomableCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final String title;
  final BoxFit fit;
  final double? height;

  const _SalesZoomableCardImage({
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
        _SalesResolvedCardImage(
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
          _SalesResolvedCardImage(
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
                  barrierColor: Colors.black.withValues(alpha: 0.92),
                  builder: (_) => _SalesCardImageFullscreenDialog(
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

class _SalesCardImageFullscreenDialog extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String cardCode;

  const _SalesCardImageFullscreenDialog({
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

class _SalesEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SalesEmptyState({required this.title, required this.subtitle});

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
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SalesSkeletonBox extends StatelessWidget {
  final double height;
  final double radius;

  const _SalesSkeletonBox({required this.height, this.radius = 16});

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

class _SalesCardDetailsDialog extends ConsumerStatefulWidget {
  final MarketplaceListing card;
  final VoidCallback onChanged;

  const _SalesCardDetailsDialog({required this.card, required this.onChanged});

  @override
  ConsumerState<_SalesCardDetailsDialog> createState() =>
      _SalesCardDetailsDialogState();
}

class _SalesCardDetailsDialogState
    extends ConsumerState<_SalesCardDetailsDialog> {
  final TranslationService _translationService = TranslationService();
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  late String _saleStatus;
  late String _cardCondition;

  bool _isTranslating = false;
  bool _isSavingListing = false;
  String? _translatedText;
  bool _showTranslated = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.card.hasPrice
          ? (widget.card.priceInCents! / 100).toStringAsFixed(2)
          : '',
    );
    _notesController = TextEditingController(text: widget.card.notes);
    _saleStatus = widget.card.saleStatus;
    _cardCondition = widget.card.cardCondition;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
            'N\u00E3o foi poss\u00EDvel traduzir o texto da carta.';
        _showTranslated = true;
      });
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  Future<void> _changeQuantity(int delta) async {
    final newTotal = widget.card.quantity + delta;

    if (newTotal <= 0) {
      await ref
          .read(marketplaceRepositoryProvider)
          .deleteListing(widget.card.id);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    await ref
        .read(marketplaceRepositoryProvider)
        .updateQuantity(id: widget.card.id, quantity: newTotal);

    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _removeGroup() async {
    await ref.read(marketplaceRepositoryProvider).deleteListing(widget.card.id);

    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveListingDetails() async {
    setState(() {
      _isSavingListing = true;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      final normalizedPrice = _priceController.text.trim().replaceAll(',', '.');
      final parsedPrice = normalizedPrice.isEmpty
          ? null
          : (double.tryParse(normalizedPrice) ?? -1);

      if (parsedPrice != null && parsedPrice < 0) {
        throw Exception('Pre\u00E7o inv\u00E1lido.');
      }

      await ref
          .read(marketplaceRepositoryProvider)
          .updateListingDetails(
            id: widget.card.id,
            priceInCents: parsedPrice == null
                ? null
                : (parsedPrice * 100).round(),
            notes: _notesController.text,
            saleStatus: _saleStatus,
            cardCondition: _cardCondition,
          );

      widget.onChanged();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Dados do an\u00FAncio atualizados.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar an\u00FAncio: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingListing = false;
        });
      }
    }
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _SalesZoomableCardImage(
                        imageUrl: card.imageUrl,
                        cardCode: card.cardCode,
                        title: card.name,
                        height: 320,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toque na imagem para ampliar',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Quantidade', '${card.quantity}x'),
                    _infoRow('Preço', card.formattedPrice),
                    if (card.hasSellerName)
                      _infoRow('Vendedor', card.sellerName),
                    _infoRow('Status', card.statusLabel),
                    _infoRow('Set', card.setName),
                    _infoRow('Raridade', card.rarity),
                    _infoRow('Condição', card.conditionLabel),
                    _infoRow('Cor', card.color),
                    _infoRow('Tipo', card.type),
                    _infoRow('Atributo', card.attribute),
                    if (card.hasContactInfo)
                      _infoRow('WhatsApp do cadastro', card.contactInfo),
                    if (card.hasNotes)
                      _infoRow('Observações', card.notes),
                    if (card.hasWhatsAppContact) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final uri = Uri.parse(card.whatsappUrl);
                          final launched = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!launched && mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Não foi possível abrir o WhatsApp.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir no WhatsApp'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Dados do anúncio'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Preço (ex: 12.50)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        card.hasContactInfo
                            ? 'O WhatsApp deste anúncio vem automaticamente do seu cadastro: ${card.contactInfo}'
                            : 'Cadastre seu WhatsApp no perfil para que ele seja usado automaticamente nos anúncios.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _saleStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status do anúncio',
                      ),
                      items: MarketplaceListing.saleStatuses.map((status) {
                        final label = switch (status) {
                          'reserved' => 'Reservada',
                          'sold' => 'Vendida',
                          _ => 'Ativa',
                        };
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _saleStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _cardCondition,
                      decoration: const InputDecoration(
                        labelText: 'Condição da carta',
                      ),
                      items: MarketplaceListing.cardConditions.map((condition) {
                        final label = switch (condition) {
                          'near_mint' => 'Near Mint',
                          'lightly_played' => 'Light Play',
                          'played' => 'Played',
                          'damaged' => 'Damaged',
                          _ => 'Mint',
                        };
                        return DropdownMenuItem<String>(
                          value: condition,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _cardCondition = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observações do anúncio',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _isSavingListing ? null : _saveListingDetails,
                      icon: _isSavingListing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Salvar an\u00FAncio'),
                    ),
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
                            ? 'Sem tradu\u00E7\u00E3o dispon\u00EDvel.'
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
