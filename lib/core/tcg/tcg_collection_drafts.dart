import '../../data/models/digimon_card.dart';
import '../../data/models/magic_card.dart';
import '../../data/models/riftbound_card.dart';
import '../../data/models/tcg_collection_item.dart';
import '../../data/models/yugioh_card.dart';

extension DigimonCollectionDraft on DigimonCard {
  TcgCollectionDraft get collectionDraft => TcgCollectionDraft(
    gameSlug: 'digimon',
    catalogCardId: id,
    variantId: number,
    cardCode: ligaLookupCode,
    name: name,
    imageUrl: imageUrl,
    setName: setName,
    rarity: rarity,
    color: colors.join(', '),
    type: category,
    text: [
      effect,
      inheritedEffect,
      securityEffect,
    ].where((value) => value.trim().isNotEmpty).join('\n\n'),
    attribute: [
      attribute,
      type,
      form,
    ].where((value) => value.trim().isNotEmpty).join(', '),
  );
}

extension MagicCollectionDraft on MagicCard {
  TcgCollectionDraft get collectionDraft => TcgCollectionDraft(
    gameSlug: 'magic',
    catalogCardId: id,
    variantId: '$setCode:$collectorNumber',
    cardCode: ligaLookupCode,
    name: name,
    imageUrl: largeImageUrl.isEmpty ? imageUrl : largeImageUrl,
    setName: setName,
    rarity: rarity,
    color: colorIdentity.join(', '),
    type: typeLine,
    text: oracleText,
    attribute: manaCost,
  );
}

extension RiftboundCollectionDraft on RiftboundCard {
  TcgCollectionDraft get collectionDraft => TcgCollectionDraft(
    gameSlug: 'riftbound',
    catalogCardId: id,
    variantId: riftboundId,
    cardCode: ligaLookupCode,
    name: name,
    imageUrl: imageUrl,
    setName: setName,
    rarity: rarity,
    color: domains.join(', '),
    type: [supertype, type].where((value) => value.trim().isNotEmpty).join(' '),
    text: [
      rulesText,
      flavorText,
    ].where((value) => value.trim().isNotEmpty).join('\n\n'),
    attribute: tags.join(', '),
  );
}

extension YugiohCollectionDraft on YugiohCard {
  TcgCollectionDraft collectionDraftFor(YugiohCardPrinting printing) {
    return TcgCollectionDraft(
      gameSlug: 'yugioh',
      catalogCardId: '$id',
      variantId: printing.setCode,
      cardCode: printing.ligaLookupCode,
      name: name,
      imageUrl: largeImageUrl.isEmpty ? imageUrl : largeImageUrl,
      setName: printing.setName,
      rarity: printing.rarity,
      color: attribute,
      type: type,
      text: description,
      attribute: [
        race,
        archetype,
      ].where((value) => value.trim().isNotEmpty).join(', '),
    );
  }
}
