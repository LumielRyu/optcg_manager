import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository.dart';
import '../../data/services/op_api_service.dart';
import '../../core/widgets/home_navigation_button.dart';
import 'widgets/deck_visual_layout.dart';

class SharedDeckScreen extends ConsumerStatefulWidget {
  final String shareCode;

  const SharedDeckScreen({super.key, required this.shareCode});

  @override
  ConsumerState<SharedDeckScreen> createState() => _SharedDeckScreenState();
}

class _SharedDeckScreenState extends ConsumerState<SharedDeckScreen> {
  late Future<SharedDeckData?> _deckFuture;

  @override
  void initState() {
    super.initState();
    _deckFuture = _loadDeck();
  }

  Future<SharedDeckData?> _loadDeck() {
    return ref
        .read(collectionRepositoryProvider)
        .getSharedDeck(widget.shareCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeNavigationButton(destinationRoute: '/home')],
        title: const Text('Deck compartilhado'),
      ),
      body: FutureBuilder(
        future: _deckFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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

          final totalCards = deck.items.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final uniqueCards = deck.items
              .map((item) => item.cardCode.trim().toUpperCase())
              .where((code) => code.isNotEmpty)
              .toSet()
              .length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    Text(
                      deck.deckName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('Código de compartilhamento: ${deck.shareCode}'),
                    const SizedBox(height: 4),
                    Text('$uniqueCards cartas diferentes • $totalCards cartas'),
                  ],
                ),
              ),
              Expanded(
                child: DeckVisualLayout(
                  deckName: deck.deckName,
                  items: deck.items,
                  imageBuilder: (context, item) => _SharedResolvedCardImage(
                    imageUrl: item.imageUrl,
                    cardCode: item.cardCode,
                    fit: BoxFit.contain,
                  ),
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

  const _SharedResolvedCardImage({
    required this.imageUrl,
    required this.cardCode,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directUrl = imageUrl.trim();

    if (directUrl.isNotEmpty) {
      return Image.network(
        directUrl,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) {
          return _SharedResolvedCardImageFromApi(cardCode: cardCode, fit: fit);
        },
      );
    }

    return _SharedResolvedCardImageFromApi(cardCode: cardCode, fit: fit);
  }
}

class _SharedResolvedCardImageFromApi extends ConsumerWidget {
  final String cardCode;
  final BoxFit fit;

  const _SharedResolvedCardImageFromApi({
    required this.cardCode,
    required this.fit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return FutureBuilder(
      future: api.findCardByCode(cardCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final resolvedUrl = snapshot.data?.image.trim() ?? '';

        if (resolvedUrl.isEmpty) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined),
            ),
          );
        }

        return Image.network(
          resolvedUrl,
          fit: fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, _, _) {
            return Container(
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        );
      },
    );
  }
}
