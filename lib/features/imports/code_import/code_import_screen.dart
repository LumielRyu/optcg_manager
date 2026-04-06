import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import 'code_import_controller.dart';

class CodeImportScreen extends ConsumerStatefulWidget {
  final String initialDestination;

  const CodeImportScreen({
    super.key,
    this.initialDestination = CollectionTypes.owned,
  });

  @override
  ConsumerState<CodeImportScreen> createState() => _CodeImportScreenState();
}

class _CodeImportScreenState extends ConsumerState<CodeImportScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _deckNameController = TextEditingController();

  late String _selectedDestination;
  int _singleCodeQuantity = 1;
  String? _lastHandledSelectionId;

  @override
  void initState() {
    super.initState();
    _selectedDestination = CollectionTypes.all.contains(widget.initialDestination)
        ? widget.initialDestination
        : CollectionTypes.owned;
  }

  @override
  void dispose() {
    _controller.dispose();
    _deckNameController.dispose();
    super.dispose();
  }

  bool get _isSingleCodeMode {
    final text = _controller.text.trim();
    if (text.isEmpty) return false;
    if (text.contains('\n')) return false;
    return !text.toLowerCase().contains('x');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(codeImportControllerProvider);
    final notifier = ref.read(codeImportControllerProvider.notifier);

    final pendingSelection = state.pendingSelection;
    if (pendingSelection != null &&
        pendingSelection.requestId != _lastHandledSelectionId) {
      _lastHandledSelectionId = pendingSelection.requestId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showVariantSelector(pendingSelection);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar por código'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 10,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Use de dois jeitos:\n\n'
                        '1) Lista completa:\n1xOP14-020\n4xEB01-015\n4xST02-007\n\n'
                        '2) Código único:\nOP12-027',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isSingleCodeMode) ...[
                  DropdownButtonFormField<int>(
                    value: _singleCodeQuantity,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade para código único',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(20, (index) => index + 1).map((q) {
                      return DropdownMenuItem<int>(
                        value: q,
                        child: Text('$q'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _singleCodeQuantity = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: _selectedDestination,
                  decoration: const InputDecoration(
                    labelText: 'Destino',
                    border: OutlineInputBorder(),
                  ),
                  items: CollectionTypes.all.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(CollectionTypes.label(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedDestination = value;
                    });
                  },
                ),
                if (_selectedDestination == CollectionTypes.deck) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _deckNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do deck',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () async {
                            _lastHandledSelectionId = null;
                            await notifier.analyzeText(
                              _controller.text,
                              singleCodeQuantity: _singleCodeQuantity,
                            );
                          },
                    icon: const Icon(Icons.search),
                    label: const Text('Analisar código'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.isBusy
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.candidates.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            state.error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : state.candidates.isEmpty
                        ? const Center(
                            child: Text('Nenhuma carta analisada ainda.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: state.candidates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = state.candidates[index];

                              return Card(
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: item.found
                                        ? _ImportPreviewImage(
                                            imageUrl: item.imageUrl,
                                          )
                                        : const Icon(Icons.error_outline),
                                  ),
                                  title: Text(item.name ?? item.code),
                                  subtitle: Text(
                                    item.found
                                        ? '${item.code} • ${item.setName ?? '-'} • ${item.rarity ?? '-'} • Quantidade: ${item.quantity}x'
                                        : '${item.code} • Não encontrada • Quantidade: ${item.quantity}x',
                                  ),
                                  trailing: IconButton(
                                    onPressed: () =>
                                        notifier.removeCandidate(index),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: FilledButton.icon(
            onPressed: state.isBusy || state.candidates.isEmpty
                ? null
                : () async {
                    if (_selectedDestination == CollectionTypes.deck &&
                        _deckNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Digite o nome do deck.'),
                        ),
                      );
                      return;
                    }

                    final error = await notifier.confirmImport(
                      collectionType: _selectedDestination,
                      deckName: _selectedDestination == CollectionTypes.deck
                          ? _deckNameController.text.trim()
                          : null,
                    );

                    if (!mounted) return;

                    if (error == null) {
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                    }
                  },
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('Adicionar à coleção'),
          ),
        ),
      ),
    );
  }

  Future<void> _showVariantSelector(
    CodeImportVariantSelection selection,
  ) async {
    final notifier = ref.read(codeImportControllerProvider.notifier);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: Text('Escolha a versão de ${selection.code}'),
          content: SizedBox(
            width: 760,
            height: 520,
            child: GridView.builder(
              itemCount: selection.options.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (_, index) {
                final option = selection.options[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await notifier.selectVariant(option);
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _ImportPreviewImage(
                              imageUrl: option.imageUrl,
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
                                option.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                option.variantLabel,
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
              onPressed: () async {
                Navigator.of(context).pop();
                await notifier.cancelVariantSelection();
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }
}

class _ImportPreviewImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;

  const _ImportPreviewImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();

    if (url.isEmpty) {
      return const Icon(Icons.image_not_supported_outlined);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) {
          return const Icon(Icons.broken_image_outlined);
        },
      ),
    );
  }
}
