import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/op_card.dart';
import '../../data/services/op_api_service.dart';
import '../../core/widgets/home_navigation_button.dart';

class LibraryCompareScreen extends ConsumerWidget {
  final List<String> cardCodes;

  const LibraryCompareScreen({
    super.key,
    required this.cardCodes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(opApiServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar Cartas'),
        actions: const [HomeNavigationButton()],
      ),
      body: FutureBuilder<List<OpCard>>(
        future: api.loadAllCards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar a comparacao:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allCards = snapshot.data ?? const <OpCard>[];
          final normalizedCodes = cardCodes
              .map(api.normalizeCode)
              .where((code) => code.isNotEmpty)
              .toSet();
          final selectedCards = allCards
              .where((card) => normalizedCodes.contains(api.normalizeCode(card.code)))
              .toList(growable: false);

          if (selectedCards.length < 2) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Selecione pelo menos duas cartas para comparar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Comparacao lado a lado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Compare imagem, código, tipo, cor, raridade, atributo e texto das cartas selecionadas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final card in selectedCards)
                      SizedBox(
                        width: 320,
                        child: _ComparisonCard(card: card),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final OpCard card;

  const _ComparisonCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(right: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.72,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(10),
                child: Image.network(
                  card.image,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, _, _) {
                    return const Center(
                      child: Icon(Icons.broken_image_outlined),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              card.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.code,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _CompareRow(label: 'Tipo', value: card.type),
            _CompareRow(label: 'Cor', value: card.color),
            _CompareRow(label: 'Raridade', value: card.rarity),
            _CompareRow(label: 'Atributo', value: card.attribute),
            _CompareRow(label: 'Edicao', value: card.setName),
            const SizedBox(height: 12),
            Text(
              'Texto',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.text.trim().isEmpty ? '-' : card.text,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String value;

  const _CompareRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(value.trim().isEmpty ? '-' : value.trim()),
          ),
        ],
      ),
    );
  }
}
