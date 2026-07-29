import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tcg/riftbound_text_deck_parser.dart';
import '../../core/tcg/tcg_deck_rules.dart';
import '../../core/tcg/tcg_collection_drafts.dart';
import '../../data/models/riftbound_card.dart';
import '../../data/models/tcg_deck.dart';
import '../../data/repositories/tcg_collection_repository.dart';
import '../../data/repositories/tcg_deck_repository.dart';
import '../../data/services/riftbound_tcg_service.dart';

enum RiftboundTextImportTarget { deck, collection }

class RiftboundTextListImportResult {
  final int totalCards;
  final int differentCards;

  const RiftboundTextListImportResult({
    required this.totalCards,
    required this.differentCards,
  });
}

class RiftboundTextListImportDialog extends ConsumerStatefulWidget {
  final RiftboundTextImportTarget target;
  final TcgDeck? deck;

  const RiftboundTextListImportDialog({
    super.key,
    required this.target,
    this.deck,
  });

  @override
  ConsumerState<RiftboundTextListImportDialog> createState() =>
      _RiftboundTextListImportDialogState();
}

class _RiftboundTextListImportDialogState
    extends ConsumerState<RiftboundTextListImportDialog> {
  final _controller = TextEditingController();
  RiftboundTextDeckParseResult? _parsed;
  Map<String, List<RiftboundCard>> _candidates = const {};
  final Map<String, RiftboundCard> _selected = {};
  bool _replaceDeck = true;
  bool _busy = false;
  String? _error;

  bool get _isDeck => widget.target == RiftboundTextImportTarget.deck;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'A área de transferência não possui texto.');
      return;
    }
    _controller.text = text;
    setState(() {
      _parsed = null;
      _candidates = const {};
      _selected.clear();
      _error = null;
    });
  }

  Future<void> _analyze() async {
    final parsed = parseRiftboundTextDeck(_controller.text);
    if (!parsed.isValid) {
      setState(() {
        _parsed = parsed;
        _error = parsed.errors.join('\n');
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _parsed = parsed;
      _candidates = const {};
      _selected.clear();
    });
    try {
      final candidates = await ref
          .read(riftboundTcgServiceProvider)
          .resolveExactNames(parsed.entries.map((entry) => entry.cardName));
      if (!mounted) return;
      final selected = <String, RiftboundCard>{};
      for (final entry in candidates.entries) {
        if (entry.value.isNotEmpty) selected[entry.key] = entry.value.first;
      }
      setState(() {
        _candidates = candidates;
        _selected.addAll(selected);
        _busy = false;
        final missing = _missingNames(parsed, candidates);
        _error = missing.isEmpty
            ? null
            : 'Não encontrei: ${missing.join(', ')}. Confira a escrita antes de importar.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Não foi possível consultar o catálogo Riftbound: $error';
      });
    }
  }

  List<String> _missingNames(
    RiftboundTextDeckParseResult parsed,
    Map<String, List<RiftboundCard>> candidates,
  ) {
    final missing = <String>[];
    final seen = <String>{};
    for (final entry in parsed.entries) {
      final key = normalizeRiftboundCardName(entry.cardName);
      if ((candidates[key] ?? const []).isEmpty && seen.add(key)) {
        missing.add(entry.cardName);
      }
    }
    return missing;
  }

  Future<void> _import() async {
    final parsed = _parsed;
    if (parsed == null || !parsed.isValid) {
      await _analyze();
      return;
    }
    final uniqueNames = parsed.entries
        .map((entry) => normalizeRiftboundCardName(entry.cardName))
        .toSet();
    if (uniqueNames.any((name) => !_selected.containsKey(name))) {
      setState(() {
        _error =
            'Escolha uma impressão para todas as cartas antes de importar.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isDeck) {
        final deck = widget.deck;
        if (deck == null) {
          throw StateError('Deck de destino não encontrado.');
        }
        await ref
            .read(tcgDeckRepositoryProvider)
            .importEntries(
              deck: deck,
              replaceExisting: _replaceDeck,
              entries: parsed.entries.map((entry) {
                final card =
                    _selected[normalizeRiftboundCardName(entry.cardName)]!;
                return TcgDeckImportEntry(
                  card: card.collectionDraft,
                  quantity: entry.quantity,
                  zone: entry.zone,
                );
              }),
            );
      } else {
        final quantities = <String, int>{};
        final cards = <String, RiftboundCard>{};
        for (final entry in parsed.entries) {
          final card = _selected[normalizeRiftboundCardName(entry.cardName)]!;
          quantities.update(
            card.riftboundId,
            (quantity) => quantity + entry.quantity,
            ifAbsent: () => entry.quantity,
          );
          cards[card.riftboundId] = card;
        }
        final repository = ref.read(tcgCollectionRepositoryProvider);
        for (final item in quantities.entries) {
          await repository.addOrIncrementBy(
            cards[item.key]!.collectionDraft,
            item.value,
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        RiftboundTextListImportResult(
          totalCards: parsed.totalCards,
          differentCards: uniqueNames.length,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Não foi possível importar a lista: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final canImport =
        parsed?.isValid == true &&
        _candidates.isNotEmpty &&
        _missingNames(parsed!, _candidates).isEmpty;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 860),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  const Icon(Icons.content_paste_go_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDeck
                              ? 'Montar deck por lista'
                              : 'Adicionar lista à coleção',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          'Cole o texto copiado do Piltover Archive ou de outra lista compatível.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      enabled: !_busy,
                      minLines: parsed == null ? 13 : 6,
                      maxLines: parsed == null ? 18 : 9,
                      onChanged: (_) {
                        if (_parsed == null) return;
                        setState(() {
                          _parsed = null;
                          _candidates = const {};
                          _selected.clear();
                          _error = null;
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        labelText: 'Lista do deck',
                        hintText:
                            'Legend:\n1 Master Yi, Wuju Bladesman\n\nChampion:\n1 Master Yi, Tempered\n\nMainDeck:\n3 Charm',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _paste,
                        icon: const Icon(Icons.content_paste_outlined),
                        label: const Text('Colar da área de transferência'),
                      ),
                    ),
                    if (_isDeck) ...[
                      SwitchListTile(
                        value: _replaceDeck,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _replaceDeck = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Substituir cartas atuais'),
                        subtitle: const Text(
                          'Desative para somar a lista às cartas que já estão no deck.',
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!),
                      ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                    ] else if (parsed?.isValid == true &&
                        _candidates.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _ImportSummary(parsed: parsed!),
                      const SizedBox(height: 16),
                      Text(
                        'Revise a impressão de cada carta',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'A primeira opção prioriza edições regulares. Você pode trocar para uma promocional ou arte alternativa.',
                      ),
                      const SizedBox(height: 12),
                      for (final name in _uniqueNames(parsed))
                        _CandidateSelector(
                          cardName: name,
                          quantity: _quantityForName(parsed, name),
                          candidates:
                              _candidates[normalizeRiftboundCardName(name)] ??
                              const [],
                          selected: _selected[normalizeRiftboundCardName(name)],
                          onChanged: (card) {
                            if (card == null) return;
                            setState(() {
                              _selected[normalizeRiftboundCardName(name)] =
                                  card;
                            });
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : canImport
                          ? _import
                          : _analyze,
                      icon: Icon(
                        canImport
                            ? Icons.playlist_add_check
                            : Icons.manage_search,
                      ),
                      label: Text(
                        canImport
                            ? _isDeck
                                  ? 'Montar deck'
                                  : 'Adicionar à coleção'
                            : 'Analisar lista',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _uniqueNames(RiftboundTextDeckParseResult parsed) {
    final names = <String, String>{};
    for (final entry in parsed.entries) {
      names.putIfAbsent(
        normalizeRiftboundCardName(entry.cardName),
        () => entry.cardName,
      );
    }
    return names.values.toList(growable: false);
  }

  int _quantityForName(RiftboundTextDeckParseResult parsed, String name) {
    final normalized = normalizeRiftboundCardName(name);
    return parsed.entries
        .where(
          (entry) => normalizeRiftboundCardName(entry.cardName) == normalized,
        )
        .fold(0, (total, entry) => total + entry.quantity);
  }
}

class _ImportSummary extends StatelessWidget {
  final RiftboundTextDeckParseResult parsed;

  const _ImportSummary({required this.parsed});

  @override
  Widget build(BuildContext context) {
    final totals = <TcgDeckZone, int>{};
    for (final entry in parsed.entries) {
      totals.update(
        entry.zone,
        (quantity) => quantity + entry.quantity,
        ifAbsent: () => entry.quantity,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text('${parsed.totalCards} cartas')),
        for (final entry in totals.entries)
          Chip(label: Text('${entry.key.label}: ${entry.value}')),
      ],
    );
  }
}

class _CandidateSelector extends StatelessWidget {
  final String cardName;
  final int quantity;
  final List<RiftboundCard> candidates;
  final RiftboundCard? selected;
  final ValueChanged<RiftboundCard?> onChanged;

  const _CandidateSelector({
    required this.cardName,
    required this.quantity,
    required this.candidates,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 62,
              child: selected == null
                  ? const Icon(Icons.help_outline)
                  : Image.network(
                      selected!.imageUrl,
                      fit: BoxFit.contain,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$quantity× $cardName',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (candidates.isEmpty)
                    Text(
                      'Carta não encontrada',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selected?.ligaLookupCode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Impressão',
                        isDense: true,
                      ),
                      items: candidates
                          .map(
                            (card) => DropdownMenuItem(
                              value: card.ligaLookupCode,
                              child: Text(
                                _candidateLabel(card),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (lookupCode) {
                        if (lookupCode == null) return;
                        onChanged(
                          candidates.firstWhere(
                            (card) => card.ligaLookupCode == lookupCode,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _candidateLabel(RiftboundCard card) {
    final code = card.ligaLookupCode.split(':').last;
    final details = [
      card.setCode.toUpperCase(),
      code,
      card.rarity,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
    return details;
  }
}
