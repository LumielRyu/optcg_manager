import 'package:flutter/material.dart';

import '../../../core/widgets/liga_price_display.dart';
import '../../../data/models/card_record.dart';

typedef DeckCardImageBuilder =
    Widget Function(BuildContext context, CardRecord item);
typedef DeckCardAction = Future<void> Function(CardRecord item);
typedef DeckArtAllocationAction =
    Future<void> Function(List<CardRecord> sameCodeItems);

class DeckVisualSections {
  final CardRecord? leader;
  final List<CardRecord> cards;

  const DeckVisualSections({required this.leader, required this.cards});
}

DeckVisualSections splitDeckVisualSections(
  List<CardRecord> items, {
  required String deckName,
}) {
  final sorted = [...items]..sort((a, b) => a.cardCode.compareTo(b.cardCode));
  CardRecord? leader;

  for (final item in sorted) {
    if (item.type.trim().toLowerCase() == 'leader') {
      leader = item;
      break;
    }
  }

  if (leader == null) {
    final normalizedDeckName = _normalizeName(deckName);
    for (final item in sorted) {
      if (_normalizeName(item.name) == normalizedDeckName &&
          item.quantity == 1) {
        leader = item;
        break;
      }
    }
  }

  return DeckVisualSections(
    leader: leader,
    cards: sorted
        .where((item) => item.id != leader?.id)
        .toList(growable: false),
  );
}

String _normalizeName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class DeckVisualLayout extends StatelessWidget {
  final String deckName;
  final List<CardRecord> items;
  final DeckCardImageBuilder imageBuilder;
  final DeckCardAction? onIncrement;
  final DeckCardAction? onDecrement;
  final DeckArtAllocationAction? onConfigureArts;

  const DeckVisualLayout({
    super.key,
    required this.deckName,
    required this.items,
    required this.imageBuilder,
    this.onIncrement,
    this.onDecrement,
    this.onConfigureArts,
  });

  bool get _isEditable => onIncrement != null && onDecrement != null;

  @override
  Widget build(BuildContext context) {
    final sections = splitDeckVisualSections(items, deckName: deckName);
    final mainDeckCount = sections.cards.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final itemsByCode = <String, List<CardRecord>>{};
    for (final item in sections.cards) {
      itemsByCode
          .putIfAbsent(item.cardCode.trim().toUpperCase(), () => [])
          .add(item);
    }
    final uniqueMainCards = itemsByCode.length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeading(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Líder principal',
                  subtitle: sections.leader == null
                      ? 'Nenhum líder foi identificado nesta lista.'
                      : 'A carta que comanda este deck.',
                ),
                const SizedBox(height: 14),
                if (sections.leader case final leader?)
                  Center(
                    child: SizedBox(
                      width: 250,
                      height: _isEditable ? 455 : 410,
                      child: _VisualDeckCard(
                        item: leader,
                        imageBuilder: imageBuilder,
                        isLeader: true,
                        isEditable: _isEditable,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                      ),
                    ),
                  )
                else
                  const _MissingLeaderCard(),
                const SizedBox(height: 28),
                _SectionHeading(
                  icon: Icons.grid_view_rounded,
                  title: 'Cartas do deck',
                  subtitle:
                      '$uniqueMainCards cartas diferentes • '
                      '$mainDeckCount cartas no deck principal',
                ),
              ],
            ),
          ),
        ),
        if (sections.cards.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Nenhuma carta adicionada ao deck.')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = sections.cards[index];
                final sameCodeItems =
                    itemsByCode[item.cardCode.trim().toUpperCase()] ?? [item];
                final sameCodeTotal = sameCodeItems.fold<int>(
                  0,
                  (sum, entry) => sum + entry.quantity,
                );
                final canConfigureArts =
                    onConfigureArts != null &&
                    sameCodeTotal > 1 &&
                    sameCodeItems.first.id == item.id;
                return _VisualDeckCard(
                  item: item,
                  imageBuilder: imageBuilder,
                  isEditable: _isEditable,
                  onIncrement: onIncrement,
                  onDecrement: onDecrement,
                  onConfigureArts: canConfigureArts
                      ? () => onConfigureArts!(sameCodeItems)
                      : null,
                );
              }, childCount: sections.cards.length),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 205,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: _isEditable ? 0.45 : 0.50,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisualDeckCard extends StatelessWidget {
  final CardRecord item;
  final DeckCardImageBuilder imageBuilder;
  final bool isLeader;
  final bool isEditable;
  final DeckCardAction? onIncrement;
  final DeckCardAction? onDecrement;
  final Future<void> Function()? onConfigureArts;

  const _VisualDeckCard({
    required this.item,
    required this.imageBuilder,
    required this.isEditable,
    this.isLeader = false,
    this.onIncrement,
    this.onDecrement,
    this.onConfigureArts,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('deck-visual-card-${item.id}'),
      clipBehavior: Clip.antiAlias,
      elevation: isLeader ? 5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLeader
              ? colors.primary.withValues(alpha: 0.8)
              : colors.outlineVariant.withValues(alpha: 0.45),
          width: isLeader ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: imageBuilder(context, item),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _QuantityBadge(quantity: item.quantity),
                ),
                if (isLeader)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          'LÍDER',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 4),
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              item.cardCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 1),
            child: LigaDeckCardPrice(
              cardName: item.name,
              cardCode: item.cardCode,
              imageUrl: item.imageUrl,
              quantity: item.quantity,
            ),
          ),
          if (onConfigureArts != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: OutlinedButton.icon(
                onPressed: onConfigureArts,
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: const Text('Distribuir artes'),
              ),
            ),
          if (isEditable)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 5),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Remover uma cópia',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onDecrement?.call(item),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      '${item.quantity}x',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar uma cópia',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onIncrement?.call(item),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  final int quantity;

  const _QuantityBadge({required this.quantity});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          '${quantity}x',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _MissingLeaderCard extends StatelessWidget {
  const _MissingLeaderCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_search_outlined, color: colors.error),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Revise a lista e adicione uma carta do tipo Leader para '
              'destacá-la como líder principal.',
            ),
          ),
        ],
      ),
    );
  }
}
