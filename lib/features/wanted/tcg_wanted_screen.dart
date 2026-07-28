import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tcg/tcg_game.dart';
import '../../core/utils/auth_action_guard.dart';
import '../../core/widgets/catalog_grid_card.dart';
import '../../core/widgets/home_navigation_button.dart';
import '../../data/models/tcg_wanted_listing.dart';
import '../../data/repositories/tcg_wanted_repository.dart';

class TcgWantedScreen extends ConsumerStatefulWidget {
  final TcgGame game;
  final String? sharedUserId;

  const TcgWantedScreen({super.key, required this.game, this.sharedUserId});

  @override
  ConsumerState<TcgWantedScreen> createState() => _TcgWantedScreenState();
}

class _TcgWantedScreenState extends ConsumerState<TcgWantedScreen> {
  List<TcgWantedListing> _items = const [];
  bool _loading = true;
  bool _showMine = false;
  String _query = '';
  String? _error;

  bool get _isShared => widget.sharedUserId != null;

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
      final repo = ref.read(tcgWantedRepositoryProvider);
      final items = _isShared
          ? await repo.listPublicByUser(
              gameSlug: widget.game.slug,
              userId: widget.sharedUserId!,
            )
          : _showMine
          ? await repo.listMine(widget.game.slug)
          : await repo.listPublic(widget.game.slug);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  List<TcgWantedListing> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.cardCode.toLowerCase().contains(query) ||
              item.setName.toLowerCase().contains(query) ||
              item.seekerName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> _selectMode(bool showMine) async {
    if (showMine && !requireSignedIn(context)) return;
    setState(() => _showMine = showMine);
    await _load();
  }

  String _shareLink(String userId) {
    final origin = '${Uri.base.scheme}://${Uri.base.authority}';
    return '$origin/#/shared/wanted/${widget.game.slug}/$userId';
  }

  Future<void> _shareMine() async {
    if (!requireSignedIn(context)) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final link = _shareLink(user.id);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link das procuradas copiado.')),
    );
  }

  Future<void> _contact(TcgWantedListing item) async {
    if (!requireSignedIn(context)) return;
    try {
      var contact = item.contactInfo;
      if (contact.trim().isEmpty) {
        contact = await ref
            .read(tcgWantedRepositoryProvider)
            .getPublicContact(item.id);
      }
      final digits = contact.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        throw StateError('Esta busca não possui WhatsApp disponível.');
      }
      final phone = digits.startsWith('55') ? digits : '55$digits';
      final seeker = item.seekerName.trim().isEmpty
          ? 'Olá!'
          : 'Olá, ${item.seekerName}!';
      final note = item.notes.trim().isEmpty
          ? ''
          : '\nObservação da busca: ${item.notes.trim()}';
      final message = Uri.encodeComponent(
        '$seeker Eu tenho ${item.quantity}x ${item.name} '
        '(${item.cardCode}) que você procura.$note',
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

  Future<void> _edit(TcgWantedListing item) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _WantedEditorDialog(item: item),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    final total = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final ownerName = _items
        .map((item) => item.seekerName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');

    return Scaffold(
      appBar: AppBar(
        leading: _isShared
            ? const BackButton()
            : HomeNavigationButton(destinationRoute: '/${widget.game.slug}'),
        title: Text(
          _isShared && ownerName.isNotEmpty
              ? 'Procuradas por $ownerName'
              : 'Procuradas • ${widget.game.label}',
        ),
        actions: [
          if (!_isShared && _showMine)
            IconButton(
              tooltip: 'Compartilhar minhas procuradas',
              onPressed: _shareMine,
              icon: const Icon(Icons.share_outlined),
            ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _isShared
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/${widget.game.slug}/library'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Adicionar pela biblioteca'),
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
                    if (!_isShared) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Comunidade'),
                            icon: Icon(Icons.public),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Minhas procuradas'),
                            icon: Icon(Icons.favorite_outline),
                          ),
                        ],
                        selected: {_showMine},
                        onSelectionChanged: _loading
                            ? null
                            : (value) => _selectMode(value.first),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'Buscar carta, edição ou jogador',
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _query = ''),
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${items.length} cartas diferentes • $total cópias procuradas',
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
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_border, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _query.isNotEmpty
                              ? 'Nenhuma carta corresponde à busca.'
                              : _showMine
                              ? 'Você ainda não cadastrou procuradas de ${widget.game.label}.'
                              : 'Ainda não há procuradas públicas de ${widget.game.label}.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (!_isShared && (_showMine || _items.isEmpty)) ...[
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () =>
                                context.go('/${widget.game.slug}/library'),
                            icon: const Icon(Icons.auto_stories_outlined),
                            label: const Text('Abrir biblioteca'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    final ownItem =
                        Supabase.instance.client.auth.currentUser?.id ==
                        item.ownerUserId;
                    return CatalogGridCard(
                      code: _displayCode(item.cardCode),
                      title: item.name,
                      metadata: [
                        '${item.quantity}x procurada(s)',
                        item.setName,
                        item.seekerName.isEmpty
                            ? 'Jogador da comunidade'
                            : item.seekerName,
                        if (!item.isActive) 'Pausada',
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
                        onPressed: ownItem && _showMine
                            ? () => _edit(item)
                            : () => _contact(item),
                        icon: Icon(
                          ownItem && _showMine
                              ? Icons.edit_outlined
                              : Icons.chat_outlined,
                          size: 17,
                        ),
                        label: Text(
                          ownItem && _showMine ? 'Editar' : 'Eu tenho',
                        ),
                      ),
                      onTap: ownItem && _showMine
                          ? () => _edit(item)
                          : () => _contact(item),
                    );
                  }, childCount: items.length),
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

  String _displayCode(String code) {
    final parts = code.split(':');
    return parts.length >= 3
        ? '${parts[parts.length - 2]}-${parts.last}'
        : code;
  }
}

class _WantedEditorDialog extends ConsumerStatefulWidget {
  final TcgWantedListing item;

  const _WantedEditorDialog({required this.item});

  @override
  ConsumerState<_WantedEditorDialog> createState() =>
      _WantedEditorDialogState();
}

class _WantedEditorDialogState extends ConsumerState<_WantedEditorDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _notes;
  late bool _active;
  late bool _public;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: '${widget.item.quantity}');
    _notes = TextEditingController(text: widget.item.notes);
    _active = widget.item.isActive;
    _public = widget.item.isPublic;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(tcgWantedRepositoryProvider)
          .update(
            id: widget.item.id,
            quantity: int.tryParse(_quantity.text) ?? 1,
            notes: _notes.text,
            isActive: _active,
            isPublic: _public,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await ref.read(tcgWantedRepositoryProvider).delete(widget.item.id);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade procurada',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  hintText: 'Idioma, estado mínimo, versão desejada...',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Busca ativa'),
                value: _active,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exibir para a comunidade'),
                value: _public,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _public = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar'),
        ),
      ],
    );
  }
}
