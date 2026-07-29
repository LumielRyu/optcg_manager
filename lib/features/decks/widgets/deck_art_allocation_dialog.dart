import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import '../../../data/models/card_record.dart';
import '../../../data/models/op_card.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/services/op_api_service.dart';
import '../../collection/collection_controller.dart';

class DeckArtAllocationDialog extends ConsumerStatefulWidget {
  final String deckName;
  final String cardCode;
  final List<CardRecord> currentItems;

  const DeckArtAllocationDialog({
    super.key,
    required this.deckName,
    required this.cardCode,
    required this.currentItems,
  });

  @override
  ConsumerState<DeckArtAllocationDialog> createState() =>
      _DeckArtAllocationDialogState();
}

class _DeckArtAllocationDialogState
    extends ConsumerState<DeckArtAllocationDialog> {
  late Future<List<_DeckArtVariant>> _variantsFuture;
  final Map<String, int> _quantities = {};
  bool _saving = false;
  String? _error;

  int get _requiredTotal =>
      widget.currentItems.fold<int>(0, (sum, item) => sum + item.quantity);

  int get _allocatedTotal =>
      _quantities.values.fold<int>(0, (sum, quantity) => sum + quantity);

  @override
  void initState() {
    super.initState();
    _variantsFuture = _loadVariants();
  }

  Future<List<_DeckArtVariant>> _loadVariants() async {
    final apiVariants = await ref
        .read(opApiServiceProvider)
        .findAllByCode(widget.cardCode);
    final variantsByKey = <String, _DeckArtVariant>{};

    for (final card in apiVariants) {
      final variant = _DeckArtVariant.fromOpCard(card);
      variantsByKey.putIfAbsent(variant.key, () => variant);
    }

    for (final item in widget.currentItems) {
      final variant = _DeckArtVariant.fromRecord(item);
      variantsByKey.putIfAbsent(variant.key, () => variant);
      _quantities.update(
        variant.key,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    final variants = variantsByKey.values.toList(growable: false);
    variants.sort((a, b) {
      final aSelected = (_quantities[a.key] ?? 0) > 0 ? 0 : 1;
      final bSelected = (_quantities[b.key] ?? 0) > 0 ? 0 : 1;
      final selectedComparison = aSelected.compareTo(bSelected);
      if (selectedComparison != 0) return selectedComparison;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return variants;
  }

  void _changeQuantity(_DeckArtVariant variant, int delta) {
    if (_saving) return;
    final current = _quantities[variant.key] ?? 0;
    final next = (current + delta).clamp(0, _requiredTotal);
    if (delta > 0 && _allocatedTotal >= _requiredTotal) return;
    setState(() {
      _quantities[variant.key] = next;
      _error = null;
    });
  }

  Future<void> _save(List<_DeckArtVariant> variants) async {
    if (_allocatedTotal != _requiredTotal) {
      setState(() {
        _error =
            'Distribua exatamente $_requiredTotal cópias. '
            'Ainda faltam ${_requiredTotal - _allocatedTotal}.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repository = ref.read(collectionRepositoryProvider);
      final existingByKey = <String, List<CardRecord>>{};
      for (final item in widget.currentItems) {
        final key = _DeckArtVariant.keyFor(item.imageUrl, fallback: item.id);
        existingByKey.putIfAbsent(key, () => []).add(item);
      }

      final deletions = <String>[];
      final upserts = <CardRecord>[];

      for (final variant in variants) {
        final quantity = _quantities[variant.key] ?? 0;
        final existing = existingByKey.remove(variant.key) ?? const [];
        if (quantity == 0) {
          deletions.addAll(existing.map((item) => item.id));
          continue;
        }

        final base = existing.isNotEmpty ? existing.first : null;
        if (existing.length > 1) {
          deletions.addAll(existing.skip(1).map((item) => item.id));
        }
        upserts.add(
          CardRecord(
            id: base?.id ?? _temporaryId(),
            cardCode: widget.cardCode,
            name: variant.name,
            imageUrl: variant.imageUrl,
            dateAddedUtc: base?.dateAddedUtc ?? DateTime.now(),
            setName: variant.setName,
            rarity: variant.rarity,
            color: variant.color,
            type: variant.type,
            text: variant.text,
            attribute: variant.attribute,
            quantity: quantity,
            collectionType: CollectionTypes.deck,
            deckName: widget.deckName,
            isFavorite: base?.isFavorite ?? false,
          ),
        );
      }

      for (final remaining in existingByKey.values) {
        deletions.addAll(remaining.map((item) => item.id));
      }

      if (upserts.isNotEmpty) {
        await repository.upsertMany(upserts);
      }
      if (deletions.isNotEmpty) {
        await repository.deleteManyByIds(deletions);
      }
      await ref.read(collectionControllerProvider.notifier).load();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não foi possível salvar a distribuição: $error';
      });
    }
  }

  String _temporaryId() {
    final random = Random();
    return List.generate(
      24,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 840),
        child: FutureBuilder<List<_DeckArtVariant>>(
          future: _variantsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _LoadError(error: snapshot.error);
            }

            final variants = snapshot.data ?? const [];
            if (variants.isEmpty) {
              return const _LoadError(
                error: 'Nenhuma arte encontrada para esta carta.',
              );
            }

            final remaining = _requiredTotal - _allocatedTotal;
            final colors = Theme.of(context).colorScheme;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    children: [
                      Text(
                        'Distribuir artes • ${widget.cardCode}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Escolha quantas das $_requiredTotal cópias usam cada '
                        'arte. O total da carta no deck não será alterado.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: remaining == 0
                              ? colors.primaryContainer
                              : colors.errorContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          remaining == 0
                              ? '$_allocatedTotal / $_requiredTotal distribuídas'
                              : 'Faltam $remaining de $_requiredTotal cópias',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.52,
                        ),
                    itemCount: variants.length,
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final quantity = _quantities[variant.key] ?? 0;
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: variant.imageUrl.isEmpty
                                      ? const ColoredBox(
                                          color: Colors.black12,
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                          ),
                                        )
                                      : Image.network(
                                          variant.imageUrl,
                                          fit: BoxFit.contain,
                                          webHtmlElementStrategy:
                                              WebHtmlElementStrategy.prefer,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                                color: Colors.black12,
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                              ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                variant.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Diminuir',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: quantity == 0
                                        ? null
                                        : () => _changeQuantity(variant, -1),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${quantity}x',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Aumentar',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _allocatedTotal >= _requiredTotal
                                        ? null
                                        : () => _changeQuantity(variant, 1),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving || remaining != 0
                              ? null
                              : () => _save(variants),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.palette_outlined),
                          label: const Text('Salvar distribuição'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeckArtVariant {
  final String key;
  final String label;
  final String name;
  final String imageUrl;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String text;
  final String attribute;

  const _DeckArtVariant({
    required this.key,
    required this.label,
    required this.name,
    required this.imageUrl,
    required this.setName,
    required this.rarity,
    required this.color,
    required this.type,
    required this.text,
    required this.attribute,
  });

  factory _DeckArtVariant.fromOpCard(OpCard card) {
    return _DeckArtVariant(
      key: keyFor(card.image, fallback: '${card.code}:${card.name}'),
      label: _label(card.name, card.rarity, card.setName),
      name: card.name,
      imageUrl: card.image,
      setName: card.setName,
      rarity: card.rarity,
      color: card.color,
      type: card.type,
      text: card.text,
      attribute: card.attribute,
    );
  }

  factory _DeckArtVariant.fromRecord(CardRecord item) {
    return _DeckArtVariant(
      key: keyFor(item.imageUrl, fallback: item.id),
      label: _label(item.name, item.rarity, item.setName),
      name: item.name,
      imageUrl: item.imageUrl,
      setName: item.setName,
      rarity: item.rarity,
      color: item.color,
      type: item.type,
      text: item.text,
      attribute: item.attribute,
    );
  }

  static String keyFor(String imageUrl, {required String fallback}) {
    final normalized = imageUrl.trim();
    return normalized.isEmpty ? 'fallback:$fallback' : normalized;
  }

  static String _label(String name, String rarity, String setName) {
    return [
      name,
      rarity,
      setName,
    ].where((value) => value.trim().isNotEmpty).join(' • ');
  }
}

class _LoadError extends StatelessWidget {
  final Object? error;

  const _LoadError({required this.error});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar as artes: $error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}
