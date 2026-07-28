import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tcg/tcg_deck_adapter.dart';
import '../../core/tcg/tcg_deck_rules.dart';
import '../../core/tcg/tcg_game.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/tcg_collection_item.dart';
import '../../data/models/tcg_deck.dart';
import '../../data/repositories/tcg_collection_repository.dart';
import '../../data/repositories/tcg_deck_repository.dart';

class TcgDecksScreen extends ConsumerStatefulWidget {
  final TcgGame game;

  const TcgDecksScreen({super.key, required this.game});

  @override
  ConsumerState<TcgDecksScreen> createState() => _TcgDecksScreenState();
}

class _TcgDecksScreenState extends ConsumerState<TcgDecksScreen> {
  List<TcgDeck> _decks = const [];
  bool _loading = true;
  String? _errorMessage;

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
      final decks = await ref
          .read(tcgDeckRepositoryProvider)
          .listDecks(widget.game);
      if (!mounted) return;
      setState(() {
        _decks = decks;
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

  Future<void> _createDeck() async {
    if (!requireSignedIn(context)) return;
    final formats = TcgDeckRulesRegistry.forGame(widget.game);
    final nameController = TextEditingController();
    var selectedFormat = formats.first;
    final result = await showDialog<({String name, TcgDeckFormatRules format})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Novo deck ${widget.game.label}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nome do deck',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TcgDeckFormatRules>(
                  initialValue: selectedFormat,
                  decoration: const InputDecoration(
                    labelText: 'Formato',
                    prefixIcon: Icon(Icons.rule_outlined),
                  ),
                  items: formats
                      .map(
                        (format) => DropdownMenuItem(
                          value: format,
                          child: Text(format.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (format) {
                    if (format != null) {
                      setDialogState(() => selectedFormat = format);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext, (
                  name: name,
                  format: selectedFormat,
                ));
              },
              child: const Text('Criar deck'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (result == null || !mounted) return;

    try {
      final deckId = await ref
          .read(tcgDeckRepositoryProvider)
          .createDeck(
            game: widget.game,
            name: result.name,
            format: result.format,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              TcgDeckEditorScreen(game: widget.game, deckId: deckId),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar deck: $error')));
    }
  }

  Future<void> _deleteDeck(TcgDeck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir deck?'),
        content: Text(
          'O deck “${deck.name}” e todas as cartas dele serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tcgDeckRepositoryProvider).deleteDeck(deck.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: HomeNavigationButton(destinationRoute: '/${widget.game.slug}'),
        title: Text('Decks ${widget.game.label}'),
        actions: [
          IconButton(
            tooltip: 'Atualizar decks',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDeck,
        icon: const Icon(Icons.add),
        label: const Text('Novo deck'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      final signedIn = Supabase.instance.client.auth.currentUser != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(signedIn ? Icons.cloud_off_outlined : Icons.lock_outline),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: signedIn ? _load : () => requireSignedIn(context),
                child: Text(signedIn ? 'Tentar novamente' : 'Entrar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_decks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dashboard_customize_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Nenhum deck ${widget.game.label} criado.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Crie um deck e use as cartas cadastradas na sua coleção.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _createDeck,
                icon: const Icon(Icons.add),
                label: const Text('Criar primeiro deck'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 430,
          mainAxisExtent: 260,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _decks.length,
        itemBuilder: (context, index) {
          final deck = _decks[index];
          final rules =
              TcgDeckRulesRegistry.bySlug(deck.formatSlug) ??
              TcgDeckRulesRegistry.defaultFor(widget.game);
          final validation = const TcgDeckValidator().validate(
            rules: rules,
            entries: deck.items.map(deckEntryFromItem).toList(growable: false),
            context: validationContextFromDeck(deck, rules),
          );
          final total = deck.items.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TcgDeckEditorScreen(game: widget.game, deckId: deck.id),
                  ),
                );
                await _load();
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deck.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') _deleteDeck(deck);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir deck'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text('${rules.label} • $total cartas'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final zone in rules.zones.keys)
                          Chip(
                            label: Text(
                              '${zone.label}: ${deck.quantityInZone(zone)}',
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          validation.isValid
                              ? Icons.verified_outlined
                              : Icons.info_outline,
                          color: validation.isValid
                              ? Colors.green
                              : Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validation.isValid
                                ? 'Estrutura básica válida'
                                : '${validation.errors.length} ajustes pendentes',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.arrow_forward),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TcgDeckEditorScreen extends ConsumerStatefulWidget {
  final TcgGame game;
  final String deckId;

  const TcgDeckEditorScreen({
    super.key,
    required this.game,
    required this.deckId,
  });

  @override
  ConsumerState<TcgDeckEditorScreen> createState() =>
      _TcgDeckEditorScreenState();
}

class _TcgDeckEditorScreenState extends ConsumerState<TcgDeckEditorScreen> {
  TcgDeck? _deck;
  List<TcgCollectionItem> _collection = const [];
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ref.read(tcgDeckRepositoryProvider).getDeck(widget.deckId),
        ref.read(tcgCollectionRepositoryProvider).listOwned(widget.game.slug),
      ]);
      if (!mounted) return;
      setState(() {
        _deck = results[0] as TcgDeck;
        _collection = results[1] as List<TcgCollectionItem>;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  TcgDeckFormatRules get _rules {
    final deck = _deck;
    return TcgDeckRulesRegistry.bySlug(deck?.formatSlug ?? '') ??
        TcgDeckRulesRegistry.defaultFor(widget.game);
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TcgDeckZone _suggestZone(TcgCollectionItem card) {
    final type = card.type.toUpperCase();
    if (widget.game == TcgGame.digimon && type.contains('DIGI-EGG')) {
      return TcgDeckZone.digiEgg;
    }
    if (widget.game == TcgGame.yugioh &&
        [
          'FUSION',
          'SYNCHRO',
          'XYZ',
          'LINK',
        ].any((value) => type.contains(value))) {
      return TcgDeckZone.extra;
    }
    if (widget.game == TcgGame.riftbound) {
      if (type.contains('RUNE')) return TcgDeckZone.resource;
      if (type.contains('BATTLEFIELD')) return TcgDeckZone.battlefield;
      if (type.contains('LEGEND')) return TcgDeckZone.legend;
      if (type.contains('CHAMPION')) return TcgDeckZone.chosenChampion;
    }
    return TcgDeckZone.main;
  }

  Future<void> _chooseZoneAndAdd(TcgCollectionItem card) async {
    final zones = _rules.zones.keys.toList(growable: false);
    var selected = zones.contains(_suggestZone(card))
        ? _suggestZone(card)
        : zones.first;
    if (zones.length > 1) {
      final chosen = await showDialog<TcgDeckZone>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Adicionar em qual zona?'),
            content: DropdownButtonFormField<TcgDeckZone>(
              initialValue: selected,
              items: zones
                  .map(
                    (zone) =>
                        DropdownMenuItem(value: zone, child: Text(zone.label)),
                  )
                  .toList(growable: false),
              onChanged: (zone) {
                if (zone != null) {
                  setDialogState(() => selected = zone);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      );
      if (chosen == null) return;
      selected = chosen;
    }
    final deck = _deck;
    if (deck == null) return;
    await _mutate(
      () => ref
          .read(tcgDeckRepositoryProvider)
          .addOrIncrement(deck: deck, card: card, zone: selected),
    );
  }

  Future<void> _openCollectionPicker() async {
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = _collection
              .where((card) {
                final needle = query.trim().toLowerCase();
                return needle.isEmpty ||
                    card.name.toLowerCase().contains(needle) ||
                    card.cardCode.toLowerCase().contains(needle) ||
                    card.setName.toLowerCase().contains(needle);
              })
              .toList(growable: false);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: TextField(
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: const InputDecoration(
                        hintText: 'Buscar na minha coleção',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Nenhuma carta encontrada na coleção.'),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final card = filtered[index];
                              return ListTile(
                                leading: SizedBox(
                                  width: 44,
                                  child: Image.network(
                                    card.imageUrl,
                                    fit: BoxFit.contain,
                                    webHtmlElementStrategy:
                                        WebHtmlElementStrategy.prefer,
                                  ),
                                ),
                                title: Text(card.name),
                                subtitle: Text(
                                  '${card.setName} • Você possui ${card.quantity}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Adicionar ao deck',
                                  onPressed: _saving
                                      ? null
                                      : () => _chooseZoneAndAdd(card),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    return Scaffold(
      appBar: AppBar(title: Text(deck?.name ?? 'Deck')),
      floatingActionButton: deck == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _openCollectionPicker,
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('Adicionar carta'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : deck == null
          ? const Center(child: Text('Deck não encontrado.'))
          : _buildEditor(deck),
    );
  }

  Widget _buildEditor(TcgDeck deck) {
    final rules = _rules;
    final validation = const TcgDeckValidator().validate(
      rules: rules,
      entries: deck.items.map(deckEntryFromItem).toList(growable: false),
      context: validationContextFromDeck(deck, rules),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      validation.isValid
                          ? Icons.verified_outlined
                          : Icons.rule_outlined,
                      color: validation.isValid ? Colors.green : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${rules.label}: ${validation.isValid ? 'estrutura válida' : '${validation.errors.length} ajustes'}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(rules.officialRulesUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Regras oficiais'),
                    ),
                  ],
                ),
                if (!validation.isValid) ...[
                  const SizedBox(height: 10),
                  for (final error in validation.errors.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('• $error'),
                    ),
                ],
                if (rules.supportsDynamicBanList) ...[
                  const SizedBox(height: 8),
                  Text(
                    'A validação cobre estrutura e cópias básicas. Listas banidas/restritas com vigência ainda precisam de sincronização.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final zone in rules.zones.keys)
          _DeckZoneSection(
            zone: zone,
            rule: rules.zones[zone]!,
            items: deck.items.where((item) => item.zone == zone).toList(),
            allZones: rules.zones.keys.toList(growable: false),
            saving: _saving,
            onSetQuantity: (item, quantity) => _mutate(
              () => ref
                  .read(tcgDeckRepositoryProvider)
                  .setItemQuantity(item, quantity),
            ),
            onMove: (item, nextZone) => _mutate(
              () =>
                  ref.read(tcgDeckRepositoryProvider).moveItem(item, nextZone),
            ),
          ),
      ],
    );
  }
}

class _DeckZoneSection extends StatelessWidget {
  final TcgDeckZone zone;
  final TcgDeckZoneRule rule;
  final List<TcgDeckItem> items;
  final List<TcgDeckZone> allZones;
  final bool saving;
  final Future<void> Function(TcgDeckItem item, int quantity) onSetQuantity;
  final Future<void> Function(TcgDeckItem item, TcgDeckZone zone) onMove;

  const _DeckZoneSection({
    required this.zone,
    required this.rule,
    required this.items,
    required this.allZones,
    required this.saving,
    required this.onSetQuantity,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, item) => sum + item.quantity);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          '${zone.label}: $total',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('Esperado: ${rule.describe()}'),
        children: items.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Nenhuma carta nesta zona.'),
                ),
              ]
            : items
                  .map(
                    (item) => ListTile(
                      leading: SizedBox(
                        width: 44,
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.contain,
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: DropdownButton<TcgDeckZone>(
                        value: item.zone,
                        isDense: true,
                        items: allZones
                            .map(
                              (zone) => DropdownMenuItem(
                                value: zone,
                                child: Text(zone.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: saving
                            ? null
                            : (nextZone) {
                                if (nextZone != null) onMove(item, nextZone);
                              },
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Remover uma',
                            onPressed: saving
                                ? null
                                : () => onSetQuantity(item, item.quantity - 1),
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          IconButton(
                            tooltip: 'Adicionar uma',
                            onPressed: saving
                                ? null
                                : () => onSetQuantity(item, item.quantity + 1),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
      ),
    );
  }
}
