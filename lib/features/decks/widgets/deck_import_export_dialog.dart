import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import '../../../data/models/card_record.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/services/op_api_service.dart';
import '../../collection/collection_controller.dart';

class DeckImportExportDialog extends ConsumerStatefulWidget {
  final String deckName;
  final List<CardRecord> items;

  const DeckImportExportDialog({
    super.key,
    required this.deckName,
    required this.items,
  });

  @override
  ConsumerState<DeckImportExportDialog> createState() =>
      _DeckImportExportDialogState();
}

class _DeckImportExportDialogState
    extends ConsumerState<DeckImportExportDialog> {
  final TextEditingController _importController = TextEditingController();

  bool _replaceExisting = false;
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  String _buildExportText() {
    final sorted = [...widget.items]
      ..sort((a, b) => a.cardCode.compareTo(b.cardCode));

    return sorted.map((e) => '${e.quantity}x${e.cardCode}').join('\n');
  }

  Future<void> _copyExportText(String exportText) async {
    await Clipboard.setData(
      ClipboardData(text: exportText),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lista copiada.'),
      ),
    );
  }

  Future<void> _importList() async {
    final repo = ref.read(collectionRepositoryProvider);
    final api = ref.read(opApiServiceProvider);
    final controller = ref.read(collectionControllerProvider.notifier);

    final raw = _importController.text.trim();

    if (raw.isEmpty) {
      setState(() {
        _error = 'Cole uma lista de cartas para importar.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await api.preload();

      final parsed = _parseLines(raw);

      if (parsed.isEmpty) {
        setState(() {
          _error = 'Nenhuma linha válida encontrada.';
          _isBusy = false;
        });
        return;
      }

      final incomingTotal = parsed.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

      final currentTotal = widget.items.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

      final finalTotal =
          _replaceExisting ? incomingTotal : currentTotal + incomingTotal;

      if (finalTotal > 51) {
        setState(() {
          _error = 'Essa importação ultrapassa o limite de 51 cartas.';
          _isBusy = false;
        });
        return;
      }

      if (_replaceExisting) {
        final idsToDelete = widget.items.map((e) => e.id).toList();
        await repo.deleteManyByIds(idsToDelete);
      }

      for (final entry in parsed) {
        final apiCard = await api.findCardByCode(entry.code);
        if (apiCard == null) {
          continue;
        }

        final existing = repo.findByCodeAndCollection(
          cardCode: apiCard.code,
          collectionType: CollectionTypes.deck,
          deckName: widget.deckName,
        );

        if (existing != null) {
          await repo.upsert(
            existing.copyWith(
              quantity: existing.quantity + entry.quantity,
              name: apiCard.name.isNotEmpty ? apiCard.name : existing.name,
              imageUrl:
                  apiCard.image.isNotEmpty ? apiCard.image : existing.imageUrl,
              setName: apiCard.setName.isNotEmpty
                  ? apiCard.setName
                  : existing.setName,
              rarity:
                  apiCard.rarity.isNotEmpty ? apiCard.rarity : existing.rarity,
              color: apiCard.color.isNotEmpty ? apiCard.color : existing.color,
              type: apiCard.type.isNotEmpty ? apiCard.type : existing.type,
              text: apiCard.text.isNotEmpty ? apiCard.text : existing.text,
              attribute: apiCard.attribute.isNotEmpty
                  ? apiCard.attribute
                  : existing.attribute,
            ),
          );
        } else {
          await repo.upsert(
            CardRecord(
              id: _randomId(),
              cardCode: apiCard.code,
              name: apiCard.name,
              imageUrl: apiCard.image,
              dateAddedUtc: DateTime.now(),
              setName: apiCard.setName,
              rarity: apiCard.rarity,
              color: apiCard.color,
              type: apiCard.type,
              text: apiCard.text,
              attribute: apiCard.attribute,
              quantity: entry.quantity,
              collectionType: CollectionTypes.deck,
              deckName: widget.deckName,
            ),
          );
        }
      }

      await controller.load();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Erro ao importar lista: $e';
        _isBusy = false;
      });
    }
  }

  List<_ParsedDeckLine> _parseLines(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final result = <_ParsedDeckLine>[];

    for (final line in lines) {
      final compact = line.replaceAll(' ', '');

      final match =
          RegExp(r'^(\d+)x([A-Za-z0-9\-]+)$', caseSensitive: false)
              .firstMatch(compact);

      if (match == null) continue;

      final quantity = int.tryParse(match.group(1) ?? '1') ?? 1;
      final code = (match.group(2) ?? '').toUpperCase().trim();

      if (code.isEmpty) continue;

      result.add(
        _ParsedDeckLine(
          quantity: quantity,
          code: code,
        ),
      );
    }

    return result;
  }

  String _randomId() {
    final r = Random();
    return List.generate(20, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  @override
  Widget build(BuildContext context) {
    final exportText = _buildExportText();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 720,
          maxHeight: 820,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Text(
                    'Importar / Exportar Deck',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(widget.deckName),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Exportar lista atual',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: exportText),
                      minLines: 6,
                      maxLines: 10,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _copyExportText(exportText),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar'),
                      ),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'Importar para este deck',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _importController,
                      minLines: 8,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        hintText: 'Exemplo:\n4xOP01-077\n2xOP02-036\n1xOP09-062',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _replaceExisting,
                      onChanged: _isBusy
                          ? null
                          : (value) {
                              setState(() {
                                _replaceExisting = value;
                              });
                            },
                      title: const Text('Substituir deck atual'),
                      subtitle: const Text(
                        'Se ativado, remove as cartas atuais do deck antes de importar.',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isBusy ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isBusy ? null : _importList,
                      icon: _isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.playlist_add_check),
                      label: const Text('Importar'),
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
}

class _ParsedDeckLine {
  final int quantity;
  final String code;

  _ParsedDeckLine({
    required this.quantity,
    required this.code,
  });
}