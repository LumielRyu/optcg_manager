import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tcg/tcg_game.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/tcg_marketplace_listing.dart';
import '../../data/models/marketplace_order.dart';
import '../../data/repositories/marketplace_order_repository.dart';
import '../../data/repositories/tcg_marketplace_repository.dart';

class TcgSalesScreen extends ConsumerStatefulWidget {
  final TcgGame game;

  const TcgSalesScreen({super.key, required this.game});

  @override
  ConsumerState<TcgSalesScreen> createState() => _TcgSalesScreenState();
}

class _TcgSalesScreenState extends ConsumerState<TcgSalesScreen> {
  List<TcgMarketplaceListing> _items = const [];
  bool _loading = true;
  String? _error;
  List<MarketplaceOrder> _pendingOrders = const [];
  final Set<String> _resolvingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ref.read(tcgMarketplaceRepositoryProvider).listMine(widget.game.slug),
        ref
            .read(marketplaceOrderRepositoryProvider)
            .getSellerOrders(gameSlug: widget.game.slug),
      ]);
      final items = results[0] as List<TcgMarketplaceListing>;
      final orders = results[1] as List<MarketplaceOrder>;
      if (!mounted) return;
      setState(() {
        _items = items;
        _pendingOrders = orders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _edit(TcgMarketplaceListing listing) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _TcgSaleEditorDialog(game: widget.game, listing: listing),
    );
    if (changed == true) await _load();
  }

  Future<void> _resolveOrder(
    MarketplaceOrder order, {
    required bool confirm,
  }) async {
    if (_resolvingOrderIds.contains(order.id)) return;
    setState(() => _resolvingOrderIds.add(order.id));
    try {
      final repository = ref.read(marketplaceOrderRepositoryProvider);
      if (confirm) {
        await repository.confirmOrder(order.id);
      } else {
        await repository.rejectOrder(order.id);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirm
                ? 'Venda confirmada.'
                : 'Reserva recusada e estoque restaurado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _resolvingOrderIds.remove(order.id));
    }
  }

  Future<void> _contactBuyer(MarketplaceOrder order) async {
    final digits = order.buyerContact.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final phone = digits.startsWith('55') ? digits : '55$digits';
    await launchUrl(
      Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent('Olá ${order.buyerName}, recebi sua reserva no TCG BH.')}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildPendingOrdersPanel() {
    if (_pendingOrders.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pedidos aguardando confirmação (${_pendingOrders.length})',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Text(
              'Confirme em até 24 horas ou o estoque será restaurado.',
            ),
            const SizedBox(height: 10),
            for (final order in _pendingOrders)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.buyerName.trim().isEmpty
                            ? 'Comprador'
                            : order.buyerName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${order.totalCards} cartas • ${order.remainingLabel}',
                      ),
                      const SizedBox(height: 6),
                      for (final item in order.items)
                        Text(
                          '${item.quantity}x ${item.cardName} (${item.cardCode})',
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          if (order.buyerContact.trim().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _contactBuyer(order),
                              icon: const Icon(Icons.chat_outlined),
                              label: const Text('WhatsApp'),
                            ),
                          OutlinedButton(
                            onPressed: _resolvingOrderIds.contains(order.id)
                                ? null
                                : () => _resolveOrder(order, confirm: false),
                            child: const Text('Recusar'),
                          ),
                          FilledButton.icon(
                            onPressed: _resolvingOrderIds.contains(order.id)
                                ? null
                                : () => _resolveOrder(order, confirm: true),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Confirmar venda'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final published = _items.where((item) => item.isVisible).length;
    final inventory = _items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        leading: HomeNavigationButton(destinationRoute: '/${widget.game.slug}'),
        title: Text('Cartas à venda • ${widget.game.label}'),
        actions: [
          IconButton(
            tooltip: 'Abrir marketplace',
            onPressed: () => context.go('/${widget.game.slug}/marketplace'),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/${widget.game.slug}/collection'),
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: const Text('Importar da coleção'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(published: published, inventory: inventory),
      ),
    );
  }

  Widget _buildBody({required int published, required int inventory}) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 280),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      final signedIn = Supabase.instance.client.auth.currentUser != null;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 110),
          Icon(
            signedIn ? Icons.cloud_off_outlined : Icons.lock_outline,
            size: 58,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: signedIn ? _load : () => context.go('/login'),
              icon: Icon(signedIn ? Icons.refresh : Icons.login),
              label: Text(signedIn ? 'Tentar novamente' : 'Entrar'),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SaleStat(
                      icon: Icons.inventory_2_outlined,
                      value: '$inventory',
                      label: 'cartas à venda',
                    ),
                    _SaleStat(
                      icon: Icons.public,
                      value: '$published',
                      label: 'anúncios publicados',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Anúncios publicados permanecem visíveis por 7 dias. '
                            'Abra uma carta para definir preço, condição e renovar.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_pendingOrders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPendingOrdersPanel(),
                ],
              ],
            ),
          ),
        ),
        if (_items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sell_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma carta ${widget.game.label} à venda.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Abra sua coleção e use o botão “Colocar à venda”.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () =>
                          context.go('/${widget.game.slug}/collection'),
                      icon: const Icon(Icons.collections_bookmark_outlined),
                      label: const Text('Abrir coleção'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = _items[index];
                return CatalogGridCard(
                  code: _displayCode(item.cardCode),
                  title: item.name,
                  metadata: [
                    '${item.quantity}x • ${item.conditionLabel}',
                    item.formattedPrice,
                    item.isVisible
                        ? 'Publicado'
                        : item.isExpired
                        ? 'Expirado'
                        : 'Não publicado',
                  ],
                  image: Image.network(
                    item.imageUrl,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                  footer: Text(
                    item.isVisible
                        ? 'Visível no marketplace'
                        : 'Toque para configurar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _edit(item),
                );
              }, childCount: _items.length),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.51,
              ),
            ),
          ),
      ],
    );
  }

  String _displayCode(String code) {
    final parts = code.split(':');
    return parts.length >= 3
        ? '${parts[parts.length - 2]}-${parts.last}'
        : code;
  }
}

class _TcgSaleEditorDialog extends ConsumerStatefulWidget {
  final TcgGame game;
  final TcgMarketplaceListing listing;

  const _TcgSaleEditorDialog({required this.game, required this.listing});

  @override
  ConsumerState<_TcgSaleEditorDialog> createState() =>
      _TcgSaleEditorDialogState();
}

class _TcgSaleEditorDialogState extends ConsumerState<_TcgSaleEditorDialog> {
  late final TextEditingController _priceController;
  late final TextEditingController _percentageController;
  late final TextEditingController _notesController;
  late int _quantity;
  late bool _publish;
  late String _pricingMode;
  late String _rounding;
  late String _status;
  late String _condition;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.listing;
    _quantity = item.quantity;
    _publish = item.isPublic && !item.isExpired;
    _pricingMode = item.pricingMode;
    _rounding = item.ligaRounding;
    _status = item.saleStatus;
    _condition = item.cardCondition;
    _priceController = TextEditingController(
      text: item.priceInCents == null
          ? ''
          : (item.priceInCents! / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _percentageController = TextEditingController(
      text: item.ligaPercentage?.toStringAsFixed(0) ?? '0',
    );
    _notesController = TextEditingController(text: item.notes);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _percentageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? _manualPrice() {
    final input = _priceController.text.trim();
    final raw = input.contains(',')
        ? input.replaceAll('.', '').replaceAll(',', '.')
        : input;
    final value = double.tryParse(raw);
    return value == null ? null : (value * 100).round();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(tcgMarketplaceRepositoryProvider)
          .saveListing(
            listing: widget.listing,
            quantity: _quantity,
            publish: _publish,
            manualPriceInCents: _manualPrice(),
            pricingMode: _pricingMode,
            ligaPercentage: double.tryParse(
              _percentageController.text.trim().replaceAll(',', '.'),
            ),
            ligaRounding: _rounding,
            saleStatus: _status,
            cardCondition: _condition,
            notes: _notesController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover das vendas?'),
        content: Text('O anúncio de ${widget.listing.name} será excluído.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tcgMarketplaceRepositoryProvider)
          .delete(widget.listing.id);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.listing;
    return AlertDialog(
      title: Text(item.name),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 105,
                    height: 145,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.contain,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.setName),
                        Text(item.rarity),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _quantity,
                          decoration: const InputDecoration(
                            labelText: 'Quantidade',
                          ),
                          items: [
                            for (var value = 1; value <= 99; value++)
                              DropdownMenuItem(
                                value: value,
                                child: Text('$value'),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(
                                  () => _quantity = value ?? _quantity,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: TcgMarketplaceListing.manualPricingMode,
                    label: Text('Manual'),
                    icon: Icon(Icons.edit_outlined),
                  ),
                  ButtonSegment(
                    value: TcgMarketplaceListing.ligaPercentagePricingMode,
                    label: Text('% da Liga'),
                    icon: Icon(Icons.percent),
                  ),
                ],
                selected: {_pricingMode},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _pricingMode = value.first),
              ),
              const SizedBox(height: 12),
              if (_pricingMode == TcgMarketplaceListing.manualPricingMode)
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Preço',
                    prefixText: 'R\$ ',
                  ),
                )
              else ...[
                TextField(
                  controller: _percentageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Ajuste sobre o menor preço da Liga',
                    suffixText: '%',
                    helperText:
                        'Use número negativo para anunciar abaixo da Liga.',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _rounding,
                  decoration: const InputDecoration(
                    labelText: 'Arredondamento',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TcgMarketplaceListing.noRounding,
                      child: Text('Sem arredondar'),
                    ),
                    DropdownMenuItem(
                      value: TcgMarketplaceListing.roundUp,
                      child: Text('Para cima em reais'),
                    ),
                    DropdownMenuItem(
                      value: TcgMarketplaceListing.roundDown,
                      child: Text('Para baixo em reais'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _rounding = value ?? _rounding),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: const InputDecoration(labelText: 'Condição'),
                items: const [
                  DropdownMenuItem(value: 'mint', child: Text('Mint')),
                  DropdownMenuItem(
                    value: 'near_mint',
                    child: Text('Near Mint'),
                  ),
                  DropdownMenuItem(
                    value: 'lightly_played',
                    child: Text('Light Play'),
                  ),
                  DropdownMenuItem(value: 'played', child: Text('Played')),
                  DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                ],
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _condition = value ?? _condition),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Ativa')),
                  DropdownMenuItem(value: 'reserved', child: Text('Reservada')),
                  DropdownMenuItem(value: 'sold', child: Text('Vendida')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _status = value ?? _status;
                        if (_status != TcgMarketplaceListing.activeStatus) {
                          _publish = false;
                        }
                      }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  hintText: 'Idioma, detalhes da conservação, retirada...',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publicar no marketplace'),
                subtitle: Text(
                  _publish
                      ? 'Ao salvar, o anúncio será renovado por 7 dias.'
                      : 'A carta ficará apenas na sua área de vendas.',
                ),
                value: _publish,
                onChanged:
                    _saving || _status != TcgMarketplaceListing.activeStatus
                    ? null
                    : (value) => setState(() => _publish = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Remover'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SaleStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SaleStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text('$value $label'));
  }
}
