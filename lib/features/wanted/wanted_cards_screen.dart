import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/catalog_search_field.dart';
import '../../core/widgets/dashboard_header_panel.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../core/widgets/primary_bottom_navigation.dart';
import '../../core/widgets/summary_stat_card.dart';
import '../../data/models/wanted_card_listing.dart';
import '../../data/repositories/wanted_cards_repository.dart';

class WantedCardsScreen extends ConsumerStatefulWidget {
  const WantedCardsScreen({super.key});

  @override
  ConsumerState<WantedCardsScreen> createState() => _WantedCardsScreenState();
}

class _WantedCardsScreenState extends ConsumerState<WantedCardsScreen> {
  static const double _cardMaxWidth = 220;
  static const double _cardSpacing = 12;
  static const double _gridAspectRatio = 0.53;

  final TextEditingController _searchController = TextEditingController();
  late Future<List<WantedCardListing>> _wantedFuture;
  String _query = '';
  bool _showMineOnly = false;

  @override
  void initState() {
    super.initState();
    _wantedFuture = _loadWantedCards();
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

  Future<List<WantedCardListing>> _loadWantedCards() {
    final repo = ref.read(wantedCardsRepositoryProvider);
    return _showMineOnly
        ? repo.getMyWantedCards()
        : repo.getGlobalWantedCards();
  }

  void _reloadWantedCards() {
    if (!mounted) return;
    setState(() {
      _wantedFuture = _loadWantedCards();
    });
  }

  List<WantedCardListing> _filterItems(List<WantedCardListing> allItems) {
    final filtered =
        allItems
            .where((item) {
              if (_query.isEmpty) return true;

              return item.name.toLowerCase().contains(_query) ||
                  item.cardCode.toLowerCase().contains(_query) ||
                  item.setName.toLowerCase().contains(_query);
            })
            .toList(growable: false)
          ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));

    return filtered;
  }

  Future<void> _showAddWantedDialog() async {
    if (!requireSignedIn(context)) {
      return;
    }

    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _WantedCardFormDialog(),
    );

    if (added == true) {
      _reloadWantedCards();
    }
  }

  Future<void> _openWhatsApp(WantedCardListing item) async {
    if (!requireSignedIn(context)) {
      return;
    }

    if (!item.hasWhatsAppContact) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta busca nao possui WhatsApp configurado.'),
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://wa.me/${item.normalizedWhatsAppNumber}?text=${Uri.encodeComponent(_buildOfferMessage(item))}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o WhatsApp.')),
      );
    }
  }

  String _buildOfferMessage(WantedCardListing item) {
    final greeting = item.hasSeekerName ? 'Oi ${item.seekerName},' : 'Oi,';
    final extras = item.notes.trim().isNotEmpty
        ? '\n\nObservacao da busca: ${item.notes.trim()}'
        : '';

    return [
      greeting,
      'eu tenho essas cartas:',
      '',
      '${item.quantity}x ${item.name} - ${item.cardCode}',
      extras,
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const HomeNavigationButton(),
        title: const Text('Cartas procuradas'),
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
            tooltip: 'Cadastrar busca',
            onPressed: _showAddWantedDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<WantedCardListing>>(
        future: _wantedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _WantedLoadingView();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar buscas:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allItems = snapshot.data ?? const <WantedCardListing>[];
          final filteredItems = _filterItems(allItems);
          final totalCards = filteredItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final uniqueCards = filteredItems
              .map((item) => item.cardCode)
              .toSet()
              .length;
          final activeItems = filteredItems
              .where((item) => item.isActive)
              .length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _WantedHeader(
                  totalListings: filteredItems.length,
                  totalCards: totalCards,
                  uniqueCards: uniqueCards,
                  activeItems: activeItems,
                  searchController: _searchController,
                  showMineOnly: _showMineOnly,
                  onToggleMineOnly: () {
                    if (!requireSignedIn(context)) {
                      return;
                    }

                    setState(() {
                      _showMineOnly = !_showMineOnly;
                      _wantedFuture = _loadWantedCards();
                    });
                  },
                  onAddWanted: _showAddWantedDialog,
                ),
              ),
              if (filteredItems.isEmpty)
                const SliverFillRemaining(child: _WantedEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: _cardMaxWidth,
                          crossAxisSpacing: _cardSpacing,
                          mainAxisSpacing: _cardSpacing,
                          childAspectRatio: _gridAspectRatio,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = filteredItems[index];
                      final isOwner =
                          Supabase.instance.client.auth.currentUser?.id ==
                          item.ownerUserId;

                      return CatalogGridCard(
                        code: item.cardCode,
                        title: item.name,
                        metadata: [
                          'Busca: ${item.quantity}x',
                          if (item.hasSeekerName) 'Pessoa: ${item.seekerName}',
                          'Set: ${item.setName.isEmpty ? '-' : item.setName}',
                          item.statusLabel,
                        ],
                        footer: FilledButton.icon(
                          onPressed: isOwner ? null : () => _openWhatsApp(item),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: Text(isOwner ? 'Sua busca' : 'Eu tenho'),
                        ),
                        image: _WantedCardImage(
                          imageUrl: item.imageUrl,
                          cardCode: item.cardCode,
                        ),
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => _WantedCardDetailsDialog(
                              item: item,
                              isOwner: isOwner,
                              onOpenWhatsApp: () => _openWhatsApp(item),
                              onChanged: _reloadWantedCards,
                            ),
                          );
                        },
                      );
                    }, childCount: filteredItems.length),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWantedDialog,
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar busca'),
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/wanted',
      ),
    );
  }
}

class _WantedHeader extends StatelessWidget {
  final int totalListings;
  final int totalCards;
  final int uniqueCards;
  final int activeItems;
  final TextEditingController searchController;
  final bool showMineOnly;
  final VoidCallback onToggleMineOnly;
  final VoidCallback onAddWanted;

  const _WantedHeader({
    required this.totalListings,
    required this.totalCards,
    required this.uniqueCards,
    required this.activeItems,
    required this.searchController,
    required this.showMineOnly,
    required this.onToggleMineOnly,
    required this.onAddWanted,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;

    return DashboardHeaderPanel(
      crossAxisAlignment: CrossAxisAlignment.start,
      top: Text(
        'Veja cartas que outros usuarios estao procurando e ofereca as que voce tem.',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      stats: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SummaryStatCard(
            label: 'Buscas',
            value: '$totalListings',
            icon: Icons.travel_explore_outlined,
          ),
          SummaryStatCard(
            label: 'Cartas',
            value: '$totalCards',
            icon: Icons.style_outlined,
          ),
          SummaryStatCard(
            label: 'Unicas',
            value: '$uniqueCards',
            icon: Icons.auto_awesome_motion_outlined,
          ),
          SummaryStatCard(
            label: 'Ativas',
            value: '$activeItems',
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
      search: compact
          ? Column(
              children: [
                CatalogSearchField(
                  controller: searchController,
                  hintText: 'Buscar por nome, codigo ou set',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('Minhas buscas'),
                        selected: showMineOnly,
                        onSelected: (_) => onToggleMineOnly(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onAddWanted,
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar'),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: CatalogSearchField(
                    controller: searchController,
                    hintText: 'Buscar por nome, codigo ou set',
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('Minhas buscas'),
                  selected: showMineOnly,
                  onSelected: (_) => onToggleMineOnly(),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAddWanted,
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar busca'),
                ),
              ],
            ),
    );
  }
}

class _WantedCardFormDialog extends ConsumerStatefulWidget {
  final WantedCardListing? item;

  const _WantedCardFormDialog({this.item});

  @override
  ConsumerState<_WantedCardFormDialog> createState() =>
      _WantedCardFormDialogState();
}

class _WantedCardFormDialogState extends ConsumerState<_WantedCardFormDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _codeController = TextEditingController(text: item?.cardCode ?? '');
    _quantityController = TextEditingController(
      text: item == null ? '1' : item.quantity.toString(),
    );
    _notesController = TextEditingController(text: item?.notes ?? '');
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
      if (quantity <= 0) {
        throw Exception('Quantidade invalida.');
      }

      final repo = ref.read(wantedCardsRepositoryProvider);
      final item = widget.item;
      if (item == null) {
        await repo.addWantedCard(
          rawCardCode: _codeController.text,
          quantity: quantity,
          notes: _notesController.text,
        );
      } else {
        await repo.updateWantedCard(
          id: item.id,
          quantity: quantity,
          notes: _notesController.text,
          isActive: _isActive,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar busca: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar busca' : 'Cadastrar busca'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              enabled: !isEditing,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codigo da carta',
                hintText: 'Ex: OP01-001',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observacoes',
                hintText: 'Ex: aceito paralela, preferencia mint...',
              ),
            ),
            if (isEditing) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                title: const Text('Busca ativa'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _WantedCardDetailsDialog extends ConsumerWidget {
  final WantedCardListing item;
  final bool isOwner;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback onChanged;

  const _WantedCardDetailsDialog({
    required this.item,
    required this.isOwner,
    required this.onOpenWhatsApp,
    required this.onChanged,
  });

  Future<void> _edit(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _WantedCardFormDialog(item: item),
    );
    if (changed == true) {
      onChanged();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(wantedCardsRepositoryProvider).deleteWantedCard(item.id);
    onChanged();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.cardCode, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 320,
                        child: _WantedCardImage(
                          imageUrl: item.imageUrl,
                          cardCode: item.cardCode,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Quantidade', '${item.quantity}x'),
                    if (item.hasSeekerName) _infoRow('Pessoa', item.seekerName),
                    _infoRow('Status', item.statusLabel),
                    _infoRow('Set', item.setName),
                    _infoRow('Raridade', item.rarity),
                    _infoRow('Cor', item.color),
                    _infoRow('Tipo', item.type),
                    _infoRow('Atributo', item.attribute),
                    if (item.hasNotes) _infoRow('Observacoes', item.notes),
                    if (item.text.trim().isNotEmpty)
                      _infoRow('Texto da carta', item.text),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isOwner) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _edit(context),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _delete(context, ref),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: onOpenWhatsApp,
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Enviar: eu tenho essas cartas'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Fechar'),
                  ),
                ],
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
            width: 105,
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

class _WantedCardImage extends StatelessWidget {
  final String imageUrl;
  final String cardCode;

  const _WantedCardImage({required this.imageUrl, required this.cardCode});

  @override
  Widget build(BuildContext context) {
    final directUrl = imageUrl.trim();

    if (directUrl.isEmpty) {
      return Center(
        child: Text(
          cardCode,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }

    return Image.network(
      directUrl,
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
    );
  }
}

class _WantedEmptyState extends StatelessWidget {
  const _WantedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.travel_explore_outlined,
              size: 60,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma busca encontrada.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cadastre as cartas que voce procura ou ajuste a busca.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WantedLoadingView extends StatelessWidget {
  const _WantedLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _WantedSkeletonBox(height: 190, radius: 24),
        SizedBox(height: 16),
        _WantedSkeletonBox(height: 220, radius: 20),
        SizedBox(height: 12),
        _WantedSkeletonBox(height: 220, radius: 20),
      ],
    );
  }
}

class _WantedSkeletonBox extends StatelessWidget {
  final double height;
  final double radius;

  const _WantedSkeletonBox({required this.height, required this.radius});

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
