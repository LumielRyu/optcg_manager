import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/collection_types.dart';
import '../../data/models/card_record.dart';
import '../../data/repositories/collection_repository.dart';
import 'collection_controller.dart';

class ManualAddDialog extends ConsumerStatefulWidget {
  const ManualAddDialog({super.key});

  @override
  ConsumerState<ManualAddDialog> createState() => _ManualAddDialogState();
}

class _ManualAddDialogState extends ConsumerState<ManualAddDialog> {
  final _codeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  String _destination = CollectionTypes.owned;
  String? _deckName;

  bool _isLoading = false;
  String? _error;

  Future<void> _save() async {
    final code = _codeController.text.trim().toUpperCase();
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

    final repo = ref.read(collectionRepositoryProvider);

    final existing = repo.findByCodeAndCollection(
      cardCode: code,
      collectionType: _destination,
      deckName: _destination == CollectionTypes.deck ? _deckName : null,
    );

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (existing != null) {
        await repo.upsert(
          existing.copyWith(
            quantity: existing.quantity + quantity,
          ),
        );
      } else {
        final newRecord = CardRecord(
          id: _generateId(),
          cardCode: code,
          name: code,
          imageUrl: '',
          dateAddedUtc: DateTime.now(),
          setName: '',
          rarity: '',
          color: '',
          type: '',
          text: '',
          attribute: '',
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
              decoration: const InputDecoration(
                labelText: 'Código da carta',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade',
              ),
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
              decoration: const InputDecoration(
                labelText: 'Destino',
              ),
            ),
            if (_destination == CollectionTypes.deck) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Nome do deck',
                ),
                onChanged: (value) {
                  _deckName = value.trim();
                },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
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