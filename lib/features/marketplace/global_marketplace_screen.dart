import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/marketplace_listing.dart';
import '../../data/repositories/marketplace_repository.dart';

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
  static const double _gridAspectRatio = 0.53;
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
  List<MarketplaceListing> _loadedPublicItems = const [];

  @override
  void initState() {
    super.initState();
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

  Future<void> _openWhatsApp(MarketplaceListing item) async {
    if (!item.hasWhatsAppContact) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este anúncio não possui WhatsApp configurado.'),
        ),
      );
      return;
    }

    final message = _buildInterestMessage(item);
    final uri = Uri.parse(
      'https://wa.me/${item.normalizedWhatsAppNumber}?text=${Uri.encodeComponent(message)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o WhatsApp do vendedor.'),
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

  Future<void> _openSellerCartWhatsApp(List<MarketplaceListing> sellerItems) async {
    if (sellerItems.isEmpty) return;
    final contactItem = sellerItems.firstWhere(
      (item) => item.hasWhatsAppContact,
      orElse: () => sellerItems.first,
    );

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
          content: Text('Não foi possível abrir o WhatsApp do vendedor.'),
        ),
      );
    }
  }

  void _showCartSheet(List<MarketplaceListing> allItems) {
    final selectedItems = allItems
        .where((item) => _selectedQuantityFor(item) > 0)
        .toList(growable: false);

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seu carrinho está vazio.')),
      );
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
                      children: grouped.entries.map((entry) {
                        final sellerItems = entry.value;
                        final sellerName = sellerItems.first.sellerName.trim().isEmpty
                            ? 'Vendedor'
                            : sellerItems.first.sellerName;
                        final sellerTotal = sellerItems.fold<int>(
                          0,
                          (sum, item) =>
                              sum + ((item.priceInCents ?? 0) * _selectedQuantityFor(item)),
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
                                  style: const TextStyle(fontWeight: FontWeight.w800),
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
                                        icon: const Icon(Icons.remove_circle_outline),
                                      ),
                                      Text('${_selectedQuantityFor(item)}x'),
                                      IconButton(
                                        onPressed: () {
                                          _setCartQuantity(
                                            item,
                                            _selectedQuantityFor(item) + 1,
                                          );
                                          setModalState(() {});
                                        },
                                        icon: const Icon(Icons.add_circle_outline),
                                      ),
                                    ],
                                  ),
                                  if (item.notes.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'Extra: ${item.notes.trim()}',
                                        style: Theme.of(context).textTheme.bodySmall,
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
                                        onPressed: () => _openSellerCartWhatsApp(
                                          sellerItems.where((item) => _selectedQuantityFor(item) > 0).toList(),
                                        ),
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Enviar interesse'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(growable: false),
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
      case 'Preço: menor':
        return (a.priceInCents ?? 1 << 30).compareTo(b.priceInCents ?? 1 << 30);
      case 'Preço: maior':
        return (b.priceInCents ?? -1).compareTo(a.priceInCents ?? -1);
      case 'Nome':
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'Código':
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(marketplaceRepositoryProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final cartCount = _cartQuantities.values.fold<int>(0, (sum, qty) => sum + qty);

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
        future: repo.getGlobalPublicListings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _GlobalMarketplaceLoadingView();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar o marketplace global\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allItems = (snapshot.data ?? const <MarketplaceListing>[])
              .where((item) => item.isPublic)
              .toList(growable: false);
          _loadedPublicItems = allItems;

          final filteredItems = allItems.where((item) {
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
          }).toList(growable: false)
            ..sort(_compareListings);

          final visibleItems = filteredItems
              .take(_visibleCount.clamp(0, filteredItems.length))
              .toList(growable: false);

          final totalCards = filteredItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final totalListings = filteredItems.length;
          final totalWithPrice =
              filteredItems.where((item) => item.hasPrice).length;

          final colors = <String>[
            'Todas',
            ...{
              ...allItems
                  .map((item) => item.color.trim())
                  .where((value) => value.isNotEmpty),
            },
          ];
          final types = <String>[
            'Todos',
            ...{
              ...allItems
                  .map((item) => item.type.trim())
                  .where((value) => value.isNotEmpty),
            },
          ];
          final rarities = <String>[
            'Todas',
            ...{
              ...allItems
                  .map((item) => item.rarity.trim())
                  .where((value) => value.isNotEmpty),
            },
          ];

          return SingleChildScrollView(
            child: Column(
              children: [
                _GlobalMarketplaceHeader(
                  totalListings: totalListings,
                  totalCards: totalCards,
                  totalWithPrice: totalWithPrice,
                  searchController: _searchController,
                  isCollapsed: false,
                  showOnlyPriced: _showOnlyPriced,
                  showOnlyActive: _showOnlyActive,
                  selectedColor: _selectedColor,
                  selectedType: _selectedType,
                  selectedRarity: _selectedRarity,
                  selectedSort: _selectedSort,
                  colorOptions: colors,
                  typeOptions: types,
                  rarityOptions: rarities,
                  onToggleCollapsed: () {},
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
                ),
                filteredItems.isEmpty
                    ? const _GlobalMarketplaceEmptyState()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 320) {
                            _loadMoreIfNeeded(filteredItems.length);
                          }
                          return false;
                        },
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          key: ValueKey(
                            'global-marketplace-${_query}-${_showOnlyPriced}-${_showOnlyActive}-${_selectedColor}-${_selectedType}-${_selectedRarity}-${_selectedSort}-${visibleItems.length}',
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: _cardMaxWidth,
                                crossAxisSpacing: _cardSpacing,
                                mainAxisSpacing: _cardSpacing,
                                childAspectRatio: _gridAspectRatio,
                              ),
                          itemCount: visibleItems.length +
                              (visibleItems.length < filteredItems.length
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (index >= visibleItems.length) {
                              return const _GlobalMarketplaceLoadMoreCard();
                            }

                            final item = visibleItems[index];

                            return CatalogGridCard(
                              key: ValueKey(
                                'global-market-${item.id}-${item.cardCode}-${item.imageUrl}',
                              ),
                              code: item.cardCode,
                              title: item.name,
                              metadata: [
                                if (item.hasSellerName)
                                  'Vendedor: ${item.sellerName}',
                                item.formattedPrice,
                                '${item.statusLabel} - ${item.conditionLabel}',
                                'Quantidade: ${item.quantity}x',
                              ],
                              footer: Row(
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
                                      icon: const Icon(
                                        Icons.storefront_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Vitrine'),
                                    ),
                                  ),
                                ],
                              ),
                              image: _GlobalMarketplaceCardImage(
                                key: ValueKey(
                                  'global-market-image-${item.id}-${item.imageUrl}',
                                ),
                                imageUrl: item.imageUrl,
                                cardCode: item.cardCode,
                              ),
                              onTap: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => _GlobalMarketplaceCardDetailsDialog(
                                    card: item,
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
                              },
                            );
                          },
                        ),
                      ),
              ],
            ),
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

class _GlobalMarketplaceHeader extends StatelessWidget {
  final int totalListings;
  final int totalCards;
  final int totalWithPrice;
  final TextEditingController searchController;
  final bool isCollapsed;
  final bool showOnlyPriced;
  final bool showOnlyActive;
  final String selectedColor;
  final String selectedType;
  final String selectedRarity;
  final String selectedSort;
  final List<String> colorOptions;
  final List<String> typeOptions;
  final List<String> rarityOptions;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onToggleOnlyPriced;
  final VoidCallback onToggleOnlyActive;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onRarityChanged;
  final ValueChanged<String> onSortChanged;

  const _GlobalMarketplaceHeader({
    super.key,
    required this.totalListings,
    required this.totalCards,
    required this.totalWithPrice,
    required this.searchController,
    required this.isCollapsed,
    required this.showOnlyPriced,
    required this.showOnlyActive,
    required this.selectedColor,
    required this.selectedType,
    required this.selectedRarity,
    required this.selectedSort,
    required this.colorOptions,
    required this.typeOptions,
    required this.rarityOptions,
    required this.onToggleCollapsed,
    required this.onToggleOnlyPriced,
    required this.onToggleOnlyActive,
    required this.onColorChanged,
    required this.onTypeChanged,
    required this.onRarityChanged,
    required this.onSortChanged,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Encontre cartas à venda de toda a plataforma em um só lugar.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _GlobalMarketplaceStatCard(
                label: 'Anúncios',
                value: '$totalListings',
                icon: Icons.storefront_outlined,
              ),
              _GlobalMarketplaceStatCard(
                label: 'Cartas',
                value: '$totalCards',
                icon: Icons.style_outlined,
              ),
              _GlobalMarketplaceStatCard(
                label: 'Com preço',
                value: '$totalWithPrice',
                icon: Icons.sell_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nome, código ou edição',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () => searchController.clear(),
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilterChip(
                label: const Text('Somente ativas'),
                selected: showOnlyActive,
                onSelected: (_) => onToggleOnlyActive(),
              ),
              FilterChip(
                label: const Text('Somente com preço'),
                selected: showOnlyPriced,
                onSelected: (_) => onToggleOnlyPriced(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: selectedColor,
                  decoration: const InputDecoration(labelText: 'Cor'),
                  items: colorOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onColorChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: typeOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onTypeChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: selectedRarity,
                  decoration: const InputDecoration(labelText: 'Raridade'),
                  items: rarityOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onRarityChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: selectedSort,
                  decoration: const InputDecoration(labelText: 'Ordenar por'),
                  items: const [
                    'Mais recentes',
                    'Preço: menor',
                    'Preço: maior',
                    'Nome',
                    'Código',
                  ]
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlobalMarketplaceStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _GlobalMarketplaceStatCard({
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

class _GlobalMarketplaceCardDetailsDialog extends StatefulWidget {
  final MarketplaceListing card;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback? onOpenSellerStore;
  final int selectedQuantity;
  final ValueChanged<int> onQuantityChanged;

  const _GlobalMarketplaceCardDetailsDialog({
    required this.card,
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _globalInfoRow('Preço', card.formattedPrice),
                    if (card.hasSellerName)
                      _globalInfoRow('Vendedor', card.sellerName),
                    _globalInfoRow('Status', card.statusLabel),
                    _globalInfoRow('Condição', card.conditionLabel),
                    _globalInfoRow('Quantidade disponível', '${card.quantity}x'),
                    _globalInfoRow('Set', card.setName),
                    _globalInfoRow('Raridade', card.rarity),
                    _globalInfoRow('Cor', card.color),
                    _globalInfoRow('Tipo', card.type),
                    _globalInfoRow('Atributo', card.attribute),
                    if (card.hasNotes) _globalInfoRow('Observações', card.notes),
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
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
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

    return GestureDetector(
      onTap: () {
        if (directUrl.isEmpty) return;
        showDialog<void>(
          context: context,
          builder: (_) => _GlobalMarketplaceCardImageFullscreenDialog(
            imageUrl: directUrl,
            title: title,
          ),
        );
      },
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
        height: height,
        child: directUrl.isEmpty
            ? const Center(child: Icon(Icons.image_not_supported_outlined))
            : Image.network(
                directUrl,
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, __, ___) {
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
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, __, ___) {
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
      errorBuilder: (_, __, ___) {
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
        color: color.withOpacity(0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
