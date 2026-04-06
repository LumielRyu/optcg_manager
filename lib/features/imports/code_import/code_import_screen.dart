import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import '../../../core/widgets/home_navigation_button.dart';
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
  static const List<String> _manualColorOptions = [
    'Black',
    'Blue',
    'Green',
    'Purple',
    'Red',
    'Yellow',
  ];

  final TextEditingController _controller = TextEditingController();
  final TextEditingController _deckNameController = TextEditingController();

  late String _selectedDestination;
  int _singleCodeQuantity = 1;
  String? _lastHandledSelectionId;

  @override
  void initState() {
    super.initState();
    _selectedDestination =
        CollectionTypes.all.contains(widget.initialDestination)
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
        actions: const [HomeNavigationButton()],
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
                    hintText:
                        'Use de dois jeitos:\n\n'
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
                      return DropdownMenuItem<int>(value: q, child: Text('$q'));
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
                    return DropdownMenuItem<String>(
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
                      child: Text(state.error!, textAlign: TextAlign.center),
                    ),
                  )
                : state.candidates.isEmpty
                ? const Center(child: Text('Nenhuma carta analisada ainda.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _CodeCandidateCard(
                        candidate: state.candidates[index],
                        colorOptions: _manualColorOptions,
                        onRemove: () => notifier.removeCandidate(index),
                        onNameChanged: (value) => notifier.updateManualCandidate(
                          index,
                          name: value,
                          color: state.candidates[index].color,
                        ),
                        onColorChanged: (value) => notifier.updateManualCandidate(
                          index,
                          name: state.candidates[index].name,
                          color: value,
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
                    final invalidManual = state.candidates.any(
                      (item) => !item.found && !item.canImport,
                    );

                    if (invalidManual) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Preencha nome e cor das cartas não encontradas antes de importar.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (_selectedDestination == CollectionTypes.deck &&
                        _deckNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Digite o nome do deck.')),
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
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

class _CodeCandidateCard extends StatelessWidget {
  final CodeImportCandidate candidate;
  final List<String> colorOptions;
  final VoidCallback onRemove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String?> onColorChanged;

  const _CodeCandidateCard({
    required this.candidate,
    required this.colorOptions,
    required this.onRemove,
    required this.onNameChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 56,
                height: 56,
                child: candidate.found
                    ? _ImportPreviewImage(imageUrl: candidate.imageUrl)
                    : const Icon(Icons.edit_note_outlined),
              ),
              title: Text(
                (candidate.name?.trim().isNotEmpty ?? false)
                    ? candidate.name!.trim()
                    : candidate.code,
              ),
              subtitle: Text(
                candidate.found
                    ? '${candidate.code} • ${candidate.setName ?? '-'} • ${candidate.rarity ?? '-'} • Quantidade: ${candidate.quantity}x'
                    : '${candidate.code} • Carta não encontrada • Quantidade: ${candidate.quantity}x',
              ),
              trailing: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
            if (!candidate.found) ...[
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: candidate.name ?? '')
                  ..selection = TextSelection.collapsed(
                    offset: (candidate.name ?? '').length,
                  ),
                decoration: const InputDecoration(
                  labelText: 'Nome da carta',
                  border: OutlineInputBorder(),
                ),
                onChanged: onNameChanged,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: colorOptions.contains(candidate.color) ? candidate.color : null,
                decoration: const InputDecoration(
                  labelText: 'Cor da carta',
                  border: OutlineInputBorder(),
                ),
                items: colorOptions.map((color) {
                  return DropdownMenuItem<String>(
                    value: color,
                    child: Text(color),
                  );
                }).toList(),
                onChanged: onColorChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportPreviewImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;

  const _ImportPreviewImage({required this.imageUrl, this.fit = BoxFit.cover});

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
