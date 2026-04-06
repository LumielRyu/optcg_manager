import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/collection_types.dart';
import '../../data/models/card_record.dart';
import '../../data/models/op_card.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/services/op_api_service.dart';
import 'collection_controller.dart';

class ManualAddDialog extends ConsumerStatefulWidget {
  final String initialDestination;

  const ManualAddDialog({
    super.key,
    this.initialDestination = CollectionTypes.owned,
  });

  @override
  ConsumerState<ManualAddDialog> createState() => _ManualAddDialogState();
}

class _ManualAddDialogState extends ConsumerState<ManualAddDialog> {
  final _codeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  late String _destination;
  String? _deckName;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _destination = CollectionTypes.all.contains(widget.initialDestination)
        ? widget.initialDestination
        : CollectionTypes.owned;
  }

  Future<void> _save() async {
    final api = ref.read(opApiServiceProvider);
    final repo = ref.read(collectionRepositoryProvider);

    final code = api.normalizeCode(_codeController.text);
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    if (code.isEmpty) {
      setState(() => _error = 'Informe o código da carta');
      return;
    }

    if (_destination == CollectionTypes.deck &&
        (_deckName == null || _deckName!.trim().isEmpty)) {
      setState(() => _error = 'Informe o nome do deck');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await api.preload();
      final variants = await api.findAllByCode(code);

      if (variants.isEmpty) {
        setState(() {
          _error = 'Carta não encontrada para o código informado.';
          _isLoading = false;
        });
        return;
      }

      OpCard? selectedCard;

      if (variants.length == 1) {
        selectedCard = variants.first;
      } else {
        selectedCard = await _showVariantSelector(variants);
      }

      if (selectedCard == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final existing = repo.findByCodeAndCollection(
        cardCode: selectedCard.code,
        collectionType: _destination,
        deckName: _destination == CollectionTypes.deck ? _deckName : null,
        imageUrl: selectedCard.image,
      );

      if (existing != null) {
        await repo.upsert(
          existing.copyWith(
            quantity: existing.quantity + quantity,
            name: selectedCard.name,
            imageUrl: selectedCard.image,
            setName: selectedCard.setName,
            rarity: selectedCard.rarity,
            color: selectedCard.color,
            type: selectedCard.type,
            text: selectedCard.text,
            attribute: selectedCard.attribute,
          ),
        );
      } else {
        final newRecord = CardRecord(
          id: _generateId(),
          cardCode: selectedCard.code,
          name: selectedCard.name,
          imageUrl: selectedCard.image,
          dateAddedUtc: DateTime.now(),
          setName: selectedCard.setName,
          rarity: selectedCard.rarity,
          color: selectedCard.color,
          type: selectedCard.type,
          text: selectedCard.text,
          attribute: selectedCard.attribute,
          quantity: quantity,
          collectionType: _destination,
          deckName: _destination == CollectionTypes.deck ? _deckName : null,
        );

        await repo.upsert(newRecord);
      }

      await ref.read(collectionControllerProvider.notifier).load();

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _error = 'Erro ao salvar carta';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<OpCard?> _showVariantSelector(List<OpCard> variants) async {
    return showDialog<OpCard>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolha a versão da carta'),
          content: SizedBox(
            width: 760,
            height: 520,
            child: GridView.builder(
              itemCount: variants.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (_, index) {
                final card = variants[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(card),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _VariantPreviewImage(
                              imageUrl: card.image,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _variantLabel(card),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  String _variantLabel(OpCard card) {
    final parts = <String>[
      if (card.setName.trim().isNotEmpty) card.setName.trim(),
      if (card.rarity.trim().isNotEmpty) card.rarity.trim(),
    ];

    if (parts.isEmpty) return 'Versão alternativa';
    return parts.join(' • ');
  }

  String _generateId() {
    final random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(9999).toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar carta manualmente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Código da carta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _destination,
              items: CollectionTypes.all.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(CollectionTypes.label(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _destination = value!;
                });
              },
              decoration: const InputDecoration(labelText: 'Destino'),
            ),
            if (_destination == CollectionTypes.deck) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Nome do deck'),
                onChanged: (value) {
                  _deckName = value.trim();
                },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _VariantPreviewImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const _VariantPreviewImage({required this.imageUrl, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const Icon(Icons.image_not_supported_outlined);
    }

    return Image.network(
      imageUrl,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, __, ___) {
        return const Icon(Icons.broken_image_outlined);
      },
    );
  }
}
