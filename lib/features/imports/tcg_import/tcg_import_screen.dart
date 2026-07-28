import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/tcg/tcg_game.dart';
import '../../../core/widgets/home_navigation_button.dart';
import '../../../core/widgets/tcg_collection_add_button.dart';
import '../../../core/widgets/tcg_wanted_add_button.dart';
import '../../../data/models/tcg_collection_item.dart';
import '../image_import/card_ocr_service.dart';
import 'tcg_catalog_search_service.dart';
import 'tcg_ocr_search_hint.dart';

class TcgImportScreen extends ConsumerStatefulWidget {
  final TcgGame game;

  const TcgImportScreen({super.key, required this.game});

  @override
  ConsumerState<TcgImportScreen> createState() => _TcgImportScreenState();
}

class _TcgImportScreenState extends ConsumerState<TcgImportScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CardOcrService _ocr = CardOcrService();
  final Map<String, int> _selectedVariant = {};

  List<TcgImportCandidate> _candidates = const [];
  Uint8List? _imageBytes;
  String _ocrText = '';
  bool _searching = false;
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 92);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final text = kIsWeb
          ? await _ocr.readTextFromBytes(bytes)
          : await _ocr.readTextFromFile(file.path);
      final hint = TcgOcrSearchHint.extract(text, widget.game);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _ocrText = text.trim();
        if (hint.isNotEmpty) _queryController.text = hint;
      });
      if (hint.isNotEmpty) {
        await _search();
      } else {
        setState(() {
          _error =
              'O OCR não encontrou um nome ou código confiável. '
              'Digite o nome da carta para pesquisar.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível ler a imagem: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 2 || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
      _candidates = const [];
      _selectedVariant.clear();
    });
    try {
      final candidates = await ref
          .read(tcgCatalogSearchServiceProvider)
          .search(widget.game, query);
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _searching = false;
        if (candidates.isEmpty) {
          _error =
              'Nenhuma carta encontrada. Tente o nome completo ou outro código.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Falha ao consultar o catálogo ${widget.game.label}: $error';
      });
    }
  }

  TcgCollectionDraft _selectedDraft(TcgImportCandidate candidate) {
    final index = _selectedVariant[candidate.id] ?? 0;
    return candidate.variants[index.clamp(0, candidate.variants.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: HomeNavigationButton(destinationRoute: '/${widget.game.slug}'),
        title: Text('Importar e escanear • ${widget.game.label}'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'O scanner usa OCR para sugerir uma busca. '
                              'Confirme a carta e a impressão antes de adicionar; '
                              'o reconhecimento visual automático permanece exclusivo '
                              'do fluxo One Piece.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_imageBytes != null) ...[
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _scanning
                            ? null
                            : () => _pickAndScan(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Usar câmera'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _scanning
                            ? null
                            : () => _pickAndScan(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Escolher imagem'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: 'Nome ou código da carta',
                      hintText: _hintFor(widget.game),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Pesquisar',
                        onPressed: _searching ? null : _search,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                  if (_scanning || _searching) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    Text(
                      _scanning
                          ? 'Lendo a imagem...'
                          : 'Consultando o catálogo...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                  if (_ocrText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Texto reconhecido na imagem'),
                      subtitle: const Text(
                        'Use este texto para revisar a sugestão do scanner.',
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(_ocrText),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _candidates.isEmpty
                        ? 'Resultados'
                        : '${_candidates.length} resultado(s) para confirmar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_candidates.isEmpty && !_searching)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.document_scanner_outlined, size: 64),
                      const SizedBox(height: 14),
                      Text(
                        'Fotografe uma carta ou pesquise pelo nome/código.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final candidate = _candidates[index];
                  final draft = _selectedDraft(candidate);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Image.network(
                              candidate.imageUrl,
                              fit: BoxFit.contain,
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.prefer,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            candidate.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          if (candidate.variants.length > 1)
                            DropdownButtonFormField<int>(
                              initialValue: _selectedVariant[candidate.id] ?? 0,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Impressão',
                                isDense: true,
                              ),
                              items: [
                                for (
                                  var variantIndex = 0;
                                  variantIndex < candidate.variants.length;
                                  variantIndex++
                                )
                                  DropdownMenuItem(
                                    value: variantIndex,
                                    child: Text(
                                      _variantLabel(
                                        candidate.variants[variantIndex],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) => setState(
                                () =>
                                    _selectedVariant[candidate.id] = value ?? 0,
                              ),
                            )
                          else
                            Text(
                              _variantLabel(draft),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 8),
                          TcgCollectionAddButton(
                            key: ValueKey(
                              'collection-${candidate.id}-${draft.variantId}',
                            ),
                            draft: draft,
                            gameLabel: widget.game.label,
                            collectionRoute: '/${widget.game.slug}/collection',
                          ),
                          const SizedBox(height: 6),
                          TcgWantedAddButton(
                            key: ValueKey(
                              'wanted-${candidate.id}-${draft.variantId}',
                            ),
                            draft: draft,
                            gameLabel: widget.game.label,
                            wantedRoute: '/${widget.game.slug}/wanted',
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: _candidates.length),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 290,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.48,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _hintFor(TcgGame game) {
    return switch (game) {
      TcgGame.pokemon => 'Ex.: Pikachu ou SV1-025',
      TcgGame.digimon => 'Ex.: Agumon ou BT14-001',
      TcgGame.magic => 'Ex.: Lightning Bolt ou e:lea cn:161',
      TcgGame.riftbound => 'Ex.: nome da carta ou código da edição',
      TcgGame.yugioh => 'Ex.: Dark Magician',
      TcgGame.onePiece => 'Ex.: Nami ou OP01-016',
    };
  }

  String _variantLabel(TcgCollectionDraft draft) {
    return [
      draft.cardCode,
      draft.setName,
      draft.rarity,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
  }
}
