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
  bool _autoScanTriggered = false;

  @override
  void initState() {
    super.initState();
    _selectedDestination =
        CollectionTypes.all.contains(widget.initialDestination)
        ? widget.initialDestination
        : CollectionTypes.owned;

    final source = widget.initialImageSource;

    if (source is Uint8List) {
      _webImageBytes = source;
      Future.microtask(() async {
        await _autoDetectFromBytes(source);
      });
    } else if (source is String && source.isNotEmpty) {
      Future.microtask(() async {
        ref.read(imageImportControllerProvider.notifier).setImagePath(source);
        await _autoDetectFromImage(source);
      });
    }
  }

  @override
  void dispose() {
    _codesController.dispose();
    _deckNameController.dispose();
    super.dispose();
  }

  Future<void> _autoDetectFromImage(String path) async {
    if (_autoScanTriggered) return;
    _autoScanTriggered = true;

    final detected = await ref
        .read(imageImportControllerProvider.notifier)
        .analyzeImagePath(path);

    if (!mounted || detected == null || detected.trim().isEmpty) return;
    _codesController.text = detected;
  }

  Future<void> _autoDetectFromBytes(Uint8List bytes) async {
    if (_autoScanTriggered) return;
    _autoScanTriggered = true;

    final detected = await ref
        .read(imageImportControllerProvider.notifier)
        .analyzeImageBytes(bytes);

    if (!mounted || detected == null || detected.trim().isEmpty) return;
    _codesController.text = detected;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageImportControllerProvider);
    final notifier = ref.read(imageImportControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Importar por imagem')),
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
                if ((widget.initialImageSource is String ||
                        widget.initialImageSource is Uint8List) &&
                    state.detectedInput != null &&
                    state.detectedInput!.trim().isNotEmpty) ...[
                  _InfoBanner(
                    icon: Icons.auto_awesome_outlined,
                    text:
                        'A imagem foi escaneada automaticamente. Revise os codigos detectados antes de importar.',
                  ),
                  const SizedBox(height: 12),
                ] else if (widget.initialImageSource is Uint8List) ...[
                  _InfoBanner(
                    icon: Icons.info_outline,
                    text:
                        'No navegador, a foto agora tambem passa por OCR. Se ainda falhar, revise o debug abaixo e ajuste o enquadramento.',
                    useSecondary: true,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _codesController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText:
                        'Digite ou revise os codigos identificados.\n\n'
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
                _OcrDebugPanel(state: state),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Resultado da analise',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (state.isBusy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
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
                                ? '${item.code} - Quantidade: ${item.quantity}x'
                                : '${item.code} - Nao encontrada - Quantidade: ${item.quantity}x',
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
            label: Text(
              _selectedDestination == CollectionTypes.forSale
                  ? 'Adicionar as cartas a venda'
                  : 'Adicionar a colecao',
            ),
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
          child: Image.memory(_webImageBytes!, fit: BoxFit.contain),
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
        child: Image.file(File(state.imagePath!), fit: BoxFit.contain),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool useSecondary;

  const _InfoBanner({
    required this.icon,
    required this.text,
    this.useSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: useSecondary ? scheme.secondaryContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _OcrDebugPanel extends StatelessWidget {
  final ImageImportState state;

  const _OcrDebugPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDebugInfo =
        (state.debugMessage?.trim().isNotEmpty ?? false) ||
        (state.rawOcrText?.trim().isNotEmpty ?? false) ||
        state.extractedLines.isNotEmpty ||
        (state.detectedInput?.trim().isNotEmpty ?? false);

    if (!hasDebugInfo) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug OCR',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (state.debugMessage?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Status: ${state.debugMessage!}'),
          ],
          if (state.extractedLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Codigos extraidos: ${state.extractedLines.join(', ')}'),
          ],
          if (state.candidateNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Nomes candidatos: ${state.candidateNames.join(', ')}'),
          ],
          if (state.detectedInput?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Entrada normalizada:'),
            const SizedBox(height: 4),
            SelectableText(state.detectedInput!),
          ],
          if (state.candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Cartas resolvidas: ${state.candidates.map((item) => '${item.code}${item.matchedBy == null ? '' : ' (${item.matchedBy})'}').join(', ')}",
            ),
            if (state.candidates.any((item) => item.matchedBy == 'visual+name')) ...[
              const SizedBox(height: 4),
              const Text(
                'O reconhecimento final foi confirmado pela imagem inteira da carta.',
              ),
            ],
          ],
          if (state.rawOcrText?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Texto bruto lido da imagem:'),
            const SizedBox(height: 4),
            SelectableText(state.rawOcrText!),
          ],
        ],
      ),
    );
  }
}

class _ImageImportPreviewCard extends StatelessWidget {
  final String? imageUrl;

  const _ImageImportPreviewCard({required this.imageUrl});

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
