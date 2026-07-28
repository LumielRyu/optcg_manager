import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/tcg/tcg_game.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../core/widgets/tcg_liga_price.dart';
import '../../core/widgets/tcg_wanted_add_button.dart';
import '../../data/models/tcg_collection_item.dart';
import '../../data/repositories/tcg_collection_repository.dart';
import '../../data/repositories/tcg_marketplace_repository.dart';

class TcgCollectionScreen extends ConsumerStatefulWidget {
  final TcgGame game;

  const TcgCollectionScreen({super.key, required this.game});

  @override
  ConsumerState<TcgCollectionScreen> createState() =>
      _TcgCollectionScreenState();
}

class _TcgCollectionScreenState extends ConsumerState<TcgCollectionScreen> {
  List<TcgCollectionItem> _items = const [];
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  String get _libraryRoute => '/${widget.game.slug}/library';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final items = await ref
          .read(tcgCollectionRepositoryProvider)
          .listOwned(widget.game.slug);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _changeQuantity(
    TcgCollectionItem item,
    int nextQuantity, {
    bool closeSheet = false,
  }) async {
    if (_saving || !requireSignedIn(context)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tcgCollectionRepositoryProvider)
          .setQuantity(item, nextQuantity);
      await _load();
      if (mounted && closeSheet) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addToSales(TcgCollectionItem item) async {
    if (_saving || !requireSignedIn(context)) return;
    setState(() => _saving = true);
    try {
      await ref.read(tcgMarketplaceRepositoryProvider).addFromCollection(item);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Carta adicionada a Cartas à venda.'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () => context.go('/${widget.game.slug}/sales'),
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final totalCards = _items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        leading: HomeNavigationButton(destinationRoute: '/${widget.game.slug}'),
        title: Text('Minha coleção ${widget.game.label}'),
        actions: [
          IconButton(
            tooltip: 'Atualizar coleção',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!requireSignedIn(context)) return;
          context.go(_libraryRoute);
        },
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Adicionar cartas'),
      ),
      body: TcgLigaPriceScope(
        lookupCodes: _items.map((item) => item.cardCode),
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(totalCards),
        ),
      ),
    );
  }

  Widget _buildBody(int totalCards) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 280),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null) {
      final signedIn = Supabase.instance.client.auth.currentUser != null;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            signedIn ? Icons.cloud_off_outlined : Icons.lock_outline,
            size: 52,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: signedIn
                  ? _load
                  : () {
                      requireSignedIn(context);
                    },
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
                    _CollectionStat(
                      icon: Icons.style_outlined,
                      value: '${_items.length}',
                      label: 'cartas diferentes',
                    ),
                    _CollectionStat(
                      icon: Icons.layers_outlined,
                      value: '$totalCards',
                      label: 'cartas no total',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TcgLigaCollectionValueCard(
                  gameLabel: widget.game.label,
                  items: _items.map(
                    (item) => TcgLigaCollectionItemReference(
                      lookupCode: item.cardCode,
                      quantity: item.quantity,
                    ),
                  ),
                ),
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
                    const Icon(Icons.collections_bookmark_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Sua coleção ${widget.game.label} está vazia.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Abra a biblioteca e use o botão + nas cartas que você possui.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => context.go(_libraryRoute),
                      icon: const Icon(Icons.auto_stories_outlined),
                      label: const Text('Abrir biblioteca'),
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
                    'Quantidade: ${item.quantity}x',
                    item.setName,
                    item.rarity,
                    item.type,
                  ],
                  image: Image.network(
                    item.imageUrl,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                  footer: TcgLigaPriceLabel(lookupCode: item.cardCode),
                  onTap: () => _openItemSheet(item),
                );
              }, childCount: _items.length),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.51,
              ),
            ),
          ),
      ],
    );
  }

  String _displayCode(String lookupCode) {
    final parts = lookupCode.split(':');
    return parts.length >= 3
        ? '${parts[parts.length - 2]}-${parts.last}'
        : parts.length == 2
        ? parts.last
        : lookupCode;
  }

  Future<void> _openItemSheet(TcgCollectionItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
              const SizedBox(height: 16),
              Text(
                item.name,
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text('${item.setName} • ${item.rarity}'),
              const SizedBox(height: 16),
              TcgLigaPriceDetailsPanel(
                lookupCode: item.cardCode,
                gameLabel: widget.game.label,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Remover uma',
                    onPressed: _saving
                        ? null
                        : () => _changeQuantity(
                            item,
                            item.quantity - 1,
                            closeSheet: true,
                          ),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Text(
                      '${item.quantity} na coleção',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Adicionar uma',
                    onPressed: _saving
                        ? null
                        : () => _changeQuantity(
                            item,
                            item.quantity + 1,
                            closeSheet: true,
                          ),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _saving ? null : () => _addToSales(item),
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('Colocar uma à venda'),
              ),
              const SizedBox(height: 6),
              TcgWantedAddButton(
                draft: TcgCollectionDraft(
                  gameSlug: item.gameSlug,
                  catalogCardId: item.catalogCardId,
                  variantId: item.variantId,
                  cardCode: item.cardCode,
                  name: item.name,
                  imageUrl: item.imageUrl,
                  setName: item.setName,
                  rarity: item.rarity,
                  color: item.color,
                  type: item.type,
                  text: item.text,
                  attribute: item.attribute,
                ),
                gameLabel: widget.game.label,
                wantedRoute: '/${widget.game.slug}/wanted',
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => _changeQuantity(item, 0, closeSheet: true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover da coleção'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CollectionStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}
