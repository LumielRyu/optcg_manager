import '../../core/constants/collection_types.dart';
import '../../data/models/card_record.dart';
import 'collection_sale_import.dart';

enum BulkSaleQuantityMode { onePerVariant, allAvailable }

class BulkSaleImportPlan {
  final List<CardRecord> records;
  final int sourceVariantCount;
  final int addedVariantCount;
  final int skippedVariantCount;
  final int totalQuantity;

  const BulkSaleImportPlan({
    required this.records,
    required this.sourceVariantCount,
    required this.addedVariantCount,
    required this.skippedVariantCount,
    required this.totalQuantity,
  });
}

String saleVariantKey(CardRecord card) {
  final code = card.cardCode.trim().toUpperCase();
  final image = card.imageUrl.trim().toLowerCase();
  return '$code::$image';
}

BulkSaleImportPlan buildBulkSaleImportPlan({
  required List<CardRecord> sources,
  required List<CardRecord> existingSales,
  required BulkSaleQuantityMode quantityMode,
  required DateTime now,
  required String Function(int index) generatedId,
}) {
  final ownedByVariant = <String, CardRecord>{};
  for (final source in sources) {
    if (source.collectionType != CollectionTypes.owned ||
        source.quantity <= 0) {
      continue;
    }
    ownedByVariant[saleVariantKey(source)] = source;
  }

  final salesByVariant = <String, CardRecord>{};
  for (final sale in existingSales) {
    if (sale.collectionType == CollectionTypes.forSale) {
      salesByVariant[saleVariantKey(sale)] = sale;
    }
  }

  final records = <CardRecord>[];
  var totalQuantity = 0;
  var skippedVariantCount = 0;

  for (final entry in ownedByVariant.entries) {
    final source = entry.value;
    final existingSale = salesByVariant[entry.key];
    final available = availableQuantityForSale(
      source: source,
      existingSale: existingSale,
    );
    if (available <= 0) {
      skippedVariantCount++;
      continue;
    }

    final quantity = quantityMode == BulkSaleQuantityMode.allAvailable
        ? available
        : 1;
    final record = buildSaleImportRecord(
      source: source,
      existingSale: existingSale,
      quantity: quantity,
      now: now,
      generatedId: generatedId(records.length),
    );
    records.add(record);
    salesByVariant[entry.key] = record;
    totalQuantity += quantity;
  }

  return BulkSaleImportPlan(
    records: records,
    sourceVariantCount: ownedByVariant.length,
    addedVariantCount: records.length,
    skippedVariantCount: skippedVariantCount,
    totalQuantity: totalQuantity,
  );
}
