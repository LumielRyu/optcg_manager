import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import 'image_import_controller.dart';

class ImageImportScreen extends ConsumerStatefulWidget {
  final Object? initialImageSource;
  final String initialDestination;

  const ImageImportScreen({
    super.key,
    this.initialImageSource,
    this.initialDestination = CollectionTypes.owned,
  });

  @override
  ConsumerState<ImageImportScreen> createState() => _ImageImportScreenState();
}

class _ImageImportScreenState extends ConsumerState<ImageImportScreen> {
  final TextEditingController _codesController = TextEditingController();
  final TextEditingController _deckNameController = TextEditingController();

  late String _selectedDestination;
  Uint8List? _webImageBytes;

  @override
  void initState() {
    super.initState();
    _selectedDestination = CollectionTypes.all.contains(widget.initialDestination)
        ? widget.initialDestination
        : CollectionTypes.owned;

    final source = widget.initialImageSource;

    if (source is Uint8List) {
      _webImageBytes = source;
    } else if (source is String && source.isNotEmpty) {
      Future.microtask(() {
        ref.read(imageImportControllerProvider.notifier).setImagePath(source);
      });
    }
  }

  @override
  void dispose() {
    _codesController.dispose();
    _deckNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageImportControllerProvider);
    final notifier = ref.read(imageImportControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar por imagem'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildImagePreview(state),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codesController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText:
                        'Digite ou cole os códigos identificados.\n\n'
                        'Exemplo:\n'
                        '1xOP12-027\n'
                        '2xOP09-062',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
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
                            await notifier.analyzeCodes(_codesController.text);
                          },
                    icon: const Icon(Icons.search),
                    label: const Text('Analisar e importar cartas'),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Resultado da análise',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.isBusy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.error != null && state.error!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (state.candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nenhuma carta analisada ainda.'),
                  )
                else
                  ...state.candidates.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          leading: SizedBox(
                            width: 52,
                            height: 52,
                            child: item.found
                                ? _ImageImportPreviewCard(
                                    imageUrl: item.imageUrl,
                                  )
                                : const Icon(Icons.error_outline),
                          ),
                          title: Text(item.name ?? item.code),
                          subtitle: Text(
                            item.found
                                ? '${item.code} • Quantidade: ${item.quantity}x'
                                : '${item.code} • Não encontrada • Quantidade: ${item.quantity}x',
                          ),
                          trailing: IconButton(
                            onPressed: () => notifier.removeCandidate(index),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
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

  Widget _buildImagePreview(ImageImportState state) {
    if (kIsWeb) {
      if (_webImageBytes == null) {
        return const Center(
          child: Text(
            'Selecione uma imagem',
            style: TextStyle(color: Colors.white),
          ),
        );
      }

      return InteractiveViewer(
        child: Center(
          child: Image.memory(
            _webImageBytes!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (state.imagePath == null || state.imagePath!.isEmpty) {
      return const Center(
        child: Text(
          'Selecione uma imagem',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return InteractiveViewer(
      child: Center(
        child: Image.file(
          File(state.imagePath!),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _ImageImportPreviewCard extends StatelessWidget {
  final String? imageUrl;

  const _ImageImportPreviewCard({
    required this.imageUrl,
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
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) {
          return const Icon(Icons.broken_image_outlined);
        },
      ),
    );
  }
}
