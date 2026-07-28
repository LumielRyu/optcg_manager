import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tcg/tcg_game.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/tcg_marketplace_listing.dart';
import '../../data/repositories/tcg_marketplace_repository.dart';

class TcgMarketplaceScreen extends ConsumerStatefulWidget {
  final TcgGame game;

  const TcgMarketplaceScreen({super.key, required this.game});

  @override
  ConsumerState<TcgMarketplaceScreen> createState() =>
      _TcgMarketplaceScreenState();
}

class _TcgMarketplaceScreenState extends ConsumerState<TcgMarketplaceScreen> {
  List<TcgMarketplaceListing> _items = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final items = await ref
          .read(tcgMarketplaceRepositoryProvider)
          .listPublic(widget.game.slug);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<TcgMarketplaceListing> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.cardCode.toLowerCase().contains(query) ||
              item.setName.toLowerCase().contains(query) ||
              item.sellerName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> _contact(TcgMarketplaceListing item) async {
    if (!requireSignedIn(context)) return;
    try {
      final contact = await ref
          .read(tcgMarketplaceRepositoryProvider)
          .getPublicContact(item.id);
      final digits = contact.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        throw StateError('O vendedor não possui WhatsApp disponível.');
      }
      final phone = digits.startsWith('55') ? digits : '55$digits';
      final message = Uri.encodeComponent(
        'Olá! Vi no TCG BH o anúncio de ${item.quantity}x ${item.name} '
        '(${item.cardCode}) por ${item.formattedPrice} cada. Ainda está disponível?',
      );
      final opened = await launchUrl(
        Uri.parse('https://wa.me/$phone?text=$message'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Não foi possível abrir o WhatsApp.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        leading: HomeNavigationButton(destinationRoute: '/${widget.game.slug}'),
        title: Text('Marketplace • ${widget.game.label}'),
        actions: [
          IconButton(
            tooltip: 'Minhas vendas',
            onPressed: () => context.go('/${widget.game.slug}/sales'),
            icon: const Icon(Icons.sell_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'Buscar carta, edição ou vendedor',
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _query = ''),
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${visible.length} anúncios ativos • contato protegido pelo login',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 58),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty
                              ? 'Ainda não há anúncios ativos de ${widget.game.label}.'
                              : 'Nenhum anúncio corresponde à busca.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () =>
                              context.go('/${widget.game.slug}/sales'),
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text('Anunciar carta'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = visible[index];
                    return CatalogGridCard(
                      code: _displayCode(item.cardCode),
                      title: item.name,
                      metadata: [
                        item.formattedPrice,
                        '${item.quantity}x • ${item.conditionLabel}',
                        item.sellerName.isEmpty
                            ? 'Vendedor da comunidade'
                            : item.sellerName,
                      ],
                      image: Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      footer: FilledButton.tonalIcon(
                        onPressed: () => _openDetails(item),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('Ver anúncio'),
                      ),
                      onTap: () => _openDetails(item),
                    );
                  }, childCount: visible.length),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.49,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openDetails(TcgMarketplaceListing item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 300,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.formattedPrice,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text('${item.quantity} disponível • ${item.conditionLabel}'),
                Text('${item.setName} • ${item.rarity}'),
                const Divider(height: 28),
                Text(
                  item.sellerName.isEmpty
                      ? 'Vendedor da comunidade'
                      : 'Vendedor: ${item.sellerName}',
                ),
                if (item.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(item.notes),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _contact(item);
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Falar no WhatsApp'),
          ),
        ],
      ),
    );
  }

  String _displayCode(String code) {
    final parts = code.split(':');
    return parts.length >= 3
        ? '${parts[parts.length - 2]}-${parts.last}'
        : code;
  }
}
