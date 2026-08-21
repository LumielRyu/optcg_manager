import 'package:flutter/material.dart';

import '../../data/models/collection_folder.dart';

const String unfiledCollectionFolderKey = '__unfiled__';

class MoveToFolderResult {
  final String? folderId;
  final int quantity;

  const MoveToFolderResult({required this.folderId, required this.quantity});
}

class MoveToFolderDialog extends StatefulWidget {
  final List<CollectionFolder> folders;
  final String? currentFolderId;
  final int availableQuantity;

  const MoveToFolderDialog({
    super.key,
    required this.folders,
    required this.currentFolderId,
    required this.availableQuantity,
  }) : assert(availableQuantity > 0);

  @override
  State<MoveToFolderDialog> createState() => _MoveToFolderDialogState();
}

class _MoveToFolderDialogState extends State<MoveToFolderDialog> {
  String? _selectedFolderKey;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.availableQuantity;
  }

  String get _currentFolderKey {
    final folderId = widget.currentFolderId?.trim() ?? '';
    return folderId.isEmpty ? unfiledCollectionFolderKey : folderId;
  }

  void _changeQuantity(int delta) {
    setState(() {
      _quantity = (_quantity + delta)
          .clamp(1, widget.availableQuantity)
          .toInt();
    });
  }

  void _submit() {
    final selected = _selectedFolderKey;
    if (selected == null || selected == _currentFolderKey) return;
    Navigator.of(context).pop(
      MoveToFolderResult(
        folderId: selected == unfiledCollectionFolderKey ? null : selected,
        quantity: _quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.availableQuantity;
    final canSubmit =
        _selectedFolderKey != null && _selectedFolderKey != _currentFolderKey;

    return AlertDialog(
      title: const Text('Mover para pasta'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              available == 1
                  ? '1 carta disponível'
                  : '$available cartas disponíveis',
              key: const Key('move-folder-available-quantity'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('move-folder-destination'),
              initialValue: _selectedFolderKey,
              decoration: const InputDecoration(
                labelText: 'Pasta de destino',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: unfiledCollectionFolderKey,
                  enabled: _currentFolderKey != unfiledCollectionFolderKey,
                  child: Text(
                    _currentFolderKey == unfiledCollectionFolderKey
                        ? 'Sem pasta (atual)'
                        : 'Sem pasta',
                  ),
                ),
                for (final folder in widget.folders)
                  DropdownMenuItem(
                    value: folder.id,
                    enabled: folder.id != _currentFolderKey,
                    child: Text(
                      folder.id == _currentFolderKey
                          ? '${folder.name} (atual)'
                          : folder.name,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _selectedFolderKey = value;
              }),
            ),
            const SizedBox(height: 20),
            Text('Quantidade', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  key: const Key('move-folder-decrease'),
                  tooltip: 'Diminuir quantidade',
                  onPressed: _quantity > 1 ? () => _changeQuantity(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 132,
                  child: Text(
                    '$_quantity de $available',
                    key: const Key('move-folder-selected-quantity'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.outlined(
                  key: const Key('move-folder-increase'),
                  tooltip: 'Aumentar quantidade',
                  onPressed: _quantity < available
                      ? () => _changeQuantity(1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (available > 1) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('move-folder-select-all'),
                onPressed: _quantity == available
                    ? null
                    : () => setState(() => _quantity = available),
                child: const Text('Selecionar todas'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: const Key('move-folder-confirm'),
          onPressed: canSubmit ? _submit : null,
          icon: const Icon(Icons.drive_file_move_outline),
          label: Text(
            _quantity == 1 ? 'Mover 1 carta' : 'Mover $_quantity cartas',
          ),
        ),
      ],
    );
  }
}
