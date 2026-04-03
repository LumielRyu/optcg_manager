import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository.dart';
import '../../data/services/op_api_service.dart';

class SharedSaleCardScreen extends ConsumerWidget {
  final String shareCode;

  const SharedSaleCardScreen({
    super.key,
    required this.shareCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(collectionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carta à venda'),
      ),
      body: FutureBuilder(
        future: repo.getSharedSaleCard(shareCode),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro ao carregar carta: ${snapshot.error}'),
              ),
            );
          }

          final shared = snapshot.data;

          if (shared == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Carta não encontrada ou não está pública.'),
              ),
            );
          }

          final item = shared.item;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(item.cardCode),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 320,
                          child: _SharedSaleCardImage(
                            imageUrl: item.imageUrl,
                            cardCode: item.cardCode,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _row('Quantidade', '${item.quantity}x'),
                        _row('Set', item.setName),
                        _row('Raridade', item.rarity),
                        _row('Cor', item.color),
                        _row('Tipo', item.type),
                        _row('Atributo', item.attribute),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.text.trim().isEmpty ? 'Sem texto.' : item.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    final safeValue = value.trim().isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(safeValue)),
        ],
      ),
    );
  }
}

class _SharedSaleCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;

  const _SharedSaleCardImage({
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