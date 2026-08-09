import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/collection_types.dart';
import '../../data/models/card_record.dart';
import '../../data/models/collection_folder.dart';
import '../../data/models/op_card.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/services/op_api_service.dart';
import 'collection_controller.dart';

class ManualAddDialog extends ConsumerStatefulWidget {
  final String initialDestination;
  final String? initialFolderId;
  final List<CollectionFolder> folders;

  const ManualAddDialog({
    super.key,
    this.initialDestination = CollectionTypes.owned,
    this.initialFolderId,
    this.folders = const [],
  });

  @override
  ConsumerState<ManualAddDialog> createState() => _ManualAddDialogState();
}

class _ManualAddDialogState extends ConsumerState<ManualAddDialog> {
  static const List<String> _manualColors = <String>[
    'Black',
    'Blue',
    'Green',
    'Purple',
    'Red',
    'Yellow',
  ];

  final _codeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _manualNameController = TextEditingController();

  late String _destination;
  String? _deckName;
  String? _manualColor;
  String? _folderId;

  bool _isLoading = false;
  bool _isLookingUp = false;
  bool _manualFallbackEnabled = false;
  String? _error;
  String? _lookupMessage;
  String _lookupQuery = '';
  List<OpCard> _lookupVariants = const [];
  OpCard? _selectedCard;
  Timer? _lookupDebounce;

  @override
  void initState() {
    super.initState();
    _destination = CollectionTypes.all.contains(widget.initialDestination)
        ? widget.initialDestination
        : CollectionTypes.owned;
    _folderId = widget.initialFolderId;
    _codeController.addListener(_scheduleLookup);
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _codeController.dispose();
    _quantityController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  void _scheduleLookup() {
    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(const Duration(milliseconds: 550), _lookupCard);
  }

  Future<void> _lookupCard() async {
    final api = ref.read(opApiServiceProvider);
    final query = _codeController.text.trim();
    final normalizedQuery = query.toLowerCase();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _lookupQuery = '';
        _lookupVariants = const [];
        _selectedCard = null;
        _lookupMessage = null;
        _isLookingUp = false;
      });
      return;
    }

    setState(() {
      _isLookingUp = true;
      _lookupMessage = null;
      _manualFallbackEnabled = false;
    });
    try {
      await api.preload();
      final code = api.normalizeCode(query);
      var variants = await api.findAllByCode(code);
      final foundByName = variants.isEmpty;
      if (foundByName && query.length >= 2) {
        variants = await api.searchCardsByName(query, limit: 40);
      }
      if (!mounted ||
          _codeController.text.trim().toLowerCase() != normalizedQuery) {
        return;
      }
      setState(() {
        _lookupQuery = normalizedQuery;
        _lookupVariants = variants;
        _selectedCard = variants.length == 1 ? variants.first : null;
        _lookupMessage = variants.isEmpty
            ? 'Nenhuma carta encontrada na biblioteca.'
            : variants.length == 1
            ? 'Carta encontrada. Confira a imagem antes de adicionar.'
            : foundByName
            ? '${variants.length} resultados encontrados. Escolha a carta e a arte corretas.'
            : '${variants.length} versões encontradas. Escolha a imagem correta.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lookupQuery = normalizedQuery;
        _lookupVariants = const [];
        _selectedCard = null;
        _lookupMessage = 'Não foi possível consultar a biblioteca agora.';
      });
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  Future<void> _save() async {
    final api = ref.read(opApiServiceProvider);
    final repo = ref.read(collectionRepositoryProvider);

    final query = _codeController.text.trim();
    final manualCode = api.normalizeCode(query);
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    if (query.isEmpty) {
      setState(() => _error = 'Informe o código ou o nome da carta.');
      return;
    }

    if (quantity <= 0) {
      setState(() => _error = 'Informe uma quantidade válida.');
      return;
    }

    if (_destination == CollectionTypes.deck &&
        (_deckName == null || _deckName!.trim().isEmpty)) {
      setState(() => _error = 'Informe o nome do deck.');
      return;
    }

    if (_manualFallbackEnabled) {
      if (_manualNameController.text.trim().isEmpty) {
        setState(() => _error = 'Informe o nome da carta.');
        return;
      }
      if ((_manualColor ?? '').trim().isEmpty) {
        setState(() => _error = 'Informe a cor da carta.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await api.preload();
      var variants = _lookupQuery == query.toLowerCase()
          ? _lookupVariants
          : const <OpCard>[];
      if (variants.isEmpty) {
        variants = await api.findAllByCode(manualCode);
      }
      if (variants.isEmpty && query.length >= 2) {
        variants = await api.searchCardsByName(query, limit: 40);
      }

      if (variants.isEmpty) {
        if (!_manualFallbackEnabled) {
          setState(() {
            _manualFallbackEnabled = true;
            _isLoading = false;
            _error =
                'Carta não encontrada na base. Preencha ao menos nome e cor para cadastrar manualmente.';
          });
          return;
        }

        await _saveManualCard(
          repo: repo,
          code: manualCode,
          quantity: quantity,
        );

        await ref.read(collectionControllerProvider.notifier).load();
        if (mounted) Navigator.of(context).pop();
        return;
      }

      OpCard? selectedCard = _selectedCard != null &&
              variants.any(
                (card) =>
                    card.code == _selectedCard!.code &&
                    card.image == _selectedCard!.image,
              )
          ? _selectedCard
          : null;

      if (selectedCard != null) {
        // A versão já foi conferida na prévia da biblioteca.
      } else if (variants.length == 1) {
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
        folderId: _folderId,
        matchFolder: _destination == CollectionTypes.owned,
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
          folderId: _destination == CollectionTypes.owned ? _folderId : null,
        );

        await repo.upsert(newRecord);
      }

      await ref.read(collectionControllerProvider.notifier).load();

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _error = 'Erro ao salvar carta.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveManualCard({
    required CollectionRepository repo,
    required String code,
    required int quantity,
  }) async {
    final manualName = _manualNameController.text.trim();
    final manualColor = _manualColor!.trim();

    final existing = repo.findByCodeAndCollection(
      cardCode: code,
      collectionType: _destination,
      deckName: _destination == CollectionTypes.deck ? _deckName : null,
      imageUrl: '',
      folderId: _folderId,
      matchFolder: _destination == CollectionTypes.owned,
    );

    if (existing != null) {
      await repo.upsert(
        existing.copyWith(
          quantity: existing.quantity + quantity,
          name: manualName,
          color: manualColor,
        ),
      );
      return;
    }

    await repo.upsert(
      CardRecord(
        id: _generateId(),
        cardCode: code,
        name: manualName,
        imageUrl: '',
        dateAddedUtc: DateTime.now(),
        setName: '',
        rarity: '',
        color: manualColor,
        type: '',
        text: '',
        attribute: '',
        quantity: quantity,
        collectionType: _destination,
        deckName: _destination == CollectionTypes.deck ? _deckName : null,
        folderId: _destination == CollectionTypes.owned ? _folderId : null,
      ),
    );
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
      title: const Text('Importar carta pela biblioteca'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Código ou nome da carta',
                hintText: 'Ex.: OP02-001 ou Nami',
                helperText:
                    'Pesquise pelo código ou nome e escolha a arte correta.',
              ),
            ),
            if (_isLookingUp) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_lookupMessage != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_lookupMessage!),
              ),
            ],
            if (_lookupVariants.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 238,
                width: 520,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _lookupVariants.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final card = _lookupVariants[index];
                    final selected = identical(card, _selectedCard);
                    return SizedBox(
                      width: 142,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: InkWell(
                          onTap: () => setState(() => _selectedCard = card),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _VariantPreviewImage(
                                    imageUrl: card.image,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  card.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${card.code} • ${_variantLabel(card)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                if (selected)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Selecionada',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _destination,
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
            if (_destination == CollectionTypes.owned) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _folderId ?? '',
                decoration: const InputDecoration(labelText: 'Pasta'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Sem pasta')),
                  for (final folder in widget.folders)
                    DropdownMenuItem(
                      value: folder.id,
                      child: Text(folder.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _folderId = (value ?? '').isEmpty ? null : value;
                  });
                },
              ),
            ],
            if (_destination == CollectionTypes.forSale) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cartas adicionadas em vendas só aparecem no marketplace depois de publicar/ativar o anúncio. Quando ativado, ele fica visível por 7 dias e precisa ser renovado depois.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_destination == CollectionTypes.deck) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Nome do deck'),
                onChanged: (value) {
                  _deckName = value.trim();
                },
              ),
            ],
            if (_manualFallbackEnabled) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Cadastro manual',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualNameController,
                decoration: const InputDecoration(labelText: 'Nome da carta'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _manualColor,
                decoration: const InputDecoration(labelText: 'Cor da carta'),
                items: _manualColors.map((color) {
                  return DropdownMenuItem<String>(
                    value: color,
                    child: Text(color),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _manualColor = value;
                  });
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
              : Text(
                  _manualFallbackEnabled
                      ? 'Salvar manualmente'
                      : 'Adicionar à coleção',
                ),
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
      errorBuilder: (_, _, _) {
        return const Icon(Icons.broken_image_outlined);
      },
    );
  }
}
