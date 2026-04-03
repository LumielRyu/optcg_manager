import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/card_record.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/services/op_api_service.dart';
import '../decks/widgets/deck_import_export_dialog.dart';
import 'collection_controller.dart';

class DeckDetailsDialog extends ConsumerStatefulWidget {
  final String deckName;
  final List<CardRecord> items;

  const DeckDetailsDialog({
    super.key,
    required this.deckName,
    required this.items,
  });

  @override
  ConsumerState<DeckDetailsDialog> createState() => _DeckDetailsDialogState();
}

class _DeckDetailsDialogState extends ConsumerState<DeckDetailsDialog> {
  bool _isSharingBusy = false;

  Future<void> _shareDeck() async {
    setState(() {
      _isSharingBusy = true;
    });

    try {
      final repo = ref.read(collectionRepositoryProvider);
      final shareCode = await repo.enableDeckSharing(widget.deckName);
      final link = '${Uri.base.origin}/shared/deck/$shareCode';

      await Clipboard.setData(ClipboardData(text: link));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link do deck copiado.'),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao compartilhar deck: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSharingBusy = false;
      });
    }
  }

  Future<void> _disableSharing() async {
    setState(() {
      _isSharingBusy = true;
    });

    try {
      await ref.read(collectionRepositoryProvider).disableDeckSharing(
            widget.deckName,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compartilhamento desativado.'),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao desativar compartilhamento: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSharingBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCards = widget.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final isValid = totalCards <= 51;

    final sortedItems = [...widget.items]
      ..sort((a, b) => a.cardCode.compareTo(b.cardCode));

    final repo = ref.read(collectionRepositoryProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 760,
          maxHeight: 860,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Text(
                    widget.deckName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalCards / 51 cartas',
                    style: TextStyle(
                      color: isValid ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder(
                    future: repo.getDeckShareInfo(widget.deckName),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      if (info == null || !info.isPublic || info.shareCode == null) {
                        return const Text('Deck privado');
                      }

                      return Text(
                        'Deck público • código: ${info.shareCode}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: sortedItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = sortedItems[index];

                  return Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 50,
                        height: 70,
                        child: _DeckCardImage(
                          imageUrl: item.imageUrl,
                          cardCode: item.cardCode,
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: Text(item.cardCode),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () async {
                              final newQty = item.quantity - 1;

                              if (newQty <= 0) {
                                await ref
                                    .read(collectionControllerProvider.notifier)
                                    .delete(item.id);
                              } else {
                                await ref
                                    .read(collectionControllerProvider.notifier)
                                    .update(
                                      item.copyWith(quantity: newQty),
                                    );
                              }
                            },
                          ),
                          Text('${item.quantity}x'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              await ref
                                  .read(collectionControllerProvider.notifier)
                                  .update(
                                    item.copyWith(
                                      quantity: item.quantity + 1,
                                    ),
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final exportText = sortedItems
                                .map((e) => '${e.quantity}x${e.cardCode}')
                                .join('\n');

                            Clipboard.setData(
                              ClipboardData(text: exportText),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Deck copiado!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Exportar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final changed = await showDialog<bool>(
                              context: context,
                              builder: (_) => DeckImportExportDialog(
                                deckName: widget.deckName,
                                items: widget.items,
                              ),
                            );

                            if (changed == true && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Importar lista'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isSharingBusy ? null : _shareDeck,
                          icon: _isSharingBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isSharingBusy ? null : _disableSharing,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Desativar link'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Fechar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;

  const _DeckCardImage({
    required this.imageUrl,
    required this.cardCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directUrl = imageUrl.trim();

    if (directUrl.isNotEmpty) {
      return Image.network(
        directUrl,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) {
          return _fallback(ref);
        },
      );
    }

    return _fallback(ref);
  }

  Widget _fallback(WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      future: api.findCardByCode(cardCode),
      builder: (context, snapshot) {
        final url = snapshot.data?.image ?? '';

        if (url.isEmpty) {
          return const Icon(Icons.image_not_supported);
        }

        return Image.network(
          url,
          fit: BoxFit.contain,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, __, ___) {
            return const Icon(Icons.broken_image_outlined);
          },
        );
      },
    );
  }
}