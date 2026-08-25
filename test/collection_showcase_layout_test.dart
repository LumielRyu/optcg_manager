import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/features/collection/collection_showcase_layout.dart';

void main() {
  test('showcase keeps every card inside a landscape capture', () {
    final layout = calculateCollectionShowcaseLayout(
      width: 1200,
      height: 620,
      itemCount: 24,
    );
    final rows = (24 / layout.columns).ceil();
    final usedHeight =
        (layout.cardHeight * rows) + (layout.spacing * (rows - 1));

    expect(layout.columns, greaterThan(1));
    expect(usedHeight, lessThanOrEqualTo(620));
  });

  test('showcase adapts a full folder to a mobile capture', () {
    final layout = calculateCollectionShowcaseLayout(
      width: 374,
      height: 690,
      itemCount: 18,
    );
    final rows = (18 / layout.columns).ceil();
    final usedWidth =
        (layout.cardWidth * layout.columns) +
        (layout.spacing * (layout.columns - 1));
    final usedHeight =
        (layout.cardHeight * rows) + (layout.spacing * (rows - 1));

    expect(usedWidth, lessThanOrEqualTo(374.001));
    expect(usedHeight, lessThanOrEqualTo(690.001));
  });

  test('empty showcase has a safe layout', () {
    final layout = calculateCollectionShowcaseLayout(
      width: 390,
      height: 700,
      itemCount: 0,
    );

    expect(layout.columns, 1);
    expect(layout.cardWidth, 0);
    expect(layout.cardHeight, 0);
  });

  test('single card is centered without overflowing a landscape screen', () {
    final layout = calculateCollectionShowcaseLayout(
      width: 1200,
      height: 620,
      itemCount: 1,
    );

    expect(layout.columns, 1);
    expect(layout.cardWidth, lessThanOrEqualTo(1200));
    expect(layout.cardHeight, lessThanOrEqualTo(620));
  });
}
