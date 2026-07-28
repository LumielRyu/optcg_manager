import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../core/services/app_error_reporter.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/widgets/accessible_action_surface.dart';
import '../../core/widgets/async_load_error_view.dart';
import '../../core/widgets/catalog_dropdown_field.dart';
import '../../core/widgets/catalog_search_field.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/app_page_shell.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/marketplace_listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/services/liga_one_piece_service.dart';

class GlobalMarketplaceScreen extends ConsumerStatefulWidget {
  const GlobalMarketplaceScreen({super.key});

  @override
  ConsumerState<GlobalMarketplaceScreen> createState() =>
      _GlobalMarketplaceScreenState();
}

class _GlobalMarketplaceScreenState
    extends ConsumerState<GlobalMarketplaceScreen> {
  static const double _cardMaxWidth = 220;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.50;
  static const int _pageSize = 60;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showOnlyPriced = false;
  bool _showOnlyActive = true;
  String _selectedColor = 'Todas';
  String _selectedType = 'Todos';
  String _selectedRarity = 'Todas';
  String _selectedSort = 'Mais recentes';
  int _visibleCount = _pageSize;
  final Map<String, int> _cartQuantities = {};
  final Map<String, String?> _ligaPriceLabels = {};
  final Set<String> _ligaPriceLoadingCodes = {};
  List<MarketplaceListing> _loadedPublicItems = const [];
  late Future<List<MarketplaceListing>> _publicListingsFuture;
  List<MarketplaceListing> _cachedSourceItems = const [];
  List<MarketplaceListing> _cachedFilteredItems = const [];
  List<String> _cachedColorOptions = const ['Todas'];
  List<String> _cachedTypeOptions = const ['Todos'];
  List<String> _cachedRarityOptions = const ['Todas'];
  String _cachedQuery = '';
  bool _cachedShowOnlyPriced = false;
  bool _cachedShowOnlyActive = true;
  String _cachedSelectedColor = 'Todas';
  String _cachedSelectedType = 'Todos';
  String _cachedSelectedRarity = 'Todas';
  String _cachedSelectedSort = 'Mais recentes';

  @override
  void initState() {
    super.initState();
    _publicListingsFuture = _loadPublicListings();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
        _visibleCount = _pageSize;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<MarketplaceListing>> _loadPublicListings() async {
    try {
      return await ref
          .read(marketplaceRepositoryProvider)
          .getGlobalPublicListings();
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'marketplace.load-public-listings',
      );
      throw _MarketplaceLoadException(referenceId);
    }
  }

  void _retryPublicListings() {
    setState(() {
      _visibleCount = _pageSize;
      _publicListingsFuture = _loadPublicListings();
    });
  }

  String _ligaPriceLabelFor(MarketplaceListing item) {
    final normalizedCode = item.cardCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return 'Liga: sem codigo';
    }
    final lookupCode = ref
        .read(ligaOnePieceServiceProvider)
        .lookupCodeForCard(cardName: item.name, cardCode: normalizedCode);

    if (_ligaPriceLabels.containsKey(lookupCode)) {
      return _ligaPriceLabels[lookupCode] ?? 'Liga: sem cache';
    }

    if (!_ligaPriceLabels.containsKey(lookupCode) &&
        _ligaPriceLoadingCodes.add(lookupCode)) {
      _loadLigaPriceLabel(item);
    }

    return 'Liga: consultando...';
  }

  Future<void> _loadLigaPriceLabel(MarketplaceListing item) async {
    final service = ref.read(ligaOnePieceServiceProvider);
    final lookupCode = service.lookupCodeForCard(
      cardName: item.name,
      cardCode: item.cardCode,
    );
    try {
      final snapshot = await service.fetchCachedPublicCardSnapshotForCard(
        cardName: item.name,
        cardCode: item.cardCode,
      );
      final price = snapshot?.minimumPrice ?? snapshot?.lowestListing?.price;
      final label = price == null || price <= 0
          ? null
          : 'Liga: ${_formatMarketplaceCurrency(price)}';

      if (!mounted) return;
      setState(() {
        _ligaPriceLabels[lookupCode] = label;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ligaPriceLabels[lookupCode] = null;
      });
    } finally {
      _ligaPriceLoadingCodes.remove(lookupCode);
    }
  }

  static String _formatMarketplaceCurrency(double value) {
    final cents = (value * 100).round();
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

  void _updateMarketplaceDerivedData(List<MarketplaceListing> allItems) {
    final sourceChanged = !identical(_cachedSourceItems, allItems);
    final filtersChanged =
        _cachedQuery != _query ||
        _cachedShowOnlyPriced != _showOnlyPriced ||
        _cachedShowOnlyActive != _showOnlyActive ||
        _cachedSelectedColor != _selectedColor ||
        _cachedSelectedType != _selectedType ||
        _cachedSelectedRarity != _selectedRarity ||
        _cachedSelectedSort != _selectedSort;

    if (sourceChanged) {
      _cachedSourceItems = allItems;
      _cachedColorOptions = _buildOptions(
        allItems.map((item) => item.color.trim()),
        defaultValue: 'Todas',
      );
      _cachedTypeOptions = _buildOptions(
        allItems.map((item) => item.type.trim()),
        defaultValue: 'Todos',
      );
      _cachedRarityOptions = _buildOptions(
        allItems.map((item) => item.rarity.trim()),
        defaultValue: 'Todas',
      );
    }

    if (!sourceChanged && !filtersChanged) {
      return;
    }

    _cachedQuery = _query;
    _cachedShowOnlyPriced = _showOnlyPriced;
    _cachedShowOnlyActive = _showOnlyActive;
    _cachedSelectedColor = _selectedColor;
    _cachedSelectedType = _selectedType;
    _cachedSelectedRarity = _selectedRarity;
    _cachedSelectedSort = _selectedSort;

    _cachedFilteredItems =
        allItems
            .where((item) {
              final matchesQuery =
                  _query.isEmpty ||
                  item.name.toLowerCase().contains(_query) ||
                  item.cardCode.toLowerCase().contains(_query) ||
                  item.setName.toLowerCase().contains(_query);
              final matchesPrice = !_showOnlyPriced || item.hasPrice;
              final matchesStatus = !_showOnlyActive || item.isActive;
              final matchesColor =
                  _selectedColor == 'Todas' || item.color == _selectedColor;
              final matchesType =
                  _selectedType == 'Todos' || item.type == _selectedType;
              final matchesRarity =
                  _selectedRarity == 'Todas' || item.rarity == _selectedRarity;

              return matchesQuery &&
                  matchesPrice &&
                  matchesStatus &&
                  matchesColor &&
                  matchesType &&
                  matchesRarity;
            })
            .toList(growable: false)
          ..sort(_compareListings);
  }

  List<String> _buildOptions(
    Iterable<String> values, {
    required String defaultValue,
  }) {
    final options = {
      ...values.where((value) => value.isNotEmpty),
    }.toList(growable: false)..sort();
    return <String>[defaultValue, ...options];
  }

  Future<void> _openWhatsApp(MarketplaceListing item) async {
    if (!requireSignedIn(context)) {
      return;
    }

    String contactInfo = item.contactInfo;
    if (!item.hasWhatsAppContact) {
      try {
        contactInfo = await ref
            .read(marketplaceRepositoryProvider)
            .getPublicListingContact(item.id);
      } catch (_) {
        contactInfo = '';
      }
    }
    final contactItem = item.copyWith(contactInfo: contactInfo);

    if (!contactItem.hasWhatsAppContact) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este an\u00FAncio n\u00E3o possui WhatsApp configurado.',
          ),
        ),
      );
      return;
    }

    final message = _buildInterestMessage(item);
    final uri = Uri.parse(
      'https://wa.me/${contactItem.normalizedWhatsAppNumber}?text=${Uri.encodeComponent(message)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'N\u00E3o foi poss\u00EDvel abrir o WhatsApp do vendedor.',
          ),
        ),
      );
    }
  }

  String _buildInterestMessage(MarketplaceListing item) {
    final greeting = item.hasSellerName
        ? 'Oi ${item.sellerName}, eu gostaria de reservar esta carta:'
        : 'Oi, eu gostaria de reservar esta carta:';
    final extras = item.notes.trim().isNotEmpty
        ? ' - Extra: ${item.notes.trim()}'
        : '';

    return [
      greeting,
      '',
      '1x ${item.name} - ${item.formattedPrice}$extras',
      '',
      'Total: ${item.formattedPrice}',
      'Total de cards: 1',
    ].join('\n');
  }

  int _selectedQuantityFor(MarketplaceListing item) {
    return _cartQuantities[item.id] ?? 0;
  }

  void _setCartQuantity(MarketplaceListing item, int quantity) {
    if (quantity > 0 && !requireSignedIn(context)) {
      return;
    }

    setState(() {
      if (quantity <= 0) {
        _cartQuantities.remove(item.id);
      } else {
        _cartQuantities[item.id] = quantity.clamp(1, item.quantity);
      }
    });
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

  String _buildSellerCartMessage(List<MarketplaceListing> sellerItems) {
    final sellerName = sellerItems
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

    for (final item in sellerItems) {
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

  Future<void> _openSellerCartWhatsApp(
    List<MarketplaceListing> sellerItems,
  ) async {
    if (!requireSignedIn(context)) {
      return;
    }

    if (sellerItems.isEmpty) return;
    var contactItem = sellerItems.firstWhere(
      (item) => item.hasWhatsAppContact,
      orElse: () => sellerItems.first,
    );

    if (!contactItem.hasWhatsAppContact) {
      var contactInfo = '';
      try {
        contactInfo = await ref
            .read(marketplaceRepositoryProvider)
            .getPublicListingContact(contactItem.id);
      } catch (_) {}
      contactItem = contactItem.copyWith(contactInfo: contactInfo);
    }

    if (!contactItem.hasWhatsAppContact) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este vendedor não possui WhatsApp configurado.'),
        ),
      );
      return;
    }

    final message = _buildSellerCartMessage(sellerItems);
    final uri = Uri.parse(
      'https://wa.me/${contactItem.normalizedWhatsAppNumber}?text=${Uri.encodeComponent(message)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'N\u00E3o foi poss\u00EDvel abrir o WhatsApp do vendedor.',
          ),
        ),
      );
    }
  }

  void _showCartSheet(List<MarketplaceListing> allItems) {
    if (!requireSignedIn(context)) {
      return;
    }

    final selectedItems = allItems
        .where((item) => _selectedQuantityFor(item) > 0)
        .toList(growable: false);

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seu carrinho esta vazio.')));
      return;
    }

    final grouped = <String, List<MarketplaceListing>>{};
    for (final item in selectedItems) {
      grouped.putIfAbsent(item.ownerUserId, () => []).add(item);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int totalCards = 0;
            for (final item in selectedItems) {
              totalCards += _selectedQuantityFor(item);
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carrinho do Marketplace',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Total de cards: $totalCards'),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: grouped.entries
                          .map((entry) {
                            final sellerItems = entry.value;
                            final sellerName =
                                sellerItems.first.sellerName.trim().isEmpty
                                ? 'Vendedor'
                                : sellerItems.first.sellerName;
                            final sellerTotal = sellerItems.fold<int>(
                              0,
                              (sum, item) =>
                                  sum +
                                  ((item.priceInCents ?? 0) *
                                      _selectedQuantityFor(item)),
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sellerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    for (final item in sellerItems) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item.name} - ${item.formattedPrice}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              _setCartQuantity(
                                                item,
                                                _selectedQuantityFor(item) - 1,
                                              );
                                              setModalState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                          Text(
                                            '${_selectedQuantityFor(item)}x',
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              _setCartQuantity(
                                                item,
                                                _selectedQuantityFor(item) + 1,
                                              );
                                              setModalState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.notes.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Text(
                                            'Extra: ${item.notes.trim()}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text('Total: ${_formatCents(sellerTotal)}'),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: () =>
                                                _openSellerCartWhatsApp(
                                                  sellerItems
                                                      .where(
                                                        (item) =>
                                                            _selectedQuantityFor(
                                                              item,
                                                            ) >
                                                            0,
                                                      )
                                                      .toList(),
                                                ),
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text(
                                              'Enviar interesse',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openSellerStore(MarketplaceListing item) {
    if (item.ownerUserId.trim().isEmpty) return;
    context.push('/shared/store/${item.ownerUserId}');
  }

  int _compareListings(MarketplaceListing a, MarketplaceListing b) {
    switch (_selectedSort) {
      case 'Preco: menor':
        return (a.priceInCents ?? 1 << 30).compareTo(b.priceInCents ?? 1 << 30);
      case 'Preco: maior':
        return (b.priceInCents ?? -1).compareTo(a.priceInCents ?? -1);
      case 'Nome':
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'Codigo':
        return a.cardCode.toLowerCase().compareTo(b.cardCode.toLowerCase());
      default:
        return b.dateAddedUtc.compareTo(a.dateAddedUtc);
    }
  }

  void _loadMoreIfNeeded(int totalItems) {
    if (_visibleCount >= totalItems) return;
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, totalItems);
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _showOnlyPriced = false;
      _showOnlyActive = true;
      _selectedColor = 'Todas';
      _selectedType = 'Todos';
      _selectedRarity = 'Todas';
      _selectedSort = 'Mais recentes';
      _visibleCount = _pageSize;
    });
  }

  void _openItemDetails(MarketplaceListing item, String ligaPriceLabel) {
    showDialog<void>(
      context: context,
      builder: (_) => _GlobalMarketplaceCardDetailsDialog(
        card: item,
        ligaPriceLabel: ligaPriceLabel,
        onOpenWhatsApp: () => _openWhatsApp(item),
        onOpenSellerStore: item.ownerUserId.trim().isEmpty
            ? null
            : () => _openSellerStore(item),
        selectedQuantity: _selectedQuantityFor(item),
        onQuantityChanged: (quantity) {
          _setCartQuantity(item, quantity);
        },
      ),
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: _MarketplaceEditorialFilters(
          searchController: _searchController,
          showOnlyPriced: _showOnlyPriced,
          showOnlyActive: _showOnlyActive,
          selectedColor: _selectedColor,
          selectedType: _selectedType,
          selectedRarity: _selectedRarity,
          selectedSort: _selectedSort,
          colorOptions: _cachedColorOptions,
          typeOptions: _cachedTypeOptions,
          rarityOptions: _cachedRarityOptions,
          onToggleOnlyPriced: () {
            setState(() {
              _showOnlyPriced = !_showOnlyPriced;
              _visibleCount = _pageSize;
            });
          },
          onToggleOnlyActive: () {
            setState(() {
              _showOnlyActive = !_showOnlyActive;
              _visibleCount = _pageSize;
            });
          },
          onColorChanged: (value) {
            setState(() {
              _selectedColor = value;
              _visibleCount = _pageSize;
            });
          },
          onTypeChanged: (value) {
            setState(() {
              _selectedType = value;
              _visibleCount = _pageSize;
            });
          },
          onRarityChanged: (value) {
            setState(() {
              _selectedRarity = value;
              _visibleCount = _pageSize;
            });
          },
          onSortChanged: (value) {
            setState(() {
              _selectedSort = value;
              _visibleCount = _pageSize;
            });
          },
          onReset: _resetFilters,
        ),
      ),
    );
  }

  Widget _buildMarketplaceGrid(
    List<MarketplaceListing> visibleItems,
    int total,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 320) {
          _loadMoreIfNeeded(total);
        }
        return false;
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        key: ValueKey(
          'global-marketplace-$_query-$_showOnlyPriced-$_showOnlyActive-$_selectedColor-$_selectedType-$_selectedRarity-$_selectedSort-${visibleItems.length}',
        ),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _cardMaxWidth,
          crossAxisSpacing: _cardSpacing,
          mainAxisSpacing: _cardSpacing,
          childAspectRatio: _gridAspectRatio,
        ),
        itemCount: visibleItems.length + (visibleItems.length < total ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visibleItems.length) {
            return const _GlobalMarketplaceLoadMoreCard();
          }

          final item = visibleItems[index];
          final ligaPriceLabel = _ligaPriceLabelFor(item);

          return CatalogGridCard(
            key: ValueKey(
              'global-market-${item.id}-${item.cardCode}-${item.imageUrl}',
            ),
            code: item.cardCode,
            title: item.name,
            metadata: [
              if (item.hasSellerName) 'Vendedor: ${item.sellerName}',
              'Oferta: ${item.formattedPrice}',
              '${item.statusLabel} - ${item.conditionLabel}',
              'Quantidade: ${item.quantity}x',
            ],
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GlobalMarketplaceLigaPriceBadge(label: ligaPriceLabel),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Tooltip(
                        message: 'Abrir WhatsApp',
                        child: FilledButton(
                          onPressed: item.hasWhatsAppContact
                              ? () => _openWhatsApp(item)
                              : null,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.open_in_new, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: item.ownerUserId.trim().isEmpty
                            ? null
                            : () => _openSellerStore(item),
                        icon: const Icon(Icons.storefront_outlined, size: 16),
                        label: const Text('Vitrine'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            image: _GlobalMarketplaceCardImage(
              key: ValueKey('global-market-image-${item.id}-${item.imageUrl}'),
              imageUrl: item.imageUrl,
              cardCode: item.cardCode,
            ),
            onTap: () => _openItemDetails(item, ligaPriceLabel),
          );
        },
      ),
    );
  }

  Widget _buildEditorialMarketplace({
    required List<MarketplaceListing> filteredItems,
    required List<MarketplaceListing> visibleItems,
    required int totalListings,
    required int totalCards,
    required int totalWithPrice,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1040;
    final featured = filteredItems.isEmpty ? null : filteredItems.first;
    final spotlight = filteredItems.take(8).toList(growable: false);

    return AppPageShell(
      maxWidth: 1480,
      padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 16, wide ? 24 : 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MarketplaceEditorialHero(
            featured: featured,
            ligaPriceLabel: featured == null
                ? ''
                : _ligaPriceLabelFor(featured),
            totalListings: totalListings,
            totalCards: totalCards,
            totalWithPrice: totalWithPrice,
            onOpenFeatured: featured == null
                ? null
                : () =>
                      _openItemDetails(featured, _ligaPriceLabelFor(featured)),
            onOpenFilters: wide ? null : _showFiltersSheet,
          ),
          const SizedBox(height: 18),
          if (spotlight.isNotEmpty) ...[
            _MarketplaceSpotlightRail(
              items: spotlight,
              ligaLabelFor: _ligaPriceLabelFor,
              onOpen: _openItemDetails,
            ),
            const SizedBox(height: 18),
          ],
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: filteredItems.isEmpty
                      ? const _GlobalMarketplaceEmptyState()
                      : _buildMarketplaceGrid(
                          visibleItems,
                          filteredItems.length,
                        ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 290,
                  child: _MarketplaceEditorialFilters(
                    searchController: _searchController,
                    showOnlyPriced: _showOnlyPriced,
                    showOnlyActive: _showOnlyActive,
                    selectedColor: _selectedColor,
                    selectedType: _selectedType,
                    selectedRarity: _selectedRarity,
                    selectedSort: _selectedSort,
                    colorOptions: _cachedColorOptions,
                    typeOptions: _cachedTypeOptions,
                    rarityOptions: _cachedRarityOptions,
                    onToggleOnlyPriced: () {
                      setState(() {
                        _showOnlyPriced = !_showOnlyPriced;
                        _visibleCount = _pageSize;
                      });
                    },
                    onToggleOnlyActive: () {
                      setState(() {
                        _showOnlyActive = !_showOnlyActive;
                        _visibleCount = _pageSize;
                      });
                    },
                    onColorChanged: (value) {
                      setState(() {
                        _selectedColor = value;
                        _visibleCount = _pageSize;
                      });
                    },
                    onTypeChanged: (value) {
                      setState(() {
                        _selectedType = value;
                        _visibleCount = _pageSize;
                      });
                    },
                    onRarityChanged: (value) {
                      setState(() {
                        _selectedRarity = value;
                        _visibleCount = _pageSize;
                      });
                    },
                    onSortChanged: (value) {
                      setState(() {
                        _selectedSort = value;
                        _visibleCount = _pageSize;
                      });
                    },
                    onReset: _resetFilters,
                  ),
                ),
              ],
            )
          else
            filteredItems.isEmpty
                ? const _GlobalMarketplaceEmptyState()
                : _buildMarketplaceGrid(visibleItems, filteredItems.length),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final cartCount = _cartQuantities.values.fold<int>(
      0,
      (sum, qty) => sum + qty,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(),
        title: const Text('Marketplace Global'),
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
            tooltip: 'Carrinho',
            onPressed: () => _showCartSheet(_loadedPublicItems),
            icon: Badge.count(
              count: cartCount,
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<MarketplaceListing>>(
        future: _publicListingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _GlobalMarketplaceLoadingView();
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            return AsyncLoadErrorView(
              title: 'Não foi possível carregar o Marketplace',
              message:
                  'Verifique sua conexão e tente novamente. Se o problema '
                  'continuar, informe o código abaixo ao suporte.',
              referenceId: error is _MarketplaceLoadException
                  ? error.referenceId
                  : null,
              onRetry: _retryPublicListings,
            );
          }

          final allItems = (snapshot.data ?? const <MarketplaceListing>[])
              .where((item) => item.isPublic)
              .toList(growable: false);
          _loadedPublicItems = allItems;
          _updateMarketplaceDerivedData(allItems);

          final filteredItems = _cachedFilteredItems;

          final visibleItems = filteredItems
              .take(_visibleCount.clamp(0, filteredItems.length))
              .toList(growable: false);

          final totalCards = filteredItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final totalListings = filteredItems.length;
          final totalWithPrice = filteredItems
              .where((item) => item.hasPrice)
              .length;

          return _buildEditorialMarketplace(
            filteredItems: filteredItems,
            visibleItems: visibleItems,
            totalListings: totalListings,
            totalCards: totalCards,
            totalWithPrice: totalWithPrice,
          );
        },
      ),
      floatingActionButton: cartCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => _showCartSheet(_loadedPublicItems),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text('Carrinho ($cartCount)'),
            )
          : null,
    );
  }
}

class _MarketplaceLoadException implements Exception {
  final String referenceId;

  const _MarketplaceLoadException(this.referenceId);
}

class _GlobalMarketplaceLigaPriceBadge extends StatelessWidget {
  final String label;

  const _GlobalMarketplaceLigaPriceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrice = label.startsWith('Liga: R\$');
    final isLoading = label.contains('consultando');
    final color = isPrice
        ? Colors.green.shade700
        : isLoading
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final background = isPrice
        ? Colors.green.withValues(alpha: 0.12)
        : isLoading
        ? theme.colorScheme.primary.withValues(alpha: 0.10)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceEditorialHero extends StatelessWidget {
  final MarketplaceListing? featured;
  final String ligaPriceLabel;
  final int totalListings;
  final int totalCards;
  final int totalWithPrice;
  final VoidCallback? onOpenFeatured;
  final VoidCallback? onOpenFilters;

  const _MarketplaceEditorialHero({
    required this.featured,
    required this.ligaPriceLabel,
    required this.totalListings,
    required this.totalCards,
    required this.totalWithPrice,
    required this.onOpenFeatured,
    this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = featured;
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'TCG BH MARKETPLACE',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Encontre.\nCompare.\nConquiste.',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 0.98,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'As melhores cartas de One Piece TCG em Belo Horizonte e regiao, com preco da Liga e contato direto com vendedores.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MarketplaceHeroPill(
              icon: Icons.storefront_outlined,
              label: '$totalListings anuncios',
            ),
            _MarketplaceHeroPill(
              icon: Icons.style_outlined,
              label: '$totalCards cartas',
            ),
            _MarketplaceHeroPill(
              icon: Icons.sell_outlined,
              label: '$totalWithPrice com preco',
            ),
          ],
        ),
        if (onOpenFilters != null) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpenFilters,
            icon: const Icon(Icons.tune),
            label: const Text('Filtros'),
          ),
        ],
      ],
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      padding: EdgeInsets.all(wide ? 26 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.10),
            theme.colorScheme.surface.withValues(alpha: 0.08),
            theme.colorScheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/editorial/marketplace_hero.png',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.34),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: 0.92),
                    theme.colorScheme.surface.withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.18),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _MarketplaceStarfieldPainter(theme.colorScheme.primary),
            ),
          ),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: 24),
                if (card != null)
                  Flexible(
                    flex: 3,
                    child: _MarketplaceFeaturedCard(
                      item: card,
                      ligaPriceLabel: ligaPriceLabel,
                      onTap: onOpenFeatured,
                    ),
                  ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                if (card != null) ...[
                  const SizedBox(height: 22),
                  _MarketplaceFeaturedCard(
                    item: card,
                    ligaPriceLabel: ligaPriceLabel,
                    onTap: onOpenFeatured,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MarketplaceFeaturedCard extends StatelessWidget {
  final MarketplaceListing item;
  final String ligaPriceLabel;
  final VoidCallback? onTap;

  const _MarketplaceFeaturedCard({
    required this.item,
    required this.ligaPriceLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 230,
              child: _GlobalMarketplaceCardImage(
                imageUrl: item.imageUrl,
                cardCode: item.cardCode,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text('${item.cardCode} - ${item.formattedPrice}'),
            const SizedBox(height: 8),
            _GlobalMarketplaceLigaPriceBadge(label: ligaPriceLabel),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceSpotlightRail extends StatelessWidget {
  final List<MarketplaceListing> items;
  final String Function(MarketplaceListing item) ligaLabelFor;
  final void Function(MarketplaceListing item, String ligaPriceLabel) onOpen;

  const _MarketplaceSpotlightRail({
    required this.items,
    required this.ligaLabelFor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ofertas em destaque',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final liga = ligaLabelFor(item);
              return _MarketplaceSpotlightCard(
                item: item,
                ligaPriceLabel: liga,
                onTap: () => onOpen(item, liga),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarketplaceSpotlightCard extends StatelessWidget {
  final MarketplaceListing item;
  final String ligaPriceLabel;
  final VoidCallback onTap;

  const _MarketplaceSpotlightCard({
    required this.item,
    required this.ligaPriceLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 164,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _GlobalMarketplaceCardImage(
                  imageUrl: item.imageUrl,
                  cardCode: item.cardCode,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(item.formattedPrice, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceEditorialFilters extends StatelessWidget {
  final TextEditingController searchController;
  final bool showOnlyPriced;
  final bool showOnlyActive;
  final String selectedColor;
  final String selectedType;
  final String selectedRarity;
  final String selectedSort;
  final List<String> colorOptions;
  final List<String> typeOptions;
  final List<String> rarityOptions;
  final VoidCallback onToggleOnlyPriced;
  final VoidCallback onToggleOnlyActive;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onRarityChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onReset;

  const _MarketplaceEditorialFilters({
    required this.searchController,
    required this.showOnlyPriced,
    required this.showOnlyActive,
    required this.selectedColor,
    required this.selectedType,
    required this.selectedRarity,
    required this.selectedSort,
    required this.colorOptions,
    required this.typeOptions,
    required this.rarityOptions,
    required this.onToggleOnlyPriced,
    required this.onToggleOnlyActive,
    required this.onColorChanged,
    required this.onTypeChanged,
    required this.onRarityChanged,
    required this.onSortChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filtros',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onReset, child: const Text('Limpar')),
            ],
          ),
          const SizedBox(height: 10),
          CatalogSearchField(
            controller: searchController,
            hintText: 'Buscar no marketplace...',
          ),
          const SizedBox(height: 12),
          FilterChip(
            label: const Text('Somente ativas'),
            selected: showOnlyActive,
            onSelected: (_) => onToggleOnlyActive(),
          ),
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('Somente com preco'),
            selected: showOnlyPriced,
            onSelected: (_) => onToggleOnlyPriced(),
          ),
          const SizedBox(height: 12),
          CatalogDropdownField<String>(
            width: double.infinity,
            label: 'Cor',
            value: selectedColor,
            options: colorOptions,
            onChanged: (value) {
              if (value != null) onColorChanged(value);
            },
          ),
          const SizedBox(height: 10),
          CatalogDropdownField<String>(
            width: double.infinity,
            label: 'Tipo',
            value: selectedType,
            options: typeOptions,
            onChanged: (value) {
              if (value != null) onTypeChanged(value);
            },
          ),
          const SizedBox(height: 10),
          CatalogDropdownField<String>(
            width: double.infinity,
            label: 'Raridade',
            value: selectedRarity,
            options: rarityOptions,
            onChanged: (value) {
              if (value != null) onRarityChanged(value);
            },
          ),
          const SizedBox(height: 10),
          CatalogDropdownField<String>(
            width: double.infinity,
            label: 'Ordenar por',
            value: selectedSort,
            options: const [
              'Mais recentes',
              'Preco: menor',
              'Preco: maior',
              'Nome',
              'Codigo',
            ],
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _MarketplaceHeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MarketplaceHeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceStarfieldPainter extends CustomPainter {
  final Color color;

  const _MarketplaceStarfieldPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.16);
    for (var i = 0; i < 42; i++) {
      final x = (i * 73) % size.width;
      final y = (i * 41) % size.height;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.5 : 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlobalMarketplaceCardDetailsDialog extends StatefulWidget {
  final MarketplaceListing card;
  final String ligaPriceLabel;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback? onOpenSellerStore;
  final int selectedQuantity;
  final ValueChanged<int> onQuantityChanged;

  const _GlobalMarketplaceCardDetailsDialog({
    required this.card,
    required this.ligaPriceLabel,
    required this.onOpenWhatsApp,
    this.onOpenSellerStore,
    required this.selectedQuantity,
    required this.onQuantityChanged,
  });

  @override
  State<_GlobalMarketplaceCardDetailsDialog> createState() =>
      _GlobalMarketplaceCardDetailsDialogState();
}

class _GlobalMarketplaceCardDetailsDialogState
    extends State<_GlobalMarketplaceCardDetailsDialog> {
  late int _selectedQuantity;

  @override
  void initState() {
    super.initState();
    _selectedQuantity = widget.selectedQuantity;
  }

  void _updateQuantity(int nextQuantity) {
    final clamped = nextQuantity.clamp(0, widget.card.quantity);
    setState(() {
      _selectedQuantity = clamped;
    });
    widget.onQuantityChanged(clamped);
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
                      child: _GlobalMarketplaceZoomableCardImage(
                        imageUrl: card.imageUrl,
                        cardCode: card.cardCode,
                        title: card.name,
                        height: 320,
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
                    _globalInfoRow('Preço', card.formattedPrice),
                    _globalInfoRow('LigaOnePiece', widget.ligaPriceLabel),
                    if (card.hasSellerName)
                      _globalInfoRow('Vendedor', card.sellerName),
                    _globalInfoRow('Status', card.statusLabel),
                    _globalInfoRow('Condição', card.conditionLabel),
                    _globalInfoRow(
                      'Quantidade disponível',
                      '${card.quantity}x',
                    ),
                    _globalInfoRow('Set', card.setName),
                    _globalInfoRow('Raridade', card.rarity),
                    _globalInfoRow('Cor', card.color),
                    _globalInfoRow('Tipo', card.type),
                    _globalInfoRow('Atributo', card.attribute),
                    if (card.hasNotes)
                      _globalInfoRow('Observações', card.notes),
                    if (card.text.trim().isNotEmpty)
                      _globalInfoRow('Texto da carta', card.text),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Carrinho',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _selectedQuantity <= 0
                              ? null
                              : () => _updateQuantity(_selectedQuantity - 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${_selectedQuantity}x'),
                        IconButton(
                          onPressed: _selectedQuantity >= card.quantity
                              ? null
                              : () => _updateQuantity(_selectedQuantity + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onOpenWhatsApp,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  if (widget.onOpenSellerStore != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenSellerStore,
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Ver vitrine'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _globalInfoRow(String label, String value) {
  if (value.trim().isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class _GlobalMarketplaceZoomableCardImage extends StatelessWidget {
  final String imageUrl;
  final String cardCode;
  final String title;
  final double height;

  const _GlobalMarketplaceZoomableCardImage({
    required this.imageUrl,
    required this.cardCode,
    required this.title,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final directUrl = imageUrl.trim();
    void openImage() {
      showDialog<void>(
        context: context,
        builder: (_) => _GlobalMarketplaceCardImageFullscreenDialog(
          imageUrl: directUrl,
          title: title,
        ),
      );
    }

    return AccessibleActionSurface(
      label: directUrl.isEmpty
          ? 'Imagem indisponivel para $title'
          : 'Ampliar imagem de $title',
      hint: directUrl.isEmpty
          ? null
          : 'Abre a imagem da carta em tela cheia com controle de zoom',
      onTap: directUrl.isEmpty ? null : openImage,
      child: Container(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        height: height,
        child: directUrl.isEmpty
            ? const Center(child: Icon(Icons.image_not_supported_outlined))
            : Image.network(
                directUrl,
                semanticLabel: 'Carta $title',
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
              ),
      ),
    );
  }
}

class _GlobalMarketplaceCardImageFullscreenDialog extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _GlobalMarketplaceCardImageFullscreenDialog({
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 5,
              child: Image.network(
                imageUrl,
                semanticLabel: 'Imagem ampliada da carta $title',
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, _, _) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 54,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Fechar imagem ampliada',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalMarketplaceCardImage extends StatelessWidget {
  final String imageUrl;
  final String cardCode;

  const _GlobalMarketplaceCardImage({
    super.key,
    required this.imageUrl,
    required this.cardCode,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 46,
          color: Colors.white70,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, _, _) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 42,
              ),
              const SizedBox(height: 8),
              Text(
                cardCode,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlobalMarketplaceEmptyState extends StatelessWidget {
  const _GlobalMarketplaceEmptyState();

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
              'Nenhum anúncio encontrado.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tente ajustar a busca ou os filtros para encontrar mais cartas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobalMarketplaceLoadingView extends StatelessWidget {
  const _GlobalMarketplaceLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _GlobalMarketplaceSkeletonBox(height: 190, radius: 24),
        SizedBox(height: 16),
        _GlobalMarketplaceSkeletonBox(height: 220, radius: 20),
        SizedBox(height: 12),
        _GlobalMarketplaceSkeletonBox(height: 220, radius: 20),
      ],
    );
  }
}

class _GlobalMarketplaceLoadMoreCard extends StatelessWidget {
  const _GlobalMarketplaceLoadMoreCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Carregando mais anúncios...',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalMarketplaceSkeletonBox extends StatelessWidget {
  final double height;
  final double radius;

  const _GlobalMarketplaceSkeletonBox({
    required this.height,
    required this.radius,
  });

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
