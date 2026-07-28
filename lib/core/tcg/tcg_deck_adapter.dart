import '../../data/models/tcg_deck.dart';
import 'tcg_deck_rules.dart';

TcgDeckEntry deckEntryFromItem(TcgDeckItem item) {
  final normalizedType = item.type.trim().toUpperCase();
  final normalizedAttribute = item.attribute.trim().toUpperCase();
  final identities = item.color
      .split(',')
      .map((value) => value.trim().toUpperCase())
      .where((value) => value.isNotEmpty)
      .toSet();
  final isBasicResource =
      normalizedType.contains('BASIC LAND') ||
      normalizedType.contains('BASIC RUNE') ||
      (normalizedType.contains('ENERGY') &&
          normalizedAttribute.contains('BASIC'));

  return TcgDeckEntry(
    cardId: item.catalogCardId,
    cardNumber: _displayCardNumber(item.cardCode),
    cardName: item.name,
    quantity: item.quantity,
    zone: item.zone,
    identities: identities,
    isBasicResource: isBasicResource,
  );
}

TcgDeckValidationContext validationContextFromDeck(
  TcgDeck deck,
  TcgDeckFormatRules rules,
) {
  if (!rules.validatesColorOrDomainIdentity) {
    return const TcgDeckValidationContext();
  }

  final anchorZones = switch (rules.slug) {
    'magic-commander' => const {TcgDeckZone.commander},
    'riftbound-constructed' => const {
      TcgDeckZone.legend,
      TcgDeckZone.chosenChampion,
    },
    'one-piece-constructed' => const {TcgDeckZone.leader},
    _ => const <TcgDeckZone>{},
  };
  final identities = deck.items
      .where((item) => anchorZones.contains(item.zone))
      .expand(
        (item) => item.color
            .split(',')
            .map((value) => value.trim().toUpperCase())
            .where((value) => value.isNotEmpty),
      )
      .toSet();

  return TcgDeckValidationContext(allowedIdentities: identities);
}

String _displayCardNumber(String cardCode) {
  final parts = cardCode.split(':');
  return parts.isEmpty ? cardCode : parts.last;
}
