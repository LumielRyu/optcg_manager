import '../../core/constants/collection_types.dart';
import '../../data/models/card_record.dart';

int availableQuantityForSale({
  required CardRecord source,
  CardRecord? existingSale,
}) {
  final alreadyForSale = existingSale?.quantity ?? 0;
  return (source.quantity - alreadyForSale).clamp(0, source.quantity);
}

CardRecord buildSaleImportRecord({
  required CardRecord source,
  required CardRecord? existingSale,
  required int quantity,
  required DateTime now,
  required String generatedId,
}) {
  final available = availableQuantityForSale(
    source: source,
    existingSale: existingSale,
  );
  if (quantity <= 0 || quantity > available) {
    throw ArgumentError.value(
      quantity,
      'quantity',
      'A quantidade precisa estar entre 1 e $available.',
    );
  }

  if (existingSale != null) {
    if (existingSale.collectionType != CollectionTypes.forSale) {
      throw ArgumentError('O registro existente nao pertence as vendas.');
    }
    return existingSale.copyWith(quantity: existingSale.quantity + quantity);
  }

  return CardRecord(
    id: generatedId,
    cardCode: source.cardCode,
    name: source.name,
    imageUrl: source.imageUrl,
    dateAddedUtc: now,
    setName: source.setName,
    rarity: source.rarity,
    color: source.color,
    type: source.type,
    text: source.text,
    attribute: source.attribute,
    quantity: quantity,
    collectionType: CollectionTypes.forSale,
  );
}
