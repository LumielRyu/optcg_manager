import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository.dart';
import '../../data/services/op_api_service.dart';
import '../../core/widgets/home_navigation_button.dart';

class SharedDeckScreen extends ConsumerWidget {
  final String shareCode;

  const SharedDeckScreen({
    super.key,
    required this.shareCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(collectionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        actions: const [HomeNavigationButton()],
        title: const Text('Deck compartilhado'),
      ),
      body: FutureBuilder(
        future: repo.getSharedDeck(shareCode),
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
                child: Text('Erro ao carregar deck: ${snapshot.error}'),
              ),
            );
          }

          final deck = snapshot.data;

          if (deck == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Deck não encontrado ou não está público.'),
              ),
            );
          }

          final totalCards =
              deck.items.fold<int>(0, (sum, item) => sum + item.quantity);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    Text(
                      deck.deckName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('Código de compartilhamento: ${deck.shareCode}'),
                    const SizedBox(height: 4),
                    Text(
                      '${deck.items.length} cartas únicas • $totalCards cartas',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 210,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.56,
                  ),
                  itemCount: deck.items.length,
                  itemBuilder: (context, index) {
                    final item = deck.items[index];

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: _SharedResolvedCardImage(
                                  imageUrl: item.imageUrl,
                                  cardCode: item.cardCode,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.cardCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text('Quantidade: ${item.quantity}x'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SharedResolvedCardImage extends ConsumerWidget {
  final String imageUrl;
  final String cardCode;
  final BoxFit fit;
  final double? height;

  const _SharedResolvedCardImage({
    required this.imageUrl,
    required this.cardCode,
    this.fit = BoxFit.contain,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directUrl = imageUrl.trim();

    if (directUrl.isNotEmpty) {
      return Image.network(
        directUrl,
        height: height,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) {
          return _SharedResolvedCardImageFromApi(
            cardCode: cardCode,
            fit: fit,
            height: height,
          );
        },
      );
    }

    return _SharedResolvedCardImageFromApi(
      cardCode: cardCode,
      fit: fit,
      height: height,
    );
  }
}

class _SharedResolvedCardImageFromApi extends ConsumerWidget {
  final String cardCode;
  final BoxFit fit;
  final double? height;

  const _SharedResolvedCardImageFromApi({
    required this.cardCode,
    required this.fit,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      future: api.findCardByCode(cardCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final resolvedUrl = snapshot.data?.image.trim() ?? '';

        if (resolvedUrl.isEmpty) {
          return SizedBox(
            height: height,
            child: Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined),
              ),
            ),
          );
        }

        return Image.network(
          resolvedUrl,
          height: height,
          fit: fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, __, ___) {
            return SizedBox(
              height: height,
              child: Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            );
          },
        );
      },
    );
  }
}