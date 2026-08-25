import 'dart:math' as math;

class CollectionShowcaseLayout {
  final int columns;
  final double spacing;
  final double cardWidth;
  final double cardHeight;

  const CollectionShowcaseLayout({
    required this.columns,
    required this.spacing,
    required this.cardWidth,
    required this.cardHeight,
  });
}

CollectionShowcaseLayout calculateCollectionShowcaseLayout({
  required double width,
  required double height,
  required int itemCount,
  double cardAspectRatio = 0.714,
  double preferredSpacing = 6,
}) {
  if (itemCount <= 0 || width <= 0 || height <= 0) {
    return const CollectionShowcaseLayout(
      columns: 1,
      spacing: 0,
      cardWidth: 0,
      cardHeight: 0,
    );
  }

  final spacing = math.min(
    preferredSpacing,
    width / math.max(itemCount * 4, 1),
  );
  var bestColumns = itemCount;
  var bestCardWidth = 0.0;
  var bestCardHeight = 0.0;

  for (var columns = 1; columns <= itemCount; columns++) {
    final rows = (itemCount / columns).ceil();
    final widthPerCard = (width - (spacing * (columns - 1))) / columns;
    final heightPerCard = (height - (spacing * (rows - 1))) / rows;
    final cardWidth = math.min(widthPerCard, heightPerCard * cardAspectRatio);
    if (cardWidth <= 0 || heightPerCard <= 0) continue;
    final cardHeight = cardWidth / cardAspectRatio;
    if (cardWidth > bestCardWidth) {
      bestColumns = columns;
      bestCardWidth = cardWidth;
      bestCardHeight = cardHeight;
    }
  }

  return CollectionShowcaseLayout(
    columns: bestColumns,
    spacing: spacing,
    cardWidth: bestCardWidth,
    cardHeight: bestCardHeight,
  );
}
